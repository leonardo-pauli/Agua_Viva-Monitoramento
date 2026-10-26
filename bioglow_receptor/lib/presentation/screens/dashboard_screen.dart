import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/leitura_entity.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import 'relatorio_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  static const Color corRms = Colors.cyanAccent;
  static const Color corPico = Colors.orangeAccent;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bioglow - Boia'),
        actions: [
          IconButton(
            tooltip: 'Relatório do cartão SD',
            icon: const Icon(Icons.insights),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const RelatorioScreen()),
            ),
          ),
          IconButton(
            tooltip: 'Limpar histórico',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: () => context.read<DashboardCubit>().limpar(),
          ),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final ultima = state.ultima;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _StatusCard(status: state.status),
              const SizedBox(height: 12),
              if (ultima != null) ...[
                Text(
                  'Última leitura: ${ultima.data}  ${ultima.hora}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
              ],
              Row(
                children: [
                  Expanded(
                    child: _ValorCard(
                      titulo: 'RMS',
                      valor: ultima?.rms.toStringAsFixed(2) ?? '--',
                      cor: corRms,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _ValorCard(
                      titulo: 'Pico',
                      valor: ultima?.pico.toString() ?? '--',
                      cor: corPico,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _Grafico(historico: state.historico),
              const SizedBox(height: 16),
              Text(
                'Histórico (${state.historico.length})',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 8),
              if (state.historico.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Aguardando dados da boia...')),
                )
              else
                ...state.historico.reversed.map((l) => _LinhaHistorico(l)),
            ],
          );
        },
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  final StatusConexao status;
  const _StatusCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final (cor, icone, texto) = switch (status) {
      StatusConexao.conectado => (
          Colors.greenAccent,
          Icons.wifi,
          'Conectado à boia',
        ),
      StatusConexao.conectando => (
          Colors.amberAccent,
          Icons.wifi_find,
          'Conectando...',
        ),
      StatusConexao.desconectado => (
          Colors.redAccent,
          Icons.wifi_off,
          'Desconectado - tentando novamente',
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icone, color: cor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(texto, style: TextStyle(color: cor)),
                  const SizedBox(height: 2),
                  Text(
                    status == StatusConexao.conectado
                        ? Esp32WebSocketService.url
                        : 'Conecte o celular na rede Wi-Fi "Bioglow_Boia"',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            if (status != StatusConexao.conectado)
              IconButton(
                tooltip: 'Reconectar',
                icon: const Icon(Icons.refresh),
                onPressed: () => context.read<DashboardCubit>().reconectar(),
              ),
          ],
        ),
      ),
    );
  }
}

class _ValorCard extends StatelessWidget {
  final String titulo;
  final String valor;
  final Color cor;

  const _ValorCard({
    required this.titulo,
    required this.valor,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        child: Column(
          children: [
            Text(titulo, style: TextStyle(color: cor, fontSize: 16)),
            const SizedBox(height: 8),
            FittedBox(
              child: Text(
                valor,
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Text('ADC (0 - 4095)', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _Grafico extends StatelessWidget {
  final List<LeituraEntity> historico;
  const _Grafico({required this.historico});

  @override
  Widget build(BuildContext context) {
    final rms = <FlSpot>[];
    final pico = <FlSpot>[];
    for (var i = 0; i < historico.length; i++) {
      rms.add(FlSpot(i.toDouble(), historico[i].rms));
      pico.add(FlSpot(i.toDouble(), historico[i].pico.toDouble()));
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 16, 16, 8),
        child: Column(
          children: [
            const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _Legenda(cor: DashboardScreen.corRms, texto: 'RMS'),
                SizedBox(width: 16),
                _Legenda(cor: DashboardScreen.corPico, texto: 'Pico'),
              ],
            ),
            const SizedBox(height: 12),
            SizedBox(
              height: 220,
              child: historico.isEmpty
                  ? const Center(child: Text('Sem dados'))
                  : LineChart(
                      LineChartData(
                        minY: 0,
                        maxY: 4095,
                        minX: 0,
                        maxX: (DashboardCubit.maxHistorico - 1).toDouble(),
                        gridData: const FlGridData(drawVerticalLine: false),
                        borderData: FlBorderData(show: false),
                        titlesData: const FlTitlesData(
                          topTitles: AxisTitles(),
                          rightTitles: AxisTitles(),
                          bottomTitles: AxisTitles(),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              interval: 1024,
                            ),
                          ),
                        ),
                        lineBarsData: [
                          _linha(pico, DashboardScreen.corPico),
                          _linha(rms, DashboardScreen.corRms),
                        ],
                      ),
                      duration: Duration.zero,
                    ),
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
      barWidth: 2,
      isCurved: false,
      dotData: const FlDotData(show: false),
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

class _LinhaHistorico extends StatelessWidget {
  final LeituraEntity l;
  const _LinhaHistorico(this.l);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${l.data}  ${l.hora}'),
      trailing: Text(
        'RMS ${l.rms.toStringAsFixed(2)}   Pico ${l.pico}',
        style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
      ),
    );
  }
}
