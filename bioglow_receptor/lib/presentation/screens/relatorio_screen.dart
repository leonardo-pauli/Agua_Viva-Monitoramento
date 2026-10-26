import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/historico_sd.dart';

/// Períodos disponíveis no relatório.
enum PeriodoRelatorio {
  desdeSaida('Desde sua saída'),
  umaHora('1 h'),
  seisHoras('6 h'),
  umDia('24 h'),
  tudo('Tudo');

  final String rotulo;
  const PeriodoRelatorio(this.rotulo);
}

/// Relatório (gráfico ao longo do tempo) dos dados gravados no cartão SD
/// da boia. Os dados são baixados do ESP32 via WebSocket.
class RelatorioScreen extends StatefulWidget {
  /// Momento em que o usuário saiu do app. Se informado, habilita o
  /// período "Desde sua saída" (selecionado por padrão).
  final DateTime? desdeSaida;

  const RelatorioScreen({super.key, this.desdeSaida});

  static const Color corRms = Colors.cyanAccent;
  static const Color corPico = Colors.orangeAccent;

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  late PeriodoRelatorio _periodo;
  bool _carregando = false;
  String? _erro;
  HistoricoSd? _historico;

  @override
  void initState() {
    super.initState();
    _periodo = widget.desdeSaida != null
        ? PeriodoRelatorio.desdeSaida
        : PeriodoRelatorio.umaHora;
    WidgetsBinding.instance.addPostFrameCallback((_) => _carregar());
  }

  DateTime _inicioDoPeriodo() {
    final agora = DateTime.now();
    return switch (_periodo) {
      PeriodoRelatorio.desdeSaida => widget.desdeSaida ?? agora,
      PeriodoRelatorio.umaHora => agora.subtract(const Duration(hours: 1)),
      PeriodoRelatorio.seisHoras => agora.subtract(const Duration(hours: 6)),
      PeriodoRelatorio.umDia => agora.subtract(const Duration(days: 1)),
      PeriodoRelatorio.tudo => DateTime(2000),
    };
  }

  Future<void> _carregar() async {
    if (_carregando) return;
    setState(() {
      _carregando = true;
      _erro = null;
    });

    final service = context.read<Esp32WebSocketService>();
    final conectou = await service.aguardarConexao(const Duration(seconds: 15));

    HistoricoSd? resultado;
    String? erro;
    if (!conectou) {
      erro = 'Não foi possível conectar à boia.\n'
          'Conecte o celular na rede Wi-Fi "Bioglow_Boia" e tente novamente.';
    } else {
      resultado = await service.baixarHistorico(_inicioDoPeriodo());
      if (resultado == null) {
        erro = 'A boia não respondeu ao pedido de dados do cartão SD.';
      } else if (!resultado.sdOk) {
        erro = 'Cartão SD não detectado na boia.';
      }
    }

    if (!mounted) return;
    setState(() {
      _carregando = false;
      _erro = erro;
      if (resultado != null) _historico = resultado;
    });
  }

  void _selecionar(PeriodoRelatorio p) {
    if (p == _periodo) return;
    setState(() => _periodo = p);
    _carregar();
  }

  @override
  Widget build(BuildContext context) {
    final periodos = PeriodoRelatorio.values
        .where((p) =>
            p != PeriodoRelatorio.desdeSaida || widget.desdeSaida != null)
        .toList();
    final pontos = _historico?.pontos ?? const <PontoHistorico>[];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Relatório da boia'),
        actions: [
          IconButton(
            tooltip: 'Atualizar',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregar,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final p in periodos)
                  ChoiceChip(
                    label: Text(p.rotulo),
                    selected: p == _periodo,
                    onSelected: _carregando ? null : (_) => _selecionar(p),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_carregando) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Lendo dados do cartão SD da boia...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (_erro != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline),
                      const SizedBox(width: 12),
                      Expanded(child: Text(_erro!)),
                    ],
                  ),
                ),
              ),
            if (_historico != null) ...[
              _Resumo(historico: _historico!),
              const SizedBox(height: 12),
              _GraficoTempo(pontos: pontos),
            ],
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// Formatação de data/hora (sem dependência do pacote intl)
// ------------------------------------------------------------------

String _dois(int v) => v.toString().padLeft(2, '0');

String formatarHora(DateTime d) => '${_dois(d.hour)}:${_dois(d.minute)}';

String formatarDataHora(DateTime d) =>
    '${_dois(d.day)}/${_dois(d.month)} ${formatarHora(d)}';

String formatarDuracao(Duration d) {
  if (d.inDays > 0) return '${d.inDays} d ${d.inHours % 24} h';
  if (d.inHours > 0) return '${d.inHours} h ${d.inMinutes % 60} min';
  return '${d.inMinutes} min';
}

class _Resumo extends StatelessWidget {
  final HistoricoSd historico;
  const _Resumo({required this.historico});

