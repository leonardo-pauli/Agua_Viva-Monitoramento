import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import '../../services/notification_service.dart';

class MonitorAnomalyUseCase {
  final FirebaseDatabase _database;
  final NotificationService _notificationService = NotificationService();
  
  Timer? _anomalyTimer;
  StreamSubscription<DatabaseEvent>? _subscription;
  bool _isAlertActive = false;

  MonitorAnomalyUseCase({FirebaseDatabase? database}) 
      : _database = database ?? FirebaseDatabase.instance;
  
  void startMonitoring() {
    final ref = _database.ref('bioglow/test_data');
    
    _subscription = ref.limitToLast(1).onChildAdded.listen((DatabaseEvent event) {
      if (event.snapshot.value == null) return;

      try {
        final value = event.snapshot.value;
        double magnitude = 0.0;
        
        if (value is Map) {
          final data = Map<String, dynamic>.from(value);
          if (data.containsKey('magnitude')) {
            magnitude = (data['magnitude'] as num).toDouble();
          } else if (data.containsKey('value')) {
            magnitude = (data['value'] as num).toDouble();
          }
        } else if (value is num) {
          magnitude = value.toDouble();
        } else if (value is String) {
          magnitude = double.tryParse(value) ?? 0.0;
        }

        _processData(magnitude);
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
