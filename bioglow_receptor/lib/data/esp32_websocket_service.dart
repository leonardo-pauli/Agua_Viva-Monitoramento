import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import '../domain/entities/historico_sd.dart';
import '../domain/entities/leitura_entity.dart';

enum StatusConexao { conectando, conectado, desconectado }

/// Conecta no servidor WebSocket do ESP32 (Access Point "Bioglow_Boia").
///
/// O IP padrão do ESP32 em modo softAP é 192.168.4.1 e o servidor
/// WebSocket roda na porta 81.
///
/// Além das leituras ao vivo, permite pedir ao ESP32 os dados gravados
/// no cartão SD (comandos "resumo" e "historico").
class Esp32WebSocketService {
  static const String url = 'ws://192.168.4.1:81';
  static const Duration _intervaloReconexao = Duration(seconds: 3);

  final _leituras = StreamController<LeituraEntity>.broadcast();
  final _status = StreamController<StatusConexao>.broadcast();

  WebSocketChannel? _channel;
  StreamSubscription? _sub;
  Timer? _timerReconexao;
  bool _encerrado = false;
  StatusConexao _statusAtual = StatusConexao.conectando;

  // Pedidos ao SD em andamento
  Completer<ResumoSd>? _pedidoResumo;
  Completer<HistoricoSd>? _pedidoHistorico;
  final List<PontoHistorico> _bufferHistorico = [];
  Timer? _timerHistorico;
  Duration _timeoutHistorico = const Duration(seconds: 60);

  Stream<LeituraEntity> get leituras => _leituras.stream;
  Stream<StatusConexao> get status => _status.stream;
  StatusConexao get statusAtual => _statusAtual;
  bool get conectado => _statusAtual == StatusConexao.conectado;

  void _setStatus(StatusConexao s) {
    _statusAtual = s;
    if (!_status.isClosed) _status.add(s);
  }

  Future<void> conectar() async {
    if (_encerrado) return;
    _timerReconexao?.cancel();
    await _fecharCanal();

    _setStatus(StatusConexao.conectando);

    try {
      final channel = WebSocketChannel.connect(Uri.parse(url));
      _channel = channel;

      // Aguarda o handshake. Se o celular não estiver na rede da boia,
      // isso falha e agendamos nova tentativa.
      await channel.ready.timeout(const Duration(seconds: 5));
      if (_encerrado || _channel != channel) return;

      _sub = channel.stream.listen(
        _onMensagem,
        onError: (Object e) {
          debugPrint('Bioglow WS erro: $e');
          _agendarReconexao();
        },
        onDone: () {
          debugPrint('Bioglow WS desconectado.');
          _agendarReconexao();
        },
        cancelOnError: true,
      );

      // Acerta o relógio da boia com a hora do celular
      _enviar({'cmd': 'sync', 'epoch_ms': epochLocalMs(DateTime.now())});

      _setStatus(StatusConexao.conectado);
    } catch (e) {
      debugPrint('Bioglow WS falha ao conectar: $e');
      _agendarReconexao();
    }
  }

  /// Aguarda até estar conectado (ou estourar o [timeout]).
  Future<bool> aguardarConexao(Duration timeout) async {
    if (conectado) return true;
    if (_statusAtual == StatusConexao.desconectado) conectar();
    try {
      await status
          .firstWhere((s) => s == StatusConexao.conectado)
          .timeout(timeout);
      return true;
    } catch (_) {
      return conectado;
    }
  }

  /// Pergunta ao ESP32 quantos registros existem no SD desde [desde].
  /// Retorna null se não houver conexão ou resposta.
  Future<ResumoSd?> pedirResumo(
    DateTime desde, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    if (!conectado) return null;
    final anterior = _pedidoResumo;
    if (anterior != null && !anterior.isCompleted) {
      anterior.completeError(StateError('substituído'));
    }
    final c = Completer<ResumoSd>();
    _pedidoResumo = c;
    _enviar({'cmd': 'resumo', 'desde': epochLocalSegundos(desde)});
    try {
      return await c.future.timeout(timeout);
    } catch (e) {
      debugPrint('Bioglow resumo falhou: $e');
      return null;
    } finally {
      if (identical(_pedidoResumo, c)) _pedidoResumo = null;
    }
  }

