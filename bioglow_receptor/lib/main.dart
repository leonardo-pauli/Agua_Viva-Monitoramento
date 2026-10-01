import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';

import 'data/repositories/firebase_vibration_repository.dart';
import 'domain/usecases/export_history_usecase.dart';
import 'presentation/cubit/dashboard_cubit.dart';
import 'presentation/cubit/history_cubit.dart';
import 'presentation/screens/main_screen.dart';
import 'services/notification_service.dart';
import 'services/background_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

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
    // É recomendado inicializar instâncias que compartilham streams antes do MultiBlocProvider
    final repository = FirebaseVibrationRepository();
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
