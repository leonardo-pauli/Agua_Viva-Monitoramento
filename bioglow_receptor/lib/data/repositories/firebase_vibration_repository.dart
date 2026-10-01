import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:rxdart/rxdart.dart';
import '../../domain/entities/vibration_entity.dart';
import '../../domain/repositories/vibration_repository.dart';
import '../models/vibration_model.dart';

class FirebaseVibrationRepository implements VibrationRepository {
  final FirebaseDatabase _database;
  final List<VibrationEntity> _buffer = [];
  final int _maxWindowSize =
      500; // Aumentado para garantir que cabem 5 segundos mesmo com alta frequência

  FirebaseVibrationRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  @override
  Stream<List<VibrationEntity>> getVibrationStream() {
    return _database
        .ref('bioglow/test_data')
        // 3. Otimização: Escuta apenas os filhos novos em vez de baixar o banco inteiro a cada 10s
        .limitToLast(_maxWindowSize)
        .onChildAdded
        .map((event) {
          final value = event.snapshot.value;
          final key = event.snapshot.key;

          final entity = _parseSingleVibration(key, value);

          _buffer.add(entity);
          // 2. Aplica a "janela móvel" (sliding window) descartando os mais antigos
          if (_buffer.length > _maxWindowSize) {
            _buffer.removeAt(0);
          }

          // Retorna uma cópia imutável do buffer
          return List<VibrationEntity>.from(_buffer);
        })
        // 3. Throttling: Reduzido para 32ms (~30 fps) para uma animação muito mais fluida
        .throttleTime(const Duration(milliseconds: 32), trailing: true)
        .asBroadcastStream(); // Permite múltiplos listeners (Dashboard e Histórico)
  }

  VibrationEntity _parseSingleVibration(String? key, dynamic value) {
    if (value is Map) {
      return VibrationModel.fromMap(Map<String, dynamic>.from(value));
    } else {
      double mag = 0.0;
      if (value is num) mag = value.toDouble();
      if (value is String) mag = double.tryParse(value) ?? 0.0;

      int tsMs = DateTime.now().millisecondsSinceEpoch;
      final keyInt = int.tryParse(key ?? '');
      if (keyInt != null) tsMs = keyInt;

      return VibrationModel.fromMap({'frequencia': mag, 'timestamp': tsMs});
    }
  }

}
