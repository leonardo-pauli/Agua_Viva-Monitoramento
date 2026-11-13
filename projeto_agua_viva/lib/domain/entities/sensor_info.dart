/// Catálogo e metadados científicos dos 4 sensores da boia Bioglow.
///
/// Centraliza unidades, faixas ideais de referência para qualidade da água,
/// imagens ilustrativas, formatação e avaliação de dados tanto para o painel
/// ao vivo quanto para o relatório histórico do cartão SD.
library;

/// Caminho da ilustração principal da boia Bioglow.
const String kAssetBoiaBioglow = 'assets/images/boia_bioglow.png';

/// Os 4 módulos sensores físico-químicos da boia Bioglow.
enum TipoSensor {
  ph(
    id: 'ph',
    nome: 'pH da Água',
    nomeCurto: 'pH',
    subtitulo: 'Acidez / Alcalinidade',
    unidade: 'pH',
    assetImagem: 'assets/images/sensor_ph.png',
    casasDecimais: 2,
    escalaMin: 0,
    escalaMax: 14,
    idealMin: 6.5,
    idealMax: 8.5,
    atencaoMin: 6.0,
    atencaoMax: 9.0,
    descricaoFaixa: 'Ideal: 6,5 – 8,5 pH',
  ),
  temperatura(
    id: 'temperatura',
    nome: 'Temperatura',
    nomeCurto: 'Temp.',
    subtitulo: 'Temperatura da água',
    unidade: '°C',
    assetImagem: 'assets/images/sensor_temperatura.png',
    casasDecimais: 1,
    escalaMin: 0,
    escalaMax: 50,
    idealMin: 15.0,
    idealMax: 30.0,
    atencaoMin: 10.0,
    atencaoMax: 35.0,
    descricaoFaixa: 'Ref.: 15,0 – 30,0 °C',
  ),
  condutividade(
    id: 'condutividade',
    nome: 'Condutividade',
    nomeCurto: 'Condut.',
    subtitulo: 'Íons dissolvidos (CE)',
    unidade: 'µS/cm',
    assetImagem: 'assets/images/sensor_condutividade.png',
    casasDecimais: 1,
    escalaMin: 0,
    escalaMax: 2000,
    idealMin: 50.0,
    idealMax: 1500.0,
    atencaoMin: 10.0,
    atencaoMax: 2000.0,
    descricaoFaixa: 'Ref.: 50 – 1500 µS/cm',
  ),
  turbidez(
    id: 'turbidez',
    nome: 'Turbidez',
    nomeCurto: 'Turbidez',
    subtitulo: 'Partículas em suspensão',
    unidade: 'NTU',
    assetImagem: 'assets/images/sensor_turbidez.png',
    casasDecimais: 1,
    escalaMin: 0,
    escalaMax: 1000,
    idealMin: 0.0,
    idealMax: 40.0,
    atencaoMin: 0.0,
    atencaoMax: 100.0,
    descricaoFaixa: 'Ideal: < 40 NTU',
  );

  final String id;
  final String nome;
  final String nomeCurto;
  final String subtitulo;
  final String unidade;
  final String assetImagem;
  final int casasDecimais;
  final double escalaMin;
  final double escalaMax;
  final double idealMin;
  final double idealMax;
  final double atencaoMin;
  final double atencaoMax;
  final String descricaoFaixa;

  const TipoSensor({
    required this.id,
    required this.nome,
    required this.nomeCurto,
    required this.subtitulo,
    required this.unidade,
    required this.assetImagem,
    required this.casasDecimais,
    required this.escalaMin,
    required this.escalaMax,
    required this.idealMin,
    required this.idealMax,
    required this.atencaoMin,
    required this.atencaoMax,
    required this.descricaoFaixa,
  });

  /// Faixa ideal padrão deste sensor.
  FaixaIdealSensor get faixaPadrao =>
      FaixaIdealSensor(min: idealMin, max: idealMax);

  /// Formata um valor numérico de acordo com a precisão do sensor.
  String formatarValor(double? valor, {bool incluirUnidade = false}) {
    if (valor == null) return '--';
    final numero = valor.toStringAsFixed(casasDecimais);
    if (!incluirUnidade) return numero;
    return unidade == 'pH' ? '$numero pH' : '$numero $unidade';
  }

  /// Formata a descrição textual da faixa ideal (padrão ou personalizada).
  String formatarDescricaoFaixa([FaixaIdealSensor? faixa]) {
    if (faixa == null || faixa == faixaPadrao) return descricaoFaixa;
    final minTxt = formatarValor(faixa.min).replaceAll('.', ',');
    final maxTxt = formatarValor(faixa.max).replaceAll('.', ',');
    return 'Ideal: $minTxt – $maxTxt $unidade';
  }

  /// Valida um par (mínimo, máximo) para a faixa ideal deste sensor.
  /// Retorna uma mensagem de erro ou `null` se a faixa for válida.
  String? validarFaixa(double? min, double? max) {
    if (min == null || max == null || min.isNaN || max.isNaN) {
      return 'Informe valores numéricos válidos';
    }
    if (min < escalaMin || max > escalaMax) {
      return 'Use valores entre ${formatarValor(escalaMin)} e ${formatarValor(escalaMax)} $unidade';
    }
    if (min >= max) {
      return 'O valor mínimo deve ser menor que o máximo';
    }
    return null;
  }

  /// Avalia se o valor medido está dentro da faixa esperada para pesquisa.
  /// Quando uma [faixa] personalizada é fornecida, aplica margem automática
  /// de 15% da amplitude para a zona de atenção.
  StatusQualidadeSensor avaliar(double? valor, {FaixaIdealSensor? faixa}) {
    if (valor == null) return StatusQualidadeSensor.aguardandoHardware;
    if (faixa == null || faixa == faixaPadrao) {
      if (valor >= idealMin && valor <= idealMax) {
        return StatusQualidadeSensor.ideal;
      }
      if (valor >= atencaoMin && valor <= atencaoMax) {
        return StatusQualidadeSensor.atencao;
      }
      return StatusQualidadeSensor.alerta;
    }

    if (valor >= faixa.min && valor <= faixa.max) {
      return StatusQualidadeSensor.ideal;
    }
    final margem = (faixa.max - faixa.min) * 0.15;
    final minAtencao = (faixa.min - margem).clamp(escalaMin, escalaMax);
    final maxAtencao = (faixa.max + margem).clamp(escalaMin, escalaMax);
    if (valor >= minAtencao && valor <= maxAtencao) {
      return StatusQualidadeSensor.atencao;
    }
    return StatusQualidadeSensor.alerta;
  }
}

/// Limites mínimo e máximo da faixa ideal de um sensor.
class FaixaIdealSensor {
  final double min;
  final double max;

  const FaixaIdealSensor({
    required this.min,
    required this.max,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FaixaIdealSensor &&
          (min - other.min).abs() < 1e-6 &&
          (max - other.max).abs() < 1e-6;

  @override
  int get hashCode =>
      Object.hash(min.toStringAsFixed(4), max.toStringAsFixed(4));
}

/// Classificação rápida para auxiliar o pesquisador em campo.
enum StatusQualidadeSensor {
  aguardandoHardware('Aguardando sensor'),
  ideal('Faixa ideal'),
  atencao('Atenção'),
  alerta('Fora da faixa');

  final String rotulo;
  const StatusQualidadeSensor(this.rotulo);
}
