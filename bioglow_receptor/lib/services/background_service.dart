import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';

import '../data/repositories/web_socket_vibration_repository.dart';
import '../domain/usecases/monitor_anomaly_usecase.dart';
import 'notification_service.dart';

Future<void> initializeBackgroundService() async {
  final service = FlutterBackgroundService();

  await service.configure(
    androidConfiguration: AndroidConfiguration(
      // Executa quando o app estiver rodando ou em background
      onStart: onStart,
      autoStart: true,
      isForegroundMode: true, // Mantém em primeiro plano p/ SO não matar
      notificationChannelId: 'high_importance_channel',
      initialNotificationTitle: 'Monitoramento Bioglow',
      initialNotificationContent: 'O monitoramento da boia está ativo',
      foregroundServiceNotificationId: 888,
    ),
    iosConfiguration: IosConfiguration(
      autoStart: true,
      onForeground: onStart,
      onBackground: onIosBackground,
    ),
  );
}

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  // Inicialização necessária para rodar num isolate isolado
  DartPluginRegistrant.ensureInitialized();
  WidgetsFlutterBinding.ensureInitialized();

  final notificationService = NotificationService();
  await notificationService.initialize();

  final repository = WebSocketVibrationRepository();
  final monitorUseCase = MonitorAnomalyUseCase(repository);
  monitorUseCase.startMonitoring();

  // Permite comunicação com o serviço (ex: para pará-lo)
  if (service is AndroidServiceInstance) {
    service.on('setAsForeground').listen((event) {
      service.setAsForegroundService();
    });

    service.on('setAsBackground').listen((event) {
      service.setAsBackgroundService();
    });
  }

  service.on('stopService').listen((event) {
    monitorUseCase.stopMonitoring();
    service.stopSelf();
  });
}
