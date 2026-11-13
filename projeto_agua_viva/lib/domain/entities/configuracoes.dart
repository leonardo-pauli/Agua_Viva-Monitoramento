/// Preferências do usuário, persistidas no aparelho.
library;

import 'sensor_info.dart';

enum TemaApp { sistema, claro, escuro }

class Configuracoes {
  static const String hostPadrao = '192.168.4.1';
  static const int portaPadrao = 81;

  /// Intervalo nominal entre leituras enviadas pela boia.
  static const Duration intervaloLeitura = Duration(seconds: 2);

  static const List<int> opcoesJanelaMin = [1, 2, 5, 10];
  static const List<int> opcoesPontosRelatorio = [300, 600, 1200, 2000];
  static const List<int> opcoesAusenciaMin = [1, 5, 15, 30, 60];

  /// Endereço da boia (IP ou nome) e porta do servidor WebSocket.
  final String host;
  final int porta;

  /// Se falso, a conexão é desligada após um tempo em segundo plano.
  final bool manterConexaoEmSegundoPlano;

  /// Janela (minutos) exibida no gráfico ao vivo.
  final int janelaAoVivoMin;

  /// Máximo de pontos pedidos à boia para o gráfico do relatório.
  final int maxPontosRelatorio;

  /// Ao voltar ao app após [limiteAusenciaMin], avisa sobre dados no SD.
  final bool avisoAusencia;
  final int limiteAusenciaMin;

  final TemaApp tema;

  /// Eixo Y ajustado aos dados (true) ou fixo em 0 - 4095 (false).
  final bool escalaAutomatica;

  /// Amplia globalmente todas as fontes do aplicativo para acessibilidade.
  final bool modoAcessibilidade;

  /// Faixas ideais personalizadas por sensor. Quando um sensor não consta
  /// neste mapa, utiliza-se [TipoSensor.faixaPadrao].
  final Map<TipoSensor, FaixaIdealSensor> faixasIdeais;

  const Configuracoes({
    this.host = hostPadrao,
    this.porta = portaPadrao,
    this.manterConexaoEmSegundoPlano = false,
    this.janelaAoVivoMin = 2,
    this.maxPontosRelatorio = 600,
    this.avisoAusencia = true,
    this.limiteAusenciaMin = 5,
    this.tema = TemaApp.escuro,
    this.escalaAutomatica = true,
    this.modoAcessibilidade = false,
    this.faixasIdeais = const {},
  });

  String get url => 'ws://$host:$porta';

  Duration get janelaAoVivo => Duration(minutes: janelaAoVivoMin);

  /// Quantas leituras cabem na janela ao vivo.
  int get maxHistoricoAoVivo =>
      janelaAoVivo.inMilliseconds ~/ intervaloLeitura.inMilliseconds;

  Duration get limiteAusencia => Duration(minutes: limiteAusenciaMin);

  /// Retorna a faixa ideal ativa (personalizada ou padrão) do [sensor].
  FaixaIdealSensor faixaDoSensor(TipoSensor sensor) =>
      faixasIdeais[sensor] ?? sensor.faixaPadrao;

  /// Indica se o [sensor] possui uma faixa personalizada diferente da padrão.
  bool temFaixaPersonalizada(TipoSensor sensor) {
    final f = faixasIdeais[sensor];
    return f != null && f != sensor.faixaPadrao;
  }

  /// Indica se algum sensor possui faixa personalizada.
  bool get possuiAlgumaFaixaPersonalizada =>
      TipoSensor.values.any(temFaixaPersonalizada);

  /// Retorna a descrição formatada da faixa ideal ativa do [sensor].
  String descricaoFaixaDoSensor(TipoSensor sensor) =>
      sensor.formatarDescricaoFaixa(faixaDoSensor(sensor));

  /// Avalia o [valor] do [sensor] considerando a faixa ideal configurada.
  StatusQualidadeSensor avaliarSensor(TipoSensor sensor, double? valor) =>
      sensor.avaliar(valor, faixa: faixaDoSensor(sensor));

  Configuracoes copyWith({
    String? host,
    int? porta,
    bool? manterConexaoEmSegundoPlano,
    int? janelaAoVivoMin,
    int? maxPontosRelatorio,
    bool? avisoAusencia,
    int? limiteAusenciaMin,
    TemaApp? tema,
    bool? escalaAutomatica,
    bool? modoAcessibilidade,
    Map<TipoSensor, FaixaIdealSensor>? faixasIdeais,
  }) {
    return Configuracoes(
      host: host ?? this.host,
      porta: porta ?? this.porta,
      manterConexaoEmSegundoPlano:
          manterConexaoEmSegundoPlano ?? this.manterConexaoEmSegundoPlano,
      janelaAoVivoMin: janelaAoVivoMin ?? this.janelaAoVivoMin,
      maxPontosRelatorio: maxPontosRelatorio ?? this.maxPontosRelatorio,
      avisoAusencia: avisoAusencia ?? this.avisoAusencia,
      limiteAusenciaMin: limiteAusenciaMin ?? this.limiteAusenciaMin,
      tema: tema ?? this.tema,
      escalaAutomatica: escalaAutomatica ?? this.escalaAutomatica,
      modoAcessibilidade: modoAcessibilidade ?? this.modoAcessibilidade,
      faixasIdeais: faixasIdeais ?? this.faixasIdeais,
    );
  }

  // ------------------------------------------------------------------
  // Validação de endereço
  // ------------------------------------------------------------------

  static final RegExp _hostValido = RegExp(r'^[A-Za-z0-9]([A-Za-z0-9.-]*[A-Za-z0-9])?$');

  /// Retorna uma mensagem de erro, ou null se o host for válido.
  static String? validarHost(String? v) {
    final s = v?.trim() ?? '';
    if (s.isEmpty) return 'Informe o IP ou nome da boia';
    if (!_hostValido.hasMatch(s)) return 'Endereço inválido';
    final partes = s.split('.');
    final pareceIp = partes.every((p) => int.tryParse(p) != null);
    if (pareceIp) {
      if (partes.length != 4 ||
          partes.any((p) => int.parse(p) < 0 || int.parse(p) > 255)) {
        return 'IP inválido (ex.: 192.168.4.1)';
      }
    }
    return null;
  }

  /// Retorna uma mensagem de erro, ou null se a porta for válida.
  static String? validarPorta(String? v) {
    final p = int.tryParse(v?.trim() ?? '');
    if (p == null || p < 1 || p > 65535) return 'Porta entre 1 e 65535';
    return null;
  }
}
