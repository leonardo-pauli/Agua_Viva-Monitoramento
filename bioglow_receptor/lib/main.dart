import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/repositories/web_socket_vibration_repository.dart';
import 'domain/usecases/export_history_usecase.dart';
import 'presentation/cubit/dashboard_cubit.dart';
import 'presentation/cubit/history_cubit.dart';
import 'presentation/screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa o serviço de notificações
  final notificationService = NotificationService();
  await notificationService.initialize();
  await notificationService.requestPermissions();

  // Inicializa e inicia o serviço de background
  await initializeBackgroundService();

  runApp(const BioglowApp());
}

class BioglowApp extends StatelessWidget {
  const BioglowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Inicializa a conexão com o hardware via WebSocket Local
    final repository = WebSocketVibrationRepository();
    final exportUseCase = ExportHistoryUseCase();

    return MaterialApp(
      title: 'Bioglow Receptor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.blue,
        fontFamily: 'Inter',
      ),
      home: MultiBlocProvider(
        providers: [
          BlocProvider<DashboardCubit>(
            create: (context) => DashboardCubit(repository),
          ),
          BlocProvider<HistoryCubit>(
            create: (context) => HistoryCubit(repository, exportUseCase),
          ),
        ],
        child: const MainScreen(),
      ),
    );
  }
}
