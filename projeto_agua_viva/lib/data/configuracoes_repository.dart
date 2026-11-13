import 'package:shared_preferences/shared_preferences.dart';

import '../domain/entities/configuracoes.dart';
import '../domain/entities/sensor_info.dart';

/// Lê e grava [Configuracoes] no [SharedPreferences].
class ConfiguracoesRepository {
  static const _host = 'cfg_host';
  static const _porta = 'cfg_porta';
  static const _manterConexao = 'cfg_manter_conexao';
  static const _janela = 'cfg_janela_min';
  static const _pontos = 'cfg_pontos_relatorio';
  static const _aviso = 'cfg_aviso_ausencia';
  static const _ausencia = 'cfg_ausencia_min';
  static const _tema = 'cfg_tema';
  static const _escala = 'cfg_escala_auto';
  static const _modoAcessibilidade = 'cfg_modo_acessibilidade';
  static const _tutorialConcluido = 'cfg_tutorial_concluido';

  static String _chaveFaixaMin(TipoSensor s) => 'cfg_faixa_${s.id}_min';
  static String _chaveFaixaMax(TipoSensor s) => 'cfg_faixa_${s.id}_max';

  static const _chavesBase = [
    _host, _porta, _manterConexao, _janela, _pontos,
    _aviso, _ausencia, _tema, _escala, _modoAcessibilidade,
  ];

  final SharedPreferences _prefs;
  ConfiguracoesRepository(this._prefs);

  /// Indica se o usuário já visualizou a tela de boas-vindas/tutorial inicial.
  bool get tutorialConcluido => _prefs.getBool(_tutorialConcluido) ?? false;

  /// Salva que o usuário já concluiu o tutorial inicial.
  Future<void> marcarTutorialConcluido() =>
      _prefs.setBool(_tutorialConcluido, true);

  /// Carrega as preferências. Valores ausentes ou inválidos (ex.: de uma
  /// versão antiga) caem no padrão.
  Configuracoes carregar() {
    const d = Configuracoes();

    int opcao(String chave, List<int> opcoes, int padrao) {
      final v = _prefs.getInt(chave);
      return v != null && opcoes.contains(v) ? v : padrao;
    }

    final host = _prefs.getString(_host);
    final porta = _prefs.getInt(_porta);
    final tema = _prefs.getString(_tema);

    final faixas = <TipoSensor, FaixaIdealSensor>{};
    for (final s in TipoSensor.values) {
      final min = _prefs.getDouble(_chaveFaixaMin(s));
      final max = _prefs.getDouble(_chaveFaixaMax(s));
      if (min != null && max != null && s.validarFaixa(min, max) == null) {
        final f = FaixaIdealSensor(min: min, max: max);
        if (f != s.faixaPadrao) {
          faixas[s] = f;
        }
      }
    }

    return Configuracoes(
      host: host != null && Configuracoes.validarHost(host) == null
          ? host
          : d.host,
      porta: porta != null && Configuracoes.validarPorta('$porta') == null
          ? porta
          : d.porta,
      manterConexaoEmSegundoPlano:
          _prefs.getBool(_manterConexao) ?? d.manterConexaoEmSegundoPlano,
      janelaAoVivoMin:
          opcao(_janela, Configuracoes.opcoesJanelaMin, d.janelaAoVivoMin),
      maxPontosRelatorio: opcao(
          _pontos, Configuracoes.opcoesPontosRelatorio, d.maxPontosRelatorio),
      avisoAusencia: _prefs.getBool(_aviso) ?? d.avisoAusencia,
      limiteAusenciaMin: opcao(
          _ausencia, Configuracoes.opcoesAusenciaMin, d.limiteAusenciaMin),
      tema: TemaApp.values.asNameMap()[tema] ?? d.tema,
      escalaAutomatica: _prefs.getBool(_escala) ?? d.escalaAutomatica,
      modoAcessibilidade:
          _prefs.getBool(_modoAcessibilidade) ?? d.modoAcessibilidade,
      faixasIdeais: Map.unmodifiable(faixas),
    );
  }

  Future<void> salvar(Configuracoes c) async {
    final operacoes = <Future<bool>>[
      _prefs.setString(_host, c.host),
      _prefs.setInt(_porta, c.porta),
      _prefs.setBool(_manterConexao, c.manterConexaoEmSegundoPlano),
      _prefs.setInt(_janela, c.janelaAoVivoMin),
      _prefs.setInt(_pontos, c.maxPontosRelatorio),
      _prefs.setBool(_aviso, c.avisoAusencia),
      _prefs.setInt(_ausencia, c.limiteAusenciaMin),
      _prefs.setString(_tema, c.tema.name),
      _prefs.setBool(_escala, c.escalaAutomatica),
      _prefs.setBool(_modoAcessibilidade, c.modoAcessibilidade),
    ];

    for (final s in TipoSensor.values) {
      final f = c.faixasIdeais[s];
      if (f != null && f != s.faixaPadrao) {
        operacoes.add(_prefs.setDouble(_chaveFaixaMin(s), f.min));
        operacoes.add(_prefs.setDouble(_chaveFaixaMax(s), f.max));
      } else {
        operacoes.add(_prefs.remove(_chaveFaixaMin(s)));
        operacoes.add(_prefs.remove(_chaveFaixaMax(s)));
      }
    }

    await Future.wait(operacoes);
  }

  Future<void> limpar() async {
    final chavesFaixas = [
      for (final s in TipoSensor.values) ...[
        _chaveFaixaMin(s),
        _chaveFaixaMax(s),
      ],
    ];
    await Future.wait([
      ..._chavesBase.map(_prefs.remove),
      ...chavesFaixas.map(_prefs.remove),
    ]);
  }
}
