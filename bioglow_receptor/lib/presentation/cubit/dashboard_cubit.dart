import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  /// Quantidade de leituras mantidas para o gráfico/lista
  /// (60 leituras x 2 s = 2 minutos).
  static const int maxHistorico = 60;

  final Esp32WebSocketService _service;
  late final StreamSubscription _subLeituras;
  late final StreamSubscription _subStatus;

  DashboardCubit(this._service) : super(const DashboardState()) {
    _subStatus = _service.status.listen((s) {
      emit(state.copyWith(status: s));
    });

    _subLeituras = _service.leituras.listen((leitura) {
      final lista = [...state.historico, leitura];
      if (lista.length > maxHistorico) {
        lista.removeRange(0, lista.length - maxHistorico);
      }
      emit(state.copyWith(historico: lista, status: StatusConexao.conectado));
    });

    _service.conectar();
  }

  void reconectar() => _service.conectar();

  void limpar() => emit(state.copyWith(historico: const []));

  @override
  Future<void> close() async {
    await _subLeituras.cancel();
    await _subStatus.cancel();
    await _service.dispose();
    return super.close();
  }
}
