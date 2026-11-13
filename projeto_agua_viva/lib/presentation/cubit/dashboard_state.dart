import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/leitura_entity.dart';

class DashboardState {
  final StatusConexao status;
  final List<LeituraEntity> historico;
  final bool modoSimulacao;
  final bool simulandoAnomalia;

  const DashboardState({
    this.status = StatusConexao.conectando,
    this.historico = const [],
    this.modoSimulacao = false,
    this.simulandoAnomalia = false,
  });

  LeituraEntity? get ultima => historico.isEmpty ? null : historico.last;

  DashboardState copyWith({
    StatusConexao? status,
    List<LeituraEntity>? historico,
    bool? modoSimulacao,
    bool? simulandoAnomalia,
  }) {
    return DashboardState(
      status: status ?? this.status,
      historico: historico ?? this.historico,
      modoSimulacao: modoSimulacao ?? this.modoSimulacao,
      simulandoAnomalia: simulandoAnomalia ?? this.simulandoAnomalia,
    );
  }
}
