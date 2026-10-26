import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/leitura_entity.dart';

class DashboardState {
  final StatusConexao status;
  final List<LeituraEntity> historico;

  const DashboardState({
    this.status = StatusConexao.conectando,
    this.historico = const [],
  });

  LeituraEntity? get ultima => historico.isEmpty ? null : historico.last;

  DashboardState copyWith({
    StatusConexao? status,
    List<LeituraEntity>? historico,
  }) {
    return DashboardState(
      status: status ?? this.status,
      historico: historico ?? this.historico,
    );
  }
}
