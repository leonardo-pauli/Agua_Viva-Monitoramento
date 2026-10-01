import '../entities/vibration_entity.dart';
import '../repositories/vibration_repository.dart';

class SendVibrationUseCase {
  final VibrationRepository repository;

  SendVibrationUseCase(this.repository);

  Future<void> call(VibrationEntity vibration) async {
    await repository.sendVibrationData(vibration);
  }
}
