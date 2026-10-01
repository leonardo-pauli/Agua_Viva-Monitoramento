import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../cubit/transmitter_cubit.dart';
import '../cubit/transmitter_state.dart';

class TransmitterPage extends StatelessWidget {
  const TransmitterPage({Key? key}) : super(key: key);

  bool get isMobile {
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS || defaultTargetPlatform == TargetPlatform.android;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bioglow Transmissor (Mock)'),
        backgroundColor: Colors.green.shade700,
        foregroundColor: Colors.white,
      ),
      body: BlocBuilder<TransmitterCubit, TransmitterState>(
        builder: (context, state) {
          final isRunning = state is TransmitterRunning;
          final currentMagnitude =
              state is TransmitterRunning ? state.currentMagnitude : 0.0;
          final multiplier = state.multiplier;
          final simulationMode = state.simulationMode;

          return Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: isRunning ? Colors.green.shade50 : Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isRunning ? Colors.green.shade300 : Colors.grey.shade300,
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Text(
                        'Magnitude da Vibração',
                        style: TextStyle(
                          fontSize: 18, 
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        currentMagnitude.toStringAsFixed(2),
                        style: TextStyle(
                          fontSize: 64,
                          fontWeight: FontWeight.bold,
                          color: isRunning ? Colors.green.shade800 : Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'm/s²',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.grey.shade500,
                        ),
                      ),
                    ],
                  ),
                ),
                if (!isMobile) ...[
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<TransmitterCubit>().setSimulationMode(SimulationMode.normal);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: simulationMode == SimulationMode.normal
                                    ? Colors.blue.shade600
                                    : Colors.blue.shade200,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Normal (~10)', textAlign: TextAlign.center),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<TransmitterCubit>().setSimulationMode(SimulationMode.alertMedium);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: simulationMode == SimulationMode.alertMedium
                                    ? Colors.orange.shade600
                                    : Colors.orange.shade200,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Alerta (~20)', textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<TransmitterCubit>().setSimulationMode(SimulationMode.alert);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: simulationMode == SimulationMode.alert
                                    ? Colors.red.shade600
                                    : Colors.red.shade200,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Alerta (~30)', textAlign: TextAlign.center),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton(
                              onPressed: () {
                                context.read<TransmitterCubit>().setSimulationMode(SimulationMode.paralysis);
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: simulationMode == SimulationMode.paralysis
                                    ? Colors.purple.shade600
                                    : Colors.purple.shade200,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: const Text('Paralisia (10)', textAlign: TextAlign.center),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 48),
                Text(
                  'Multiplicador de Anomalia',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16, 
                    fontWeight: FontWeight.w600,
                    color: Colors.grey.shade800,
                  ),
                ),
                const SizedBox(height: 8),
                Slider(
                  value: multiplier,
                  min: 1.0,
                  max: 10.0,
                  divisions: 9,
                  activeColor: Colors.green.shade600,
                  label: multiplier.toStringAsFixed(1),
                  onChanged: (value) {
                    context.read<TransmitterCubit>().setMultiplier(value);
                  },
                ),
                Text(
                  '${multiplier.toStringAsFixed(1)}x',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.green.shade700,
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {
                    if (isRunning) {
                      context.read<TransmitterCubit>().stopSimulation();
                    } else {
                      context.read<TransmitterCubit>().startSimulation();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isRunning ? Colors.red.shade600 : Colors.green.shade600,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 24),
                    elevation: 4,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    isRunning ? 'PARAR SIMULAÇÃO' : 'INICIAR SIMULAÇÃO',
                    style: const TextStyle(
                      fontSize: 18, 
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }
}
