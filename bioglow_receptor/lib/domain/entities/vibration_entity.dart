class VibrationEntity {
  final double magnitude;
  final DateTime timestamp;
  final int bateria;
  final int sinal;

  VibrationEntity({
    required this.magnitude,
    required this.timestamp,
    this.bateria = 100,
    this.sinal = -50,
  });
}
