import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../domain/entities/vibration_entity.dart';
import '../../domain/repositories/vibration_repository.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  final VibrationRepository _repository;
  StreamSubscription? _subscription;
  
  static const double thresholdWarning = 15.0;
  static const double thresholdAlert = 25.0;

  DashboardCubit(this._repository) : super(DashboardLoading()) {
    _startListening();
  }

  void _startListening() {
    _subscription = _repository.getVibrationStream().listen(
      (vibrations) {
        _processVibrations(vibrations);
      },
      onError: (error) {
        emit(DashboardErrorState(error.toString()));
      },
    );
  }

  void _processVibrations(List<VibrationEntity> vibrations) {
    if (vibrations.isEmpty) {
      emit(const DashboardNormalState(chartData: []));
      return;
    }

    // Pega o tempo do último ponto recebido
    final latestTime = vibrations.last.timestamp.millisecondsSinceEpoch;
    
    // Filtra apenas os pontos que estão dentro da janela de 5 segundos visível no gráfico
    final recentVibrations = vibrations.where(
      (v) => latestTime - v.timestamp.millisecondsSinceEpoch <= 5000
    );

    final recentVibrationsList = recentVibrations.toList();
    
    // Verifica falha do sensor: se tivermos pelo menos 4 leituras e todas forem idênticas
    bool isFault = false;
    if (recentVibrationsList.length >= 4) {
      final firstMag = recentVibrationsList.first.magnitude;
      isFault = recentVibrationsList.every((v) => v.magnitude == firstMag);
    }

    // Conta anomalias apenas nos últimos 5 segundos
    final alertCount = recentVibrations.where((v) => v.magnitude > thresholdAlert).length;
    final warningCount = recentVibrations.where((v) => v.magnitude > thresholdWarning && v.magnitude <= thresholdAlert).length;

    if (isFault) {
      emit(DashboardFaultState(chartData: vibrations));
    } else if (alertCount > 3) {
      emit(DashboardAlertState(chartData: vibrations));
    } else if (warningCount > 3) {
      emit(DashboardWarningState(chartData: vibrations));
    } else {
      emit(DashboardNormalState(chartData: vibrations));
    }
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
