import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../services/notification_service.dart';
import '../repositories/vibration_repository.dart';
import '../entities/vibration_entity.dart';

class MonitorAnomalyUseCase {
  final VibrationRepository _repository;
  final NotificationService _notificationService = NotificationService();
  
  Timer? _anomalyTimer;
  StreamSubscription<List<VibrationEntity>>? _subscription;
  bool _isAlertActive = false;

  MonitorAnomalyUseCase(this._repository);
  
  void startMonitoring() {
    _subscription = _repository.getVibrationStream().listen((List<VibrationEntity> entities) {
      if (entities.isEmpty) return;

      try {
        final lastEntity = entities.last;
        _processData(lastEntity.magnitude);
      } catch (e) {
        debugPrint('Erro ao processar dado da boia no background: $e');
      }
    });
  }

  double? _lastMagnitude;
  int _stuckCount = 0;

  void _processData(double magnitude) {
    // Verifica falha (travado no mesmo valor ou zero)
    if (_lastMagnitude != null && magnitude == _lastMagnitude) {
      _stuckCount++;
      if (_stuckCount > 10) { // Se repetir por >10 leituras (aprox 10s dependendo da taxa de atualização)
        _anomalyTimer?.cancel();
        _triggerFaultAlert();
        return;
      }
    } else {
      _stuckCount = 0;
    }
    _lastMagnitude = magnitude;

    if (magnitude > 25.0) {
      // Alerta crítico imediato
      _anomalyTimer?.cancel();
      _triggerAlert(isCritical: true);
    } else if (magnitude > 15.0) {
      // Entrou na zona de atenção
      if (_anomalyTimer == null || !_anomalyTimer!.isActive) {
        _anomalyTimer = Timer(const Duration(seconds: 10), () {
          _triggerAlert(isCritical: false);
        });
      }
    } else {
      // Valor <= 15.0, reseta/cancela o timer
      _anomalyTimer?.cancel();
      _isAlertActive = false;
    }
  }

  void _triggerAlert({required bool isCritical}) {
    if (!_isAlertActive) {
      _isAlertActive = true;
      _notificationService.showHighPriorityNotification(
        title: isCritical ? 'ALERTA CRÍTICO BIOGLOW' : 'ATENÇÃO BIOGLOW',
        body: isCritical 
            ? 'Anomalia crítica detectada na boia (Acima de 25)!' 
            : 'Vibração em nível de sinalização na boia (Acima de 15)!',
      );
    }
  }

  void _triggerFaultAlert() {
    if (!_isAlertActive) {
      _isAlertActive = true;
      _notificationService.showHighPriorityNotification(
        title: 'FALHA DE LEITURA',
        body: 'O sensor parece estar travado ou inativo (sinal constante).',
      );
    }
  }

  void stopMonitoring() {
    _subscription?.cancel();
    _anomalyTimer?.cancel();
    _isAlertActive = false;
    _stuckCount = 0;
  }
}
