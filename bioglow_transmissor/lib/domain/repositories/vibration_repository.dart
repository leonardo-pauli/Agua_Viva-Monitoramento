import '../entities/vibration_entity.dart';

abstract class VibrationRepository {
  Future<void> sendVibrationData(VibrationEntity vibration);
}
