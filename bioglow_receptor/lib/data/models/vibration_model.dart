import '../../domain/entities/vibration_entity.dart';

class VibrationModel extends VibrationEntity {
  VibrationModel({
    required super.magnitude,
    required super.timestamp,
    super.bateria = 100,
    super.sinal = -50,
  });

  factory VibrationModel.fromMap(Map<dynamic, dynamic> map) {
    double parsedMagnitude = 0.0;
    if (map['frequencia'] != null) {
      if (map['frequencia'] is num) {
        parsedMagnitude = (map['frequencia'] as num).toDouble();
      } else if (map['frequencia'] is String) {
        parsedMagnitude = double.tryParse(map['frequencia']) ?? 0.0;
      }
    }

    DateTime parsedTimestamp = DateTime.now();
    if (map['timestamp'] != null) {
      if (map['timestamp'] is int) {
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(
          map['timestamp'] as int,
        );
      } else if (map['timestamp'] is double) {
        parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(
          (map['timestamp'] as double).toInt(),
        );
      } else if (map['timestamp'] is String) {
        final parsedInt = int.tryParse(map['timestamp']);
        if (parsedInt != null) {
          parsedTimestamp = DateTime.fromMillisecondsSinceEpoch(parsedInt);
        } else {
          parsedTimestamp =
              DateTime.tryParse(map['timestamp']) ?? DateTime.now();
        }
      }
    }

    int parsedBateria = 100;
    if (map['bateria'] != null) {
      if (map['bateria'] is num) {
        parsedBateria = (map['bateria'] as num).toInt();
      } else if (map['bateria'] is String) {
        parsedBateria = int.tryParse(map['bateria']) ?? 100;
      }
    }

    int parsedSinal = -50;
    if (map['sinal'] != null) {
      if (map['sinal'] is num) {
        parsedSinal = (map['sinal'] as num).toInt();
      } else if (map['sinal'] is String) {
        parsedSinal = int.tryParse(map['sinal']) ?? -50;
      }
    }

    return VibrationModel(
      magnitude: parsedMagnitude,
      timestamp: parsedTimestamp,
      bateria: parsedBateria,
      sinal: parsedSinal,
    );
  }
}
