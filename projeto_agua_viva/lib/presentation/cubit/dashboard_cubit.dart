import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/configuracoes.dart';
import '../../domain/entities/leitura_entity.dart';
import '../../domain/entities/sensor_info.dart';
import 'configuracoes_cubit.dart';
import 'dashboard_state.dart';

class DashboardCubit extends Cubit<DashboardState> {
  /// Tempo em segundo plano antes de desligar a conexão (quando o usuário
  /// não pediu para mantê-la). Evita reconectar a cada troca rápida de app,
  /// mas poupa bateria se o usuário sair.
  static const Duration atrasoPausa = Duration(seconds: 30);

  final Esp32WebSocketService _service;
  final ConfiguracoesCubit _cfg;
  late final StreamSubscription _subLeituras;
  late final StreamSubscription _subStatus;
  late final StreamSubscription _subCfg;
  late final AppLifecycleListener _ciclo;
  Timer? _timerPausa;
  Timer? _timerSimulacao;
  int _passoSimulacao = 0;
  final math.Random _rng = math.Random();
  bool _emSegundoPlano = false;

  DashboardCubit(this._service, this._cfg) : super(const DashboardState()) {
    _subStatus = _service.status.listen((s) {
      if (state.modoSimulacao) return;
      emit(state.copyWith(status: s));
    });

    _subLeituras = _service.leituras.listen((leitura) {
      if (state.modoSimulacao) return;
      emit(state.copyWith(
        historico: _limitar([...state.historico, leitura]),
        status: StatusConexao.conectado,
      ));
    });

    _subCfg = _cfg.stream.listen(_aplicarConfiguracoes);

    _ciclo = AppLifecycleListener(
      onHide: () {
        _emSegundoPlano = true;
        _agendarPausa();
      },
      onShow: () {
        _emSegundoPlano = false;
        _timerPausa?.cancel();
        _service.retomar();
      },
    );

    _service.conectar();
  }

  int get maxHistorico => _cfg.state.maxHistoricoAoVivo;

  void _agendarPausa() {
    _timerPausa?.cancel();
    if (_cfg.state.manterConexaoEmSegundoPlano) return;
    _timerPausa = Timer(atrasoPausa, _service.pausar);
  }

  void _aplicarConfiguracoes(Configuracoes c) {
    _service.definirUrl(c.url);

    if (state.historico.length > c.maxHistoricoAoVivo) {
      emit(state.copyWith(historico: _limitar([...state.historico])));
    }

    if (_emSegundoPlano) {
      if (c.manterConexaoEmSegundoPlano) {
        _timerPausa?.cancel();
        _service.retomar();
      } else {
        _agendarPausa();
      }
    }
  }

  List<LeituraEntity> _limitar(List<LeituraEntity> lista) {
    if (lista.length > maxHistorico) {
      lista.removeRange(0, lista.length - maxHistorico);
    }
    return lista;
  }

  void reconectar() => _service.reconectar();

  /// Limpa o histórico ao vivo e devolve o que foi removido (para "Desfazer").
  List<LeituraEntity> limpar() {
    final anterior = state.historico;
    emit(state.copyWith(historico: const []));
    return anterior;
  }

  /// Restaura leituras removidas por [limpar], mantendo as que chegaram
  /// depois.
  void restaurar(List<LeituraEntity> removidas) {
    emit(state.copyWith(
      historico: _limitar([...removidas, ...state.historico]),
    ));
  }

  /// Ativa ou desativa o Modo Simulação Científica (para testar gráficos,
  /// alertas e exportação CSV mesmo sem os sensores físicos soldados).
  void definirModoSimulacao(bool ativo) {
    _timerSimulacao?.cancel();
    _timerSimulacao = null;

    if (!ativo) {
      emit(state.copyWith(
        modoSimulacao: false,
        simulandoAnomalia: false,
        historico: const [],
        status: _service.statusAtual,
      ));
      return;
    }

    final agora = DateTime.now();
    final iniciais = <LeituraEntity>[];
    for (var i = 20; i >= 0; i--) {
      final momento = agora.subtract(Duration(seconds: i * 2));
      iniciais.add(_gerarLeituraSimulada(momento, anomalia: false));
    }

    emit(state.copyWith(
      modoSimulacao: true,
      simulandoAnomalia: false,
      status: StatusConexao.conectado,
      historico: _limitar(iniciais),
    ));

    _timerSimulacao = Timer.periodic(const Duration(seconds: 2), (_) {
      if (!state.modoSimulacao) return;
      final nova = _gerarLeituraSimulada(
        DateTime.now(),
        anomalia: state.simulandoAnomalia,
      );
      emit(state.copyWith(
        historico: _limitar([...state.historico, nova]),
      ));
    });
  }

  /// Alterna entre condições normais da água e simulação de anomalia ambiental.
  void alternarAnomaliaSimulada() {
    if (!state.modoSimulacao) return;
    final novoValor = !state.simulandoAnomalia;
    final novaLeitura = _gerarLeituraSimulada(
      DateTime.now(),
      anomalia: novoValor,
    );
    emit(state.copyWith(
      simulandoAnomalia: novoValor,
      historico: _limitar([...state.historico, novaLeitura]),
    ));
  }

