import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/historico_sd.dart';
import '../../domain/entities/leitura_entity.dart';
import '../../domain/entities/sensor_info.dart';
import '../cubit/configuracoes_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../theme/app_theme.dart';
import '../widgets/escala_grafico.dart';
import '../widgets/exportador_csv.dart';
import '../widgets/sensor_card.dart';

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

/// Relatório multiparamétrico dos dados gravados no cartão SD da boia
/// (pH, Temperatura, Condutividade e Turbidez).
class RelatorioScreen extends StatefulWidget {
  /// Momento em que o usuário saiu do app. Se informado, habilita o
  /// período "Desde sua saída" (selecionado por padrão).
  final DateTime? desdeSaida;

  const RelatorioScreen({super.key, this.desdeSaida});

  @override
  State<RelatorioScreen> createState() => _RelatorioScreenState();
}

class _RelatorioScreenState extends State<RelatorioScreen> {
  late PeriodoRelatorio _periodo;
  TipoSensor _sensorSelecionado = TipoSensor.ph;
  bool _carregando = false;
  bool _usandoSimulacao = false;
  String? _erro;
  HistoricoSd? _historico;

  @override
  void initState() {
    super.initState();
    _periodo = widget.desdeSaida != null
        ? PeriodoRelatorio.desdeSaida
        : PeriodoRelatorio.umaHora;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final emSimulacao = context.read<DashboardCubit>().state.modoSimulacao;
      if (emSimulacao) {
        _carregarSimulacao();
      } else {
        _carregar();
      }
    });
  }

  void _carregarSimulacao() {
    final agora = DateTime.now();
    final duracao = switch (_periodo) {
      PeriodoRelatorio.desdeSaida => agora.difference(
        widget.desdeSaida ?? agora.subtract(const Duration(hours: 2)),
      ),
      PeriodoRelatorio.umaHora => const Duration(hours: 1),
      PeriodoRelatorio.seisHoras => const Duration(hours: 6),
      PeriodoRelatorio.umDia => const Duration(hours: 24),
      PeriodoRelatorio.tudo => const Duration(hours: 48),
    };

    const numPontos = 60;
    final passoSeg = math.max(2, duracao.inSeconds ~/ numPontos);
    final inicio = agora.subtract(Duration(seconds: passoSeg * numPontos));
    final pontos = <PontoHistorico>[];

    for (var i = 0; i <= numPontos; i++) {
      final t = i / numPontos * math.pi * 2;
      final momento = inicio.add(Duration(seconds: i * passoSeg));
      // Ciclo diurno realista: temperatura e pH sobem levemente à tarde
      final ph = 7.15 + math.sin(t) * 0.32 + math.cos(t * 3) * 0.06;
      final temp = 24.2 + math.sin(t - 0.5) * 2.1 + math.cos(t * 2) * 0.3;
      final cond = 355.0 + math.cos(t * 1.3) * 42.0 + math.sin(t * 4) * 12.0;
      final turb = 14.0 + math.sin(t * 2).abs() * 18.0;

      pontos.add(
        PontoHistorico(
          momento: momento,
          ph: double.parse(ph.toStringAsFixed(2)),
          temperatura: double.parse(temp.toStringAsFixed(1)),
          condutividade: double.parse(cond.toStringAsFixed(1)),
          turbidez: double.parse(turb.toStringAsFixed(1)),
        ),
      );
    }

    setState(() {
      _carregando = false;
      _usandoSimulacao = true;
      _erro = null;
      _historico = HistoricoSd(
        sdOk: true,
        total: duracao.inSeconds ~/ 2,
        pontos: pontos,
      );
    });
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
      _usandoSimulacao = false;
      _erro = null;
    });

    final service = context.read<Esp32WebSocketService>();
    final maxPontos = context
        .read<ConfiguracoesCubit>()
        .state
        .maxPontosRelatorio;
    final conectou = await service.aguardarConexao(const Duration(seconds: 15));

    HistoricoSd? resultado;
    String? erro;
    if (!conectou) {
      erro =
          'Não foi possível conectar à boia.\n'
          'Conecte-se à rede Wi-Fi "Bioglow_Boia" e tente novamente.';
    } else {
      resultado = await service.baixarHistorico(
        _inicioDoPeriodo(),
        maxPontos: maxPontos,
      );
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
      _historico = (resultado != null && resultado.sdOk) ? resultado : null;
    });
  }

  void _selecionar(PeriodoRelatorio p) {
    if (p == _periodo) return;
    setState(() {
      _periodo = p;
      _historico = null;
    });
    if (_usandoSimulacao) {
      _carregarSimulacao();
    } else {
      _carregar();
    }
  }

  Future<void> _exportarCsvHistorico() async {
    final pontos = _historico?.pontos ?? const [];
    if (pontos.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não há dados carregados para exportar.')),
      );
      return;
    }

    final config = context.read<ConfiguracoesCubit>().state;
    final buffer = StringBuffer()
      ..writeln(LeituraEntity.cabecalhoCsvRelatorioSd);
    for (final p in pontos) {
      buffer.writeln(
        [
          formatarDataHora(p.momento),
          ...LeituraEntity.colunasSensoresCsv(
            config: config,
            ph: p.ph,
            temperatura: p.temperatura,
            condutividade: p.condutividade,
            turbidez: p.turbidez,
          ),
        ].join(';'),
      );
    }

    await ExportadorCsv.mostrarOpcoes(
      context,
      nomeArquivo: ExportadorCsv.gerarNomeArquivo('bioglow_relatorio_sd'),
      conteudoCsv: buffer.toString(),
      totalLinhas: pontos.length,
      tituloRelatorio: 'Exportar Relatório do Cartão SD (.CSV)',
    );
  }

  @override
  Widget build(BuildContext context) {
    final periodos = PeriodoRelatorio.values
        .where(
          (p) => p != PeriodoRelatorio.desdeSaida || widget.desdeSaida != null,
        )
        .toList();
    final pontos = _historico?.pontos ?? const <PontoHistorico>[];
    final resp = Responsivo.of(context);

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: resp.alturaAppBar,
        titleSpacing: 4,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Relatório do Cartão SD',
                maxLines: 1,
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                'Histórico gravado na boia',
                maxLines: 1,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          if (pontos.isNotEmpty)
            IconButton(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.all(6),
              constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
              tooltip: 'Exportar / Compartilhar CSV do relatório',
              icon: const IconePng(IconesApp.share, size: 19),
              onPressed: _exportarCsvHistorico,
            ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            tooltip: 'Atualizar do Cartão SD',
            icon: const Icon(Icons.refresh),
            onPressed: _carregando ? null : _carregar,
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 38, minHeight: 38),
            tooltip: 'Voltar ao Início',
            icon: const IconePng(IconesApp.home, size: 20),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _carregar,
        child: ListView(
          padding: resp.paddingLista(topo: 12, base: 28),
          children: [
            Text(
              'Janela de tempo do cartão SD',
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 6),
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
            const SizedBox(height: 14),
            if (_carregando) ...[
              const LinearProgressIndicator(),
              const SizedBox(height: 8),
              Text(
                'Transferindo registros do cartão SD da boia via Wi-Fi...',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 12),
            ],
            if (_usandoSimulacao)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.tertiaryContainer.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(
                        context,
                      ).colorScheme.tertiary.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.science_outlined,
                            size: 18,
                            color: Theme.of(context).colorScheme.tertiary,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Visualizando dados simulados do cartão SD para demonstração.',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          if (resp.isTablet)
                            TextButton(
                              onPressed: _carregar,
                              child: const Text('Ler SD real'),
                            ),
                        ],
                      ),
                      if (!resp.isTablet) ...[
                        const SizedBox(height: 4),
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _carregar,
                            child: const Text('Ler SD real'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            if (_erro != null)
              Card(
                color: Theme.of(context).colorScheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.error_outline),
                          const SizedBox(width: 12),
                          Expanded(child: Text(_erro!)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          FilledButton.tonalIcon(
                            onPressed: _carregarSimulacao,
                            icon: const Icon(Icons.science_outlined, size: 17),
                            label: const Text('Simular Dados do SD (Demo)'),
                          ),
                          OutlinedButton.icon(
                            onPressed: _carregar,
                            icon: const Icon(Icons.refresh, size: 17),
                            label: const Text('Tentar novamente'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            if (_historico != null) ...[
              SeletorSensorChips(
                selecionado: _sensorSelecionado,
                onSelecionado: (s) => setState(() => _sensorSelecionado = s),
                sensorPossuiDados: (s) => _historico!.possuiDadosDoSensor(s),
              ),
              const SizedBox(height: 12),
              _Resumo(historico: _historico!, sensor: _sensorSelecionado),
              const SizedBox(height: 12),
              _GraficoTempo(pontos: pontos, sensor: _sensorSelecionado),
              if (pontos.isNotEmpty) ...[
                const SizedBox(height: 16),
                _TabelaSinteseSensoresSd(
                  pontos: pontos,
                  sensorSelecionado: _sensorSelecionado,
                  onSelecionar: (s) => setState(() => _sensorSelecionado = s),
                ),
              ],
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
  final TipoSensor sensor;

  const _Resumo({required this.historico, required this.sensor});

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
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
    final scheme = Theme.of(context).colorScheme;
    final resp = Responsivo.of(context);

    Widget cartaoMetrica(String titulo, String valor, [Color? cor]) =>
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.30),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: (cor ?? scheme.outlineVariant).withValues(alpha: 0.25),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  titulo,
                  maxLines: 1,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: cor ?? scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  valor,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ),
            ],
          ),
        );

    final valores = pontos
        .map((p) => p.valorDoSensor(sensor))
        .whereType<double>()
        .toList();
    final cor = cores.corDoSensor(sensor);

    final List<Widget> metricas;
    if (valores.isEmpty) {
      metricas = [
        cartaoMetrica('Amostras SD', '${historico.total}'),
        cartaoMetrica('Mínimo', '--', cor),
        cartaoMetrica('Média', '--', cor),
        cartaoMetrica('Máximo', '--', cor),
      ];
    } else {
      final minV = valores.reduce(math.min);
      final maxV = valores.reduce(math.max);
      final medV = valores.reduce((a, b) => a + b) / valores.length;
      metricas = [
        cartaoMetrica('Amostras SD', '${valores.length}'),
        cartaoMetrica('Mínimo (${sensor.unidade})', sensor.formatarValor(minV), cor),
        cartaoMetrica('Média (${sensor.unidade})', sensor.formatarValor(medV), cor),
        cartaoMetrica('Máximo (${sensor.unidade})', sensor.formatarValor(maxV), cor),
      ];
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sd_card_outlined, size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${formatarDataHora(ini)}  →  ${formatarDataHora(fim)}  •  ${formatarDuracao(fim.difference(ini))}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (resp.isTablet)
              Row(
                children: [
                  for (var i = 0; i < metricas.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: metricas[i]),
                  ],
                ],
              )
            else
              Column(
                children: [
                  Row(
                    children: [
                      Expanded(child: metricas[0]),
                      const SizedBox(width: 8),
                      Expanded(child: metricas[1]),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(child: metricas[2]),
                      const SizedBox(width: 8),
                      Expanded(child: metricas[3]),
                    ],
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _GraficoTempo extends StatefulWidget {
  final List<PontoHistorico> pontos;
  final TipoSensor sensor;

  const _GraficoTempo({required this.pontos, required this.sensor});

  @override
  State<_GraficoTempo> createState() => _GraficoTempoState();
}

class _GraficoTempoState extends State<_GraficoTempo> {
  bool? _autoEscalaManual;

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = context.watch<ConfiguracoesCubit>().state;
    final autoEscala = _autoEscalaManual ?? config.escalaAutomatica;
    final pontos = widget.pontos;
    final sensor = widget.sensor;
    final faixa = config.faixaDoSensor(sensor);
    final descricaoFaixa = config.descricaoFaixaDoSensor(sensor);
    if (pontos.isEmpty) return const SizedBox.shrink();

    final inicio = pontos.first.momento;
    double x(DateTime d) => d.difference(inicio).inSeconds / 60.0;

    final seriePrincipal = <FlSpot>[];
    final valoresEscala = <double>[];

    for (final p in pontos) {
      final v = p.valorDoSensor(sensor);
      if (v == null) continue;
      final posX = x(p.momento);
      seriePrincipal.add(FlSpot(posX, v));
      valoresEscala.add(v);
    }

    final corPrincipal = cores.corDoSensor(sensor);

    if (seriePrincipal.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(iconeDoSensor(sensor), size: 32, color: corPrincipal),
              const SizedBox(height: 8),
              Text(
                'Sem registros de ${sensor.nome} no cartão SD neste período',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                'O leitor de histórico do cartão SD já está preparado para a coluna de '
                '${sensor.nome} (${sensor.unidade}). Assim que o sensor for ativado no ESP32, '
                'as curvas armazenadas no SD serão exibidas aqui.',
                style: Theme.of(context).textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    final maxX = math.max(x(pontos.last.momento), 1.0);
    final intervaloX = maxX / 4;
    final varioDias =
        pontos.last.momento.day != inicio.day ||
        pontos.last.momento.difference(inicio).inHours >= 24;

    String rotulo(double minutos) {
      final d = inicio.add(Duration(seconds: (minutos * 60).round()));
      return varioDias ? formatarDataHora(d) : formatarHora(d);
    }

    final escala = EscalaY.calcular(
      valoresEscala,
      auto: autoEscala,
      sensor: sensor,
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 6, 16, 10),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(iconeDoSensor(sensor), size: 16, color: corPrincipal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sensor.nome} (${sensor.unidade})',
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                BotaoEscala(
                  auto: autoEscala,
                  sensor: sensor,
                  onChanged: (v) => setState(() => _autoEscalaManual = v),
                ),
              ],
            ),
            const SizedBox(height: 4),
            SizedBox(
              height: Responsivo.of(context).alturaGraficoRelatorio,
              child: LineChart(
                LineChartData(
                  minY: 0,
                  maxY: escala.max,
                  minX: 0,
                  maxX: maxX,
                  gridData: FlGridData(
                    horizontalInterval: escala.intervalo,
                    verticalInterval: intervaloX,
                  ),
                  borderData: FlBorderData(show: false),
                  extraLinesData: ExtraLinesData(
                    horizontalLines: [
                      HorizontalLine(
                        y: faixa.min,
                        color: scheme.outline.withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                      HorizontalLine(
                        y: faixa.max,
                        color: scheme.outline.withValues(alpha: 0.45),
                        strokeWidth: 1,
                        dashArray: [4, 4],
                      ),
                    ],
                  ),
                  titlesData: FlTitlesData(
                    topTitles: const AxisTitles(),
                    rightTitles: const AxisTitles(),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: Responsivo.of(context).larguraEixoY,
                        interval: escala.intervalo,
                        getTitlesWidget: rotuloEixoY,
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: Responsivo.of(
                          context,
                        ).alturaEixoX(varioDias: varioDias),
                        interval: intervaloX,
                        getTitlesWidget: (value, meta) {
                          if (value != meta.min &&
                              value != meta.max &&
                              (value % intervaloX).abs() > 0.001) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              rotulo(value),
                              style: const TextStyle(fontSize: 11.5),
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
                        final prefixo = s == spots.first
                            ? '${formatarDataHora(inicio.add(Duration(seconds: (s.x * 60).round())))}\n'
                            : '';
                        return LineTooltipItem(
                          '$prefixo${sensor.nomeCurto}: ${sensor.formatarValor(s.y, incluirUnidade: true)}',
                          TextStyle(color: corPrincipal, fontSize: 13),
                        );
                      }).toList(),
                    ),
                  ),
                  lineBarsData: [_linha(seriePrincipal, corPrincipal)],
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '${seriePrincipal.length} pontos no gráfico • $descricaoFaixa',
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
      barWidth: 1.8,
      isCurved: false,
      dotData: FlDotData(show: spots.length <= 2),
      belowBarData: BarAreaData(show: true, color: cor.withValues(alpha: 0.08)),
    );
  }
}

/// Tabela resumo comparando os 4 sensores nos dados lidos do cartão SD.
class _TabelaSinteseSensoresSd extends StatelessWidget {
  final List<PontoHistorico> pontos;
  final TipoSensor sensorSelecionado;
  final ValueChanged<TipoSensor> onSelecionar;

  const _TabelaSinteseSensoresSd({
    required this.pontos,
    required this.sensorSelecionado,
    required this.onSelecionar,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = context.watch<ConfiguracoesCubit>().state;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                IconePng(IconesApp.chart, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Síntese Multiparamétrica do Período (Cartão SD)',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            for (final s in TipoSensor.values)
              Builder(
                builder: (context) {
                  final valores = pontos
                      .map((p) => p.valorDoSensor(s))
                      .whereType<double>()
                      .toList();
                  final tem = valores.isNotEmpty;
                  final media = tem
                      ? valores.reduce((a, b) => a + b) / valores.length
                      : null;
                  final maxV = tem ? valores.reduce(math.max) : null;
                  final cor = cores.corDoSensor(s);
                  final selecionado = s == sensorSelecionado;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () => onSelecionar(s),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: selecionado
                              ? cor.withValues(alpha: 0.08)
                              : scheme.surfaceContainerHighest.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selecionado
                                ? cor.withValues(alpha: 0.55)
                                : scheme.outlineVariant.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(iconeDoSensor(s), size: 18, color: cor),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    s.nome,
                                    style: TextStyle(
                                      fontWeight: selecionado
                                          ? FontWeight.w700
                                          : FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              config.descricaoFaixaDoSensor(s),
                              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                fontSize: 12.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 8),
                            if (!tem)
                              Text(
                                'Aguardando sensor no SD',
                                style: TextStyle(
                                  fontSize: 12.5,
                                  color: scheme.outline,
                                ),
                              )
                            else
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cor.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Média: ${s.formatarValor(media)} ${s.unidade}',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: cor,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: scheme.surface.withValues(alpha: 0.6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Máx: ${s.formatarValor(maxV)} ${s.unidade}',
                                        style: const TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          fontFeatures: [
                                            FontFeature.tabularFigures(),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}
