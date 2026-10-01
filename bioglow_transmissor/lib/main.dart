import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'firebase_options.dart';

import 'domain/usecases/send_vibration_usecase.dart';
import 'data/repositories/firebase_vibration_repository_impl.dart';
import 'presentation/cubit/transmitter_cubit.dart';
import 'presentation/pages/transmitter_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(const BioglowTransmitterApp());
}

class BioglowTransmitterApp extends StatelessWidget {
  const BioglowTransmitterApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Injeção de dependência simples
    final repository = FirebaseVibrationRepositoryImpl(FirebaseDatabase.instance);
    final useCase = SendVibrationUseCase(repository);

    return MaterialApp(
      title: 'Bioglow Transmissor',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,
      ),
      home: BlocProvider(
        create: (context) => TransmitterCubit(useCase),
        child: const TransmitterPage(),
      ),
    );
  }
}
