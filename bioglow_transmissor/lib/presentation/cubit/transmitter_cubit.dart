import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sensors_plus/sensors_plus.dart';
import '../../domain/entities/vibration_entity.dart';
import '../../domain/usecases/send_vibration_usecase.dart';
import 'transmitter_state.dart';

class TransmitterCubit extends Cubit<TransmitterState> {
  final SendVibrationUseCase _sendVibrationUseCase;
  StreamSubscription<AccelerometerEvent>? _accelerometerSubscription;
  Timer? _debounceTimer;
  Timer? _pcSimulationTimer;
  final Random _random = Random();

  // Variável para armazenar o último valor lido
  double _lastMagnitude = 0.0;
  
  // Variáveis de simulação de telemetria
  int _bateria = 100;

  TransmitterCubit(this._sendVibrationUseCase)
    : super(const TransmitterInitial());

  void setMultiplier(double multiplier) {
    if (state is TransmitterRunning) {
      emit(
        TransmitterRunning(
          currentMagnitude: (state as TransmitterRunning).currentMagnitude,
          multiplier: multiplier,
          simulationMode: state.simulationMode,
        ),
      );
    } else {
      emit(
        TransmitterStopped(
          multiplier: multiplier,
          simulationMode: state.simulationMode,
        ),
      );
    }
  }

  void setSimulationMode(SimulationMode mode) {
    if (state is TransmitterRunning) {
      emit(
        TransmitterRunning(
          currentMagnitude: (state as TransmitterRunning).currentMagnitude,
          multiplier: state.multiplier,
          simulationMode: mode,
        ),
      );
    } else {
      emit(
        TransmitterStopped(multiplier: state.multiplier, simulationMode: mode),
      );
    }
  }

  void startSimulation() {
    final currentMultiplier = state.multiplier;
    final currentMode = state.simulationMode;

    final bool isMobile =
        !kIsWeb &&
        (defaultTargetPlatform == TargetPlatform.iOS ||
            defaultTargetPlatform == TargetPlatform.android);

    if (isMobile) {
      // Inicia a escuta do acelerômetro
      _accelerometerSubscription = accelerometerEventStream().listen((event) {
        // Calcula a magnitude da vibração
        final magnitude = sqrt(
          event.x * event.x + event.y * event.y + event.z * event.z,
        );
        _lastMagnitude = magnitude;

        // Atualiza a interface em tempo real
        emit(
          TransmitterRunning(
            currentMagnitude: _lastMagnitude,
            multiplier: state.multiplier,
            simulationMode: state.simulationMode,
          ),
        );
      });
    } else {
      // Simulação para PC/Web
      _pcSimulationTimer = Timer.periodic(const Duration(milliseconds: 100), (
        _,
      ) {
        double baseValue = 10.0;
        if (state.simulationMode == SimulationMode.alert) {
          baseValue = 30.0;
        } else if (state.simulationMode == SimulationMode.alertMedium) {
          baseValue = 20.0;
        }

        if (state.simulationMode == SimulationMode.paralysis) {
          _lastMagnitude = 10.0;
        } else {
          _lastMagnitude = baseValue + (_random.nextDouble() * 2 - 1); // +/- 1
        }

        emit(
          TransmitterRunning(
            currentMagnitude: _lastMagnitude,
            multiplier: state.multiplier,
            simulationMode: state.simulationMode,
          ),
        );
      });
    }

    // Envia para o Firebase a cada 1000 milissegundos
    _debounceTimer = Timer.periodic(const Duration(milliseconds: 1000), (_) {
      if (state is TransmitterRunning) {
        final currentMult = state.multiplier;
        final finalMagnitude = _lastMagnitude * currentMult;

        // Regra da Bateria
        if (_bateria > 0) {
          _bateria -= 1;
        }

        // Regra do Sinal (variando de -45 a -80)
        final int sinal = -45 - _random.nextInt(36);

        final vibration = VibrationEntity(
          frequencia: finalMagnitude,
          bateria: _bateria,
          sinal: sinal,
          timestamp: DateTime.now(),
        );
        _sendVibrationUseCase(vibration);
      }
    });

    emit(
      TransmitterRunning(
        currentMagnitude: 0.0,
        multiplier: currentMultiplier,
        simulationMode: currentMode,
      ),
    );
  }

  void stopSimulation() {
    _accelerometerSubscription?.cancel();
    _pcSimulationTimer?.cancel();
    _debounceTimer?.cancel();
    emit(
      TransmitterStopped(
        multiplier: state.multiplier,
        simulationMode: state.simulationMode,
      ),
    );
  }

  @override
  Future<void> close() {
    _accelerometerSubscription?.cancel();
    _pcSimulationTimer?.cancel();
    _debounceTimer?.cancel();
    return super.close();
  }
}
