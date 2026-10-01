import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../../domain/entities/vibration_entity.dart';
import '../../domain/repositories/vibration_repository.dart';
import '../models/vibration_model.dart';

class WebSocketVibrationRepository implements VibrationRepository {
  final String _wsUrl = 'ws://192.168.4.1:81';
  WebSocketChannel? _channel;

  final List<VibrationEntity> _buffer = [];
  final int _maxWindowSize = 500;

  // O StreamController.broadcast permite múltiplos listeners (Dashboard, Histórico, etc.)
  final StreamController<List<VibrationEntity>> _controller =
      StreamController<List<VibrationEntity>>.broadcast();

  WebSocketVibrationRepository() {
    _connect();
  }

  void _connect() {
    try {
      final uri = Uri.parse(_wsUrl);
      _channel = WebSocketChannel.connect(uri);
      
      // Evita o erro "Unhandled Exception" no console caso a conexão falhe fisicamente
      _channel!.ready.catchError((e) {
        debugPrint('Bioglow WebSocket: Falha física de conexão - $e');
      });

      _channel!.stream.listen(
        (message) {
          try {
            final Map<String, dynamic> data = jsonDecode(message.toString());

            // Tratamento de fallback para o timestamp caso o hardware não envie
            if (!data.containsKey('timestamp') || data['timestamp'] == null) {
              data['timestamp'] = DateTime.now().millisecondsSinceEpoch;
            }

            // O modelo já tem o tryParse e lida com os valores "frequencia", "bateria" e "sinal"
            final entity = VibrationModel.fromMap(data);

            _buffer.add(entity);
            if (_buffer.length > _maxWindowSize) {
              _buffer.removeAt(0);
            }

            _controller.add(List<VibrationEntity>.from(_buffer));
          } catch (e) {
            debugPrint('Bioglow WebSocket: Erro ao fazer parse do JSON - $e');
          }
        },
        onError: (error) {
          debugPrint('Bioglow WebSocket Erro: $error');
          _reconnect();
        },
        onDone: () {
          debugPrint('Bioglow WebSocket Desconectado do hardware.');
          _reconnect();
        },
      );
    } catch (e) {
      debugPrint('Bioglow WebSocket: Falha ao inicializar conexão - $e');
      _reconnect();
    }
  }

  void _reconnect() {
    // Tenta reconectar a cada 3 segundos caso a rede caia
    Future.delayed(const Duration(seconds: 3), () {
      if (!_controller.isClosed) {
        debugPrint('Bioglow WebSocket: Tentando reconectar...');
        _connect();
      }
    });
  }

  @override
  Stream<List<VibrationEntity>> getVibrationStream() {
    return _controller.stream;
  }

  void dispose() {
    _channel?.sink.close();
    _controller.close();
  }
}