  LeituraEntity _gerarLeituraSimulada(
    DateTime momento, {
    required bool anomalia,
  }) {
    _passoSimulacao++;
    final t = _passoSimulacao * 0.25;
    final cfg = _cfg.state;
    double ruido() => _rng.nextDouble() - 0.5;

    final ph = _simularValorSensor(
      TipoSensor.ph,
      cfg.faixaDoSensor(TipoSensor.ph),
      anomalia: anomalia,
      onda: math.sin(t * 0.7),
      ruido: ruido(),
    );
    final temp = _simularValorSensor(
      TipoSensor.temperatura,
      cfg.faixaDoSensor(TipoSensor.temperatura),
      anomalia: anomalia,
      onda: anomalia ? math.cos(t * 0.5) : math.sin(t * 0.4),
      ruido: ruido(),
    );
    final cond = _simularValorSensor(
      TipoSensor.condutividade,
      cfg.faixaDoSensor(TipoSensor.condutividade),
      anomalia: anomalia,
      onda: anomalia ? math.sin(t * 0.8) : math.cos(t * 0.6),
      ruido: ruido(),
    );
    final turb = _simularValorSensor(
      TipoSensor.turbidez,
      cfg.faixaDoSensor(TipoSensor.turbidez),
      anomalia: anomalia,
      onda: anomalia ? math.sin(t * 0.9) : math.sin(t * 0.5),
      ruido: ruido(),
    );

    String dois(int n) => n.toString().padLeft(2, '0');
    final data =
        '${dois(momento.day)}/${dois(momento.month)}/${momento.year}';
    final hora =
        '${dois(momento.hour)}:${dois(momento.minute)}:${dois(momento.second)}';

    return LeituraEntity(
      data: data,
      hora: hora,
      recebidoEm: momento,
      ph: ph,
      temperatura: temp,
      condutividade: cond,
      turbidez: turb,
    );
  }

  /// Gera um valor simulado para [sensor] adaptado à [faixa] configurada:
  /// em condição normal permanece dentro da faixa ideal; em [anomalia]
  /// escolhe o lado com mais folga na escala física para ficar fora da faixa.
  double _simularValorSensor(
    TipoSensor sensor,
    FaixaIdealSensor faixa, {
    required bool anomalia,
    required double onda,
    required double ruido,
  }) {
    final amplitude = math.max(0.01, faixa.max - faixa.min);
    final fator = math.pow(10, sensor.casasDecimais).toDouble();
    final passo = 1.0 / fator;

    double valor;
    var limiteMin = sensor.escalaMin;
    var limiteMax = sensor.escalaMax;

    if (!anomalia) {
      final centro = (faixa.min + faixa.max) / 2.0;
      valor = centro + onda * (amplitude * 0.22) + ruido * (amplitude * 0.08);
      limiteMin = faixa.min;
      limiteMax = faixa.max;
    } else {
      final padrao = faixa == sensor.faixaPadrao;
      final margem = amplitude * 0.15;
      final minAtencao = padrao
          ? sensor.atencaoMin
          : (faixa.min - margem)
              .clamp(sensor.escalaMin, sensor.escalaMax)
              .toDouble();
      final maxAtencao = padrao
          ? sensor.atencaoMax
          : (faixa.max + margem)
              .clamp(sensor.escalaMin, sensor.escalaMax)
              .toDouble();

      final folgaAlertaAcima = math.max(0.0, sensor.escalaMax - maxAtencao);
      final folgaAlertaAbaixo = math.max(0.0, minAtencao - sensor.escalaMin);
      final folgaForaAcima = math.max(0.0, sensor.escalaMax - faixa.max);
      final folgaForaAbaixo = math.max(0.0, faixa.min - sensor.escalaMin);

      final temFolgaAlerta =
          folgaAlertaAcima >= passo || folgaAlertaAbaixo >= passo;
      final usarAcima = temFolgaAlerta
          ? folgaAlertaAcima >= folgaAlertaAbaixo
          : folgaForaAcima >= folgaForaAbaixo;

      final folga = temFolgaAlerta
          ? (usarAcima ? folgaAlertaAcima : folgaAlertaAbaixo)
          : (usarAcima ? folgaForaAcima : folgaForaAbaixo);
      final base = temFolgaAlerta
          ? (usarAcima ? maxAtencao : minAtencao)
          : (usarAcima ? faixa.max : faixa.min);

      if (folga < passo) {
        valor = usarAcima ? sensor.escalaMax : sensor.escalaMin;
      } else {
        final limiteFora = usarAcima
            ? math.min(sensor.escalaMax, ((base * fator).floor() + 1) / fator)
            : math.max(sensor.escalaMin, ((base * fator).ceil() - 1) / fator);
        if (usarAcima) {
          limiteMin = limiteFora;
        } else {
          limiteMax = limiteFora;
        }

        final spanEscala = sensor.escalaMax - sensor.escalaMin;
        final desvioDesejado = math.min(
          folga * 0.55,
          math.max(amplitude * 0.35, spanEscala * 0.08),
        );
        final sinal = usarAcima ? 1.0 : -1.0;
        final centro = (base + sinal * desvioDesejado)
            .clamp(limiteMin, limiteMax)
            .toDouble();
        final ampOnda = math.min(desvioDesejado * 0.28, folga * 0.18);
        valor = centro + onda * ampOnda + ruido * (ampOnda * 0.35);
      }
    }

    final ajustado = valor.clamp(limiteMin, limiteMax).toDouble();
    final arredondado =
        double.parse(ajustado.toStringAsFixed(sensor.casasDecimais));
    return arredondado.clamp(limiteMin, limiteMax).toDouble();
  }

  @override
  Future<void> close() async {
    _timerPausa?.cancel();
    _timerSimulacao?.cancel();
    _ciclo.dispose();
    await _subCfg.cancel();
    await _subLeituras.cancel();
    await _subStatus.cancel();
    await _service.dispose();
    return super.close();
  }
}
