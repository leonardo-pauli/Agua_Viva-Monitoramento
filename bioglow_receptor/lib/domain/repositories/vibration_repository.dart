import '../entities/vibration_entity.dart';

abstract class VibrationRepository {
  Stream<List<VibrationEntity>> getVibrationStream();
}
