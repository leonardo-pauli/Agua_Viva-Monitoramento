import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../../domain/entities/vibration_entity.dart';
import '../cubit/dashboard_cubit.dart';

class RealtimeChart extends StatelessWidget {
  final List<VibrationEntity> data;
  final bool isAlert;
  final bool isWarning;
  final bool isFault;

  const RealtimeChart({
    super.key,
    required this.data,
    required this.isAlert,
    this.isWarning = false,
    this.isFault = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(
        child: Text(
          'Aguardando dados...',
          style: TextStyle(color: Colors.black54, fontSize: 18),
        ),
      );
    }

    final spots = data.map((e) {
      return FlSpot(
        e.timestamp.millisecondsSinceEpoch.toDouble(),
        e.magnitude,
      );
    }).toList();

    final maxX = spots.last.x;
    final minX = maxX - 5000; // Janela fixa de exatamente 5 segundos (5000 ms)

    // Limita o topo do gráfico em 80, a menos que o valor ultrapasse muito
    double maxMag = 0;
    for (final s in spots) {
      if (s.y > maxMag) maxMag = s.y;
    }
    final chartMaxY = maxMag > 75 ? maxMag + 5 : 80.0;

    return RepaintBoundary(
      child: LineChart(
        LineChartData(
          // Habilita tooltips ao tocar nos pontos para ver os valores
          lineTouchData: LineTouchData(
            enabled: true,
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (touchedSpot) => Colors.blueGrey.withValues(alpha: 0.8),
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  return LineTooltipItem(
                    spot.y.toStringAsFixed(2),
                    const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  );
                }).toList();
              },
            ),
          ),
          clipData: const FlClipData.all(),
          minX: minX,
          maxX: maxX,
          minY: 0,
          maxY: chartMaxY,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 10,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: Colors.grey.withValues(alpha: 0.15),
                strokeWidth: 1,
              );
            },
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            // Adiciona os valores na parte de baixo do gráfico
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 24,
                interval: 1000, // Mostra um valor a cada 1 segundo no eixo inferior
                getTitlesWidget: (value, meta) {
                  if (spots.isEmpty) return const SizedBox.shrink();
                  // Encontra o ponto mais próximo deste tempo
                  final closest = spots.reduce((a, b) => (a.x - value).abs() < (b.x - value).abs() ? a : b);
                  if ((closest.x - value).abs() > 500) return const SizedBox.shrink();
                  
                  return Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: Text(
                      closest.y.toStringAsFixed(1),
                      style: TextStyle(
                        color: Colors.blueGrey[400],
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 36,
                interval: 10,
                getTitlesWidget: (value, meta) {
                  return Text(
                    value.toInt().toString(),
                    style: const TextStyle(color: Colors.black45, fontSize: 11),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.2,
              preventCurveOverShooting: true,
              color: isFault ? Colors.grey[700] : (isAlert ? Colors.redAccent : (isWarning ? Colors.orange : Colors.blueAccent)),
              barWidth: 3,
              isStrokeCapRound: true,
              // Adiciona um pontinho em cada alteração (dados)
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: Colors.white,
                    strokeWidth: 2,
                    strokeColor: isFault ? Colors.grey[700]! : (isAlert ? Colors.redAccent : (isWarning ? Colors.orange : Colors.blueAccent)),
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    (isFault ? Colors.grey[500]! : (isAlert ? Colors.redAccent : (isWarning ? Colors.orange : Colors.blueAccent))).withValues(alpha: 0.2),
                    (isFault ? Colors.grey[500]! : (isAlert ? Colors.redAccent : (isWarning ? Colors.orange : Colors.blueAccent))).withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
          extraLinesData: ExtraLinesData(
            horizontalLines: [
              HorizontalLine(
                y: DashboardCubit.thresholdWarning,
                color: Colors.orange.withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  labelResolver: (line) => 'Atenção ${DashboardCubit.thresholdWarning}',
                ),
              ),
              HorizontalLine(
                y: DashboardCubit.thresholdAlert,
                color: Colors.redAccent.withValues(alpha: 0.6),
                strokeWidth: 1.5,
                dashArray: [6, 4],
                label: HorizontalLineLabel(
                  show: true,
                  alignment: Alignment.topRight,
                  padding: const EdgeInsets.only(right: 5, bottom: 5),
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontWeight: FontWeight.w600,
                    fontSize: 11,
                  ),
                  labelResolver: (line) => 'Alerta ${DashboardCubit.thresholdAlert}',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