  @override
  Widget build(BuildContext context) {
    final pontos = historico.pontos;
    if (pontos.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Center(
            child: Text('Nenhum dado armazenado no cartão SD neste período.'),
          ),
        ),
      );
    }

    final ini = pontos.first.momento;
    final fim = pontos.last.momento;
    final rmsMedio =
        pontos.map((p) => p.rms).reduce((a, b) => a + b) / pontos.length;
    final rmsMax = pontos.map((p) => p.rms).reduce(math.max);
    final picoMax = pontos.map((p) => p.pico).reduce(math.max);

    Widget item(String titulo, String valor, [Color? cor]) => Expanded(
          child: Column(
            children: [
              Text(titulo,
                  style: TextStyle(fontSize: 12, color: cor ?? Colors.white70)),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  valor,
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                const Icon(Icons.sd_card_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatarDataHora(ini)}  →  ${formatarDataHora(fim)}'
                    '  (${formatarDuracao(fim.difference(ini))})',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                item('Leituras', '${historico.total}'),
                item('RMS médio', rmsMedio.toStringAsFixed(1),
                    RelatorioScreen.corRms),
                item('RMS máx.', rmsMax.toStringAsFixed(1),
                    RelatorioScreen.corRms),
                item('Pico máx.', '$picoMax', RelatorioScreen.corPico),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _GraficoTempo extends StatelessWidget {
  final List<PontoHistorico> pontos;
  const _GraficoTempo({required this.pontos});

  @override
  Widget build(BuildContext context) {
    if (pontos.isEmpty) return const SizedBox.shrink();

    final inicio = pontos.first.momento;
    // Eixo X em minutos desde o primeiro ponto
    double x(DateTime d) => d.difference(inicio).inSeconds / 60.0;

    final rms = <FlSpot>[];
    final pico = <FlSpot>[];
    for (final p in pontos) {
      rms.add(FlSpot(x(p.momento), p.rms));
      pico.add(FlSpot(x(p.momento), p.pico.toDouble()));
    }

    final maxX = math.max(x(pontos.last.momento), 1.0);
    final intervaloX = maxX / 4;
    final varioDias = pontos.last.momento.day != inicio.day ||
        pontos.last.momento.difference(inicio).inHours >= 24;

    String rotulo(double minutos) {
      final d = inicio.add(Duration(seconds: (minutos * 60).round()));
      return varioDias ? formatarDataHora(d) : formatarHora(d);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legenda(cor: RelatorioScreen.corRms, texto: 'RMS'),
                SizedBox(width: 16),
                _Legenda(cor: RelatorioScreen.corPico, texto: 'Pico'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 280,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: 4095,
                  minX: 0,
                  maxX: maxX,
                  gridData: FlGridData(
                    horizontalInterval: 1024,
                    verticalInterval: intervaloX,
                  ),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: const AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 40,
                        interval: 1024,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: varioDias ? 36 : 28,
                        interval: intervaloX,
                        getTitlesWidget: (value, meta) {
                          // Evita rótulo duplicado no último ponto
                          if (value != meta.min &&
                              value != meta.max &&
                              (value % intervaloX).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              rotulo(value),
                              style: const TextStyle(fontSize: 10),
                              textAlign: TextAlign.center,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  lineTouchData: LineTouchData(
                    touchTooltipData: LineTouchTooltipData(
                      fitInsideHorizontally: true,
                      fitInsideVertically: true,
                      getTooltipItems: (spots) => spots.map((s) {
                        final ehRms = s.barIndex == 1;
                        final valor = ehRms
                            ? s.y.toStringAsFixed(1)
                            : s.y.toStringAsFixed(0);
                        final prefixo = s == spots.first
                            ? '${formatarDataHora(inicio.add(Duration(seconds: (s.x * 60).round())))}\n'
                            : '';
                        return LineTooltipItem(
                          '$prefixo${ehRms ? 'RMS' : 'Pico'}: $valor',
                          TextStyle(
                            color: ehRms
                                ? RelatorioScreen.corRms
                                : RelatorioScreen.corPico,
                            fontSize: 12,
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [
                    _linha(pico, RelatorioScreen.corPico),
                    _linha(rms, RelatorioScreen.corRms),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${pontos.length} pontos no gráfico (valores ADC 0 - 4095)',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  LineChartBarData _linha(List<FlSpot> spots, Color cor) {
    return LineChartBarData(
      spots: spots,
      color: cor,
      barWidth: 1.5,
      isCurved: false,
      dotData: FlDotData(show: spots.length <= 2),
      belowBarData: BarAreaData(
        show: true,
        color: cor.withValues(alpha: 0.08),
      ),
    );
  }
}

class _Legenda extends StatelessWidget {
  final Color cor;
  final String texto;
  const _Legenda({required this.cor, required this.texto});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 12, height: 12, color: cor),
        const SizedBox(width: 6),
        Text(texto),
      ],
    );
  }
}
