import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import 'data/esp32_websocket_service.dart';
import 'presentation/cubit/dashboard_cubit.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/widgets/ausencia_monitor.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const BioglowApp());
}

class BioglowApp extends StatelessWidget {
  const BioglowApp({super.key});

  @override
  Widget build(BuildContext context) {
    // O serviço é compartilhado entre o dashboard (leituras ao vivo) e o
    // relatório (dados do cartão SD). Quem o encerra é o DashboardCubit.
    return RepositoryProvider(
      create: (_) => Esp32WebSocketService(),
      child: BlocProvider(
        create: (ctx) => DashboardCubit(ctx.read<Esp32WebSocketService>()),
        child: MaterialApp(
          title: 'Bioglow Receptor',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            brightness: Brightness.dark,
            colorSchemeSeed: Colors.cyan,
            useMaterial3: true,
          ),
          home: const AusenciaMonitor(child: DashboardScreen()),
        ),
      ),
    );
  }
}
