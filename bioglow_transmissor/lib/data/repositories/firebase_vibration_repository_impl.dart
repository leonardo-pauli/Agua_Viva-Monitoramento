import 'package:firebase_database/firebase_database.dart';
import '../../domain/entities/vibration_entity.dart';
import '../../domain/repositories/vibration_repository.dart';

class FirebaseVibrationRepositoryImpl implements VibrationRepository {
  final FirebaseDatabase _database;

  FirebaseVibrationRepositoryImpl(this._database);

  @override
  Future<void> sendVibrationData(VibrationEntity vibration) async {
    final ref = _database.ref('bioglow/test_data');
    await ref.push().set({
      'frequencia': vibration.frequencia,
      'bateria': vibration.bateria,
      'sinal': vibration.sinal,
      'timestamp': vibration.timestamp.toIso8601String(),
    });
  }
}
