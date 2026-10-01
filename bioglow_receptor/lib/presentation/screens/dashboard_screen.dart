import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../widgets/realtime_chart.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Otimização: BlocSelector no topo para reconstruir apenas o Scaffold e AppBar quando o status de alerta muda
    return BlocSelector<DashboardCubit, DashboardState, Type>(
      selector: (state) => state.runtimeType,
      builder: (context, stateType) {
        final isAlert = stateType == DashboardAlertState;
        final isWarning = stateType == DashboardWarningState;
        final isFault = stateType == DashboardFaultState;
        
        Color bgColor = const Color(0xFFF1F5F9);
        Color appBarColor = Colors.white;
        Color iconColor = Colors.blueAccent;
        Color textColor = const Color(0xFF334155);
        IconData iconData = Icons.water_drop;
        
        if (isFault) {
          bgColor = Colors.grey[200]!;
          appBarColor = Colors.grey[700]!;
          iconColor = Colors.white;
          textColor = Colors.white;
          iconData = Icons.sensors_off_rounded;
        } else if (isAlert) {
          bgColor = Colors.red[50]!;
          appBarColor = Colors.redAccent;
          iconColor = Colors.white;
          textColor = Colors.white;
          iconData = Icons.warning_amber_rounded;
        } else if (isWarning) {
          bgColor = Colors.orange[50]!;
          appBarColor = Colors.orange;
          iconColor = Colors.white;
          textColor = Colors.white;
          iconData = Icons.warning_amber_rounded;
        }
        return Scaffold(
          backgroundColor: bgColor,
          appBar: AppBar(
            backgroundColor: appBarColor,
            iconTheme: IconThemeData(color: iconColor),
            title: Row(
              children: [
                Icon(
                  iconData,
                  color: iconColor,
                ),
                const SizedBox(width: 12),
                Text(
                  'Bioglow Receptor - FLL',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            elevation: 1,
            shadowColor: Colors.black.withValues(alpha: 0.1),
          ),
          body: const _DashboardBody(), // Const para evitar rebuild do scroll inteiro
        );
      },
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody();

  @override
  Widget build(BuildContext context) {
    // 2. Otimização: BlocBuilder restrito apenas ao conteúdo do corpo
    return BlocBuilder<DashboardCubit, DashboardState>(
      builder: (context, state) {
        if (state is DashboardLoading) {
          return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
        }
        
        if (state is DashboardErrorState) {
          return Center(
            child: Text(
              'Erro ao carregar dados:\n${state.message}',
              style: const TextStyle(color: Colors.black87, fontSize: 18),
              textAlign: TextAlign.center,
            ),
          );
        }

        final isAlert = state is DashboardAlertState;
        final isWarning = state is DashboardWarningState;
        final isFault = state is DashboardFaultState;
        final data = state.chartData;
        final currentMagnitude = data.isNotEmpty ? data.last.magnitude : 0.0;
        final currentBateria = data.isNotEmpty ? data.last.bateria : 100;
        final currentSinal = data.isNotEmpty ? data.last.sinal : -50;

        return SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _StatusCard(isAlert: isAlert, isWarning: isWarning, isFault: isFault, currentMagnitude: currentMagnitude),
                const SizedBox(height: 20),
                _ChartCard(state: state, isAlert: isAlert, isWarning: isWarning, isFault: isFault),
                const SizedBox(height: 20),
                TelemetryStatusBar(currentBateria: currentBateria, currentSinal: currentSinal),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatusCard extends StatelessWidget {
  final bool isAlert;
  final bool isWarning;
  final bool isFault;
  final double currentMagnitude;

  const _StatusCard({
    required this.isAlert,
    required this.isWarning,
    required this.isFault,
    required this.currentMagnitude,
  });

  @override
  Widget build(BuildContext context) {
    List<Color> gradientColors = [Colors.teal[400]!, Colors.teal[600]!];
    Color shadowColor = Colors.teal;
    String statusText = 'Qualidade Estável';
    IconData statusIcon = Icons.check_circle_outline_rounded;
    
    if (isFault) {
      gradientColors = [Colors.grey[700]!, Colors.grey[900]!];
      shadowColor = Colors.grey[700]!;
      statusText = 'FALHA NO SENSOR';
      statusIcon = Icons.sensors_off_rounded;
    } else if (isAlert) {
      gradientColors = [Colors.redAccent, Colors.red[700]!];
      shadowColor = Colors.redAccent;
      statusText = 'ALERTA CRÍTICO';
      statusIcon = Icons.warning_rounded;
    } else if (isWarning) {
      gradientColors = [Colors.orange, Colors.deepOrange];
      shadowColor = Colors.orange;
      statusText = 'ATENÇÃO (SINALIZAÇÃO)';
      statusIcon = Icons.warning_amber_rounded;
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        children: [
          Icon(
            statusIcon,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 12),
          Text(
            statusText,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.waves, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Vibração: ${currentMagnitude.toStringAsFixed(2)}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          if (isFault) ...[
            const SizedBox(height: 12),
            const Text(
              'Atenção: O sensor parece estar travado ou inativo (sinal constante).',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            )
          ] else if (isAlert) ...[
            const SizedBox(height: 12),
            const Text(
              'Alerta Crítico! Níveis de vibração acima do limite (25.0).',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            )
          ] else if (isWarning) ...[
            const SizedBox(height: 12),
            const Text(
              'Atenção! Níveis de vibração em sinalização (acima de 15.0).',
              style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w500),
              textAlign: TextAlign.center,
            )
          ],
        ],
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  final DashboardState state;
  final bool isAlert;
  final bool isWarning;
  final bool isFault;

  const _ChartCard({
    required this.state,
    required this.isAlert,
    required this.isWarning,
    required this.isFault,
  });

  @override
  Widget build(BuildContext context) {
    Color cardColor = Colors.white;
    Color borderColor = Colors.grey.withValues(alpha: 0.1);
    Color iconBgColor = Colors.blueAccent.withValues(alpha: 0.1);
    Color iconColor = Colors.blueAccent;
    
    if (isFault) {
      cardColor = Colors.grey[50]!;
      borderColor = Colors.grey.withValues(alpha: 0.3);
      iconBgColor = Colors.grey.withValues(alpha: 0.2);
      iconColor = Colors.grey[700]!;
    } else if (isAlert) {
      cardColor = Colors.red[50]!;
      borderColor = Colors.redAccent.withValues(alpha: 0.3);
      iconBgColor = Colors.redAccent.withValues(alpha: 0.1);
      iconColor = Colors.redAccent;
    } else if (isWarning) {
      cardColor = Colors.orange[50]!;
      borderColor = Colors.orange.withValues(alpha: 0.3);
      iconBgColor = Colors.orange.withValues(alpha: 0.1);
      iconColor = Colors.orange;
    }

    return Container(
      height: 420,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: borderColor,
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.show_chart_rounded, 
                  color: iconColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Monitoramento em Tempo Real',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[800],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Histórico contínuo (Janela de 100 pontos)',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.blueGrey[400],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: RealtimeChart(
              data: state.chartData,
              isAlert: isAlert,
              isWarning: isWarning,
              isFault: isFault,
            ),
          ),
        ],
      ),
    );
  }
}

class TelemetryStatusBar extends StatelessWidget {
  final int currentBateria;
  final int currentSinal;

  const TelemetryStatusBar({
    super.key,
    required this.currentBateria,
    required this.currentSinal,
  });

  @override
  Widget build(BuildContext context) {
    IconData batteryIcon;
    Color batteryColor;
    if (currentBateria > 50) {
      batteryIcon = Icons.battery_full;
      batteryColor = Colors.green;
    } else if (currentBateria <= 20) {
      batteryIcon = Icons.battery_alert;
      batteryColor = Colors.red;
    } else {
      batteryIcon = Icons.battery_4_bar;
      batteryColor = Colors.orange;
    }

    IconData signalIcon;
    Color signalColor;
    if (currentSinal >= -55) {
      signalIcon = Icons.wifi;
      signalColor = Colors.blueAccent; 
    } else if (currentSinal >= -75) {
      signalIcon = Icons.wifi_2_bar;
      signalColor = Colors.orange;
    } else {
      signalIcon = Icons.wifi_1_bar;
      signalColor = Colors.red;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ],
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.1),
          width: 1.5,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Battery indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: batteryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(batteryIcon, color: batteryColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Bateria',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey[400],
                    ),
                  ),
                  Text(
                    '$currentBateria%',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            width: 1,
            height: 40,
            color: Colors.grey.withValues(alpha: 0.2),
          ),
          // Signal indicator
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: signalColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(signalIcon, color: signalColor, size: 24),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Sinal Wi-Fi',
                    style: TextStyle(
                      fontSize: 13,
                      color: Colors.blueGrey[400],
                    ),
                  ),
                  Text(
                    '$currentSinal dBm',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.blueGrey[800],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
