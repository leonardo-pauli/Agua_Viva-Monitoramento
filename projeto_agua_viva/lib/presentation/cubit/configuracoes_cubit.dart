import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/configuracoes_repository.dart';
import '../../domain/entities/configuracoes.dart';
import '../../domain/entities/sensor_info.dart';

/// Estado global das preferências. Cada alteração é salva na hora.
class ConfiguracoesCubit extends Cubit<Configuracoes> {
  final ConfiguracoesRepository _repo;

  ConfiguracoesCubit(this._repo) : super(_repo.carregar());

  Future<void> _atualizar(Configuracoes nova) async {
    emit(nova);
    await _repo.salvar(nova);
  }

  void definirEndereco(String host, int porta) =>
      _atualizar(state.copyWith(host: host.trim(), porta: porta));

  void definirManterConexao(bool v) =>
      _atualizar(state.copyWith(manterConexaoEmSegundoPlano: v));

  void definirJanelaAoVivo(int minutos) =>
      _atualizar(state.copyWith(janelaAoVivoMin: minutos));

  void definirMaxPontosRelatorio(int pontos) =>
      _atualizar(state.copyWith(maxPontosRelatorio: pontos));

  void definirAvisoAusencia(bool v) =>
      _atualizar(state.copyWith(avisoAusencia: v));

  void definirLimiteAusencia(int minutos) =>
      _atualizar(state.copyWith(limiteAusenciaMin: minutos));

  void definirTema(TemaApp tema) => _atualizar(state.copyWith(tema: tema));

  void definirEscalaAutomatica(bool v) =>
      _atualizar(state.copyWith(escalaAutomatica: v));

  void definirModoAcessibilidade(bool v) =>
      _atualizar(state.copyWith(modoAcessibilidade: v));

  /// Define a faixa ideal (mínimo e máximo) de um [sensor] específico.
  Future<void> definirFaixaSensor(
    TipoSensor sensor,
    FaixaIdealSensor faixa,
  ) {
    final novas = Map<TipoSensor, FaixaIdealSensor>.from(state.faixasIdeais);
    if (faixa == sensor.faixaPadrao) {
      novas.remove(sensor);
    } else {
      novas[sensor] = faixa;
    }
    return _atualizar(state.copyWith(faixasIdeais: Map.unmodifiable(novas)));
  }

  /// Define de uma só vez as faixas ideais dos 4 sensores.
  Future<void> definirTodasFaixas(
    Map<TipoSensor, FaixaIdealSensor> faixas,
  ) {
    final novas = <TipoSensor, FaixaIdealSensor>{};
    for (final entry in faixas.entries) {
      if (entry.value != entry.key.faixaPadrao) {
        novas[entry.key] = entry.value;
      }
    }
    return _atualizar(state.copyWith(faixasIdeais: Map.unmodifiable(novas)));
  }

  /// Restaura a faixa ideal padrão de um único [sensor].
  Future<void> restaurarFaixaSensor(TipoSensor sensor) {
    final novas = Map<TipoSensor, FaixaIdealSensor>.from(state.faixasIdeais)
      ..remove(sensor);
    return _atualizar(state.copyWith(faixasIdeais: Map.unmodifiable(novas)));
  }

  /// Restaura todas as faixas ideais dos 4 sensores para os valores padrão.
  Future<void> restaurarTodasFaixasPadrao() =>
      _atualizar(state.copyWith(faixasIdeais: const {}));

  Future<void> restaurarPadroes() async {
    await _repo.limpar();
    emit(const Configuracoes());
  }
}