  /// Baixa do SD do ESP32 os registros desde [desde], reduzidos a no
  /// máximo [maxPontos] pontos. Retorna null se falhar.
  Future<HistoricoSd?> baixarHistorico(
    DateTime desde, {
    int maxPontos = 600,
    Duration timeoutSemResposta = const Duration(seconds: 60),
  }) async {
    if (!conectado) return null;
    final anterior = _pedidoHistorico;
    if (anterior != null && !anterior.isCompleted) {
      anterior.completeError(StateError('substituído'));
    }
    final c = Completer<HistoricoSd>();
    _pedidoHistorico = c;
    _bufferHistorico.clear();
    _timeoutHistorico = timeoutSemResposta;
    _reiniciarTimerHistorico();

    _enviar({
      'cmd': 'historico',
      'desde': epochLocalSegundos(desde),
      'max': maxPontos,
    });

    try {
      return await c.future;
    } catch (e) {
      debugPrint('Bioglow histórico falhou: $e');
      return null;
    } finally {
      if (identical(_pedidoHistorico, c)) {
        _pedidoHistorico = null;
        _timerHistorico?.cancel();
      }
    }
  }

  /// O timeout do histórico é reiniciado a cada bloco recebido, pois
  /// arquivos grandes podem levar um tempo para serem lidos pelo ESP32.
  void _reiniciarTimerHistorico() {
    _timerHistorico?.cancel();
    _timerHistorico = Timer(_timeoutHistorico, () {
      final c = _pedidoHistorico;
      if (c != null && !c.isCompleted) {
        c.completeError(TimeoutException('Sem resposta da boia'));
      }
    });
  }

  void _enviar(Map<String, dynamic> msg) {
    try {
      _channel?.sink.add(jsonEncode(msg));
    } catch (e) {
      debugPrint('Bioglow WS falha ao enviar: $e');
    }
  }

  void _onMensagem(dynamic mensagem) {
    try {
      final json = jsonDecode(mensagem.toString());
      if (json is! Map<String, dynamic>) return;

      switch (json['tipo']) {
        case 'resumo':
          final c = _pedidoResumo;
          if (c != null && !c.isCompleted) c.complete(ResumoSd.fromJson(json));
        case 'hist':
          final lista = json['p'];
          if (lista is List) {
            for (final item in lista) {
              final p = PontoHistorico.fromLista(item);
              if (p != null) _bufferHistorico.add(p);
            }
          }
          _reiniciarTimerHistorico();
        case 'hist_fim':
          _timerHistorico?.cancel();
          final c = _pedidoHistorico;
          if (c != null && !c.isCompleted) {
            c.complete(HistoricoSd(
              sdOk: json['sd'] != false,
              total: (json['total'] as num?)?.toInt() ?? 0,
              pontos: List.unmodifiable(_bufferHistorico),
            ));
          }
          _bufferHistorico.clear();
        case null:
        case 'leitura':
          _leituras.add(LeituraEntity.fromJson(json));
      }
    } catch (e) {
      debugPrint('Bioglow WS JSON inválido: $mensagem ($e)');
    }
  }

  void _falharPedidos(Object erro) {
    final r = _pedidoResumo;
    if (r != null && !r.isCompleted) r.completeError(erro);
    final h = _pedidoHistorico;
    if (h != null && !h.isCompleted) h.completeError(erro);
    _timerHistorico?.cancel();
  }

  void _agendarReconexao() {
    if (_encerrado) return;
    _falharPedidos(StateError('Conexão perdida'));
    _setStatus(StatusConexao.desconectado);
    _timerReconexao?.cancel();
    _timerReconexao = Timer(_intervaloReconexao, conectar);
  }

  Future<void> _fecharCanal() async {
    await _sub?.cancel();
    _sub = null;
    final ch = _channel;
    _channel = null;
    try {
      await ch?.sink.close();
    } catch (_) {}
  }

  Future<void> dispose() async {
    _encerrado = true;
    _timerReconexao?.cancel();
    _falharPedidos(StateError('Serviço encerrado'));
    await _fecharCanal();
    await _leituras.close();
    await _status.close();
  }
}
