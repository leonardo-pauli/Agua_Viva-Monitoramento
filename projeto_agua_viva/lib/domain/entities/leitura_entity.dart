import 'configuracoes.dart';
import 'sensor_info.dart';

/// Uma leitura multiparamétrica enviada pela boia (ESP32) com os 4 sensores
/// de qualidade da água (pH, Temperatura, Condutividade e Turbidez).
///
/// JSON esperado do ESP32:
/// `{"tipo":"leitura","ts":1788256802,"data":"06/11/2026","hora":"10:00:02.000","ph":7.18,"temp":24.5,"cond":412.0,"turb":14.2}`
class LeituraEntity {
  final String data;
  final String hora;

  // Os 4 sensores de qualidade da água (nulos enquanto não conectados no ESP32)
  final double? ph;
  final double? temperatura;
  final double? condutividade;
  final double? turbidez;

  /// Momento em que o celular recebeu a leitura.
  final DateTime recebidoEm;

  const LeituraEntity({
    required this.data,
    required this.hora,
    required this.recebidoEm,
    this.ph,
    this.temperatura,
    this.condutividade,
    this.turbidez,
  });

  factory LeituraEntity.fromJson(Map<String, dynamic> json) {
    return LeituraEntity(
      data: json['data']?.toString() ?? '--/--/----',
      hora: json['hora']?.toString() ?? '--:--:--',
      ph: _toDoubleOrNull(json['ph_val'] ?? json['ph']),
      temperatura: _toDoubleOrNull(
        json['temp_C'] ?? json['temperatura'] ?? json['temp'],
      ),
      condutividade: _toDoubleOrNull(
        json['ec_us_cm'] ??
            json['condutividade'] ??
            json['cond'] ??
            json['ce'] ??
            json['tds_ppm'],
      ),
      turbidez: _toDoubleOrNull(
        json['turb_ntu'] ?? json['turbidez'] ?? json['turb'],
      ),
      recebidoEm: DateTime.now(),
    );
  }

  /// Retorna o valor medido pelo [sensor] nesta leitura.
  double? valorDoSensor(TipoSensor sensor) => switch (sensor) {
    TipoSensor.ph => ph,
    TipoSensor.temperatura => temperatura,
    TipoSensor.condutividade => condutividade,
    TipoSensor.turbidez => turbidez,
  };

  /// Indica se o [sensor] enviou dado válido nesta leitura.
  bool sensorAtivo(TipoSensor sensor) => valorDoSensor(sensor) != null;

  /// Quantos sensores (de 4) estão enviando dados ativos nesta leitura.
  int get sensoresAtivosCount => TipoSensor.values.where(sensorAtivo).length;

  static const String cabecalhoCsv =
      'data;hora;'
      'ph_min;ph_max;ph_lido;'
      'temperatura_min;temperatura_max;temperatura_lido;'
      'condutividade_min;condutividade_max;condutividade_lido;'
      'turbidez_min;turbidez_max;turbidez_lido';

  static const String cabecalhoCsvRelatorioSd =
      'data_hora;'
      'ph_min;ph_max;ph_lido;'
      'temperatura_min;temperatura_max;temperatura_lido;'
      'condutividade_min;condutividade_max;condutividade_lido;'
      'turbidez_min;turbidez_max;turbidez_lido';

  /// Formata os 3 parâmetros (min, max da faixa configurada pelo usuário e valor lido)
  /// para cada um dos 4 sensores em colunas separadas por `;`.
  static List<String> colunasSensoresCsv({
    required Configuracoes config,
    double? ph,
    double? temperatura,
    double? condutividade,
    double? turbidez,
  }) {
    final fPh = config.faixaDoSensor(TipoSensor.ph);
    final fTemp = config.faixaDoSensor(TipoSensor.temperatura);
    final fCond = config.faixaDoSensor(TipoSensor.condutividade);
    final fTurb = config.faixaDoSensor(TipoSensor.turbidez);

    return [
      fPh.min.toStringAsFixed(2),
      fPh.max.toStringAsFixed(2),
      ph?.toStringAsFixed(2) ?? '',
      fTemp.min.toStringAsFixed(1),
      fTemp.max.toStringAsFixed(1),
      temperatura?.toStringAsFixed(1) ?? '',
      fCond.min.toStringAsFixed(1),
      fCond.max.toStringAsFixed(1),
      condutividade?.toStringAsFixed(1) ?? '',
      fTurb.min.toStringAsFixed(1),
      fTurb.max.toStringAsFixed(1),
      turbidez?.toStringAsFixed(1) ?? '',
    ];
  }

  String toCsvLine([Configuracoes config = const Configuracoes()]) => [
    data,
    hora,
    ...colunasSensoresCsv(
      config: config,
      ph: ph,
      temperatura: temperatura,
      condutividade: condutividade,
      turbidez: turbidez,
    ),
  ].join(';');

  static double? _toDoubleOrNull(dynamic v) {
    if (v == null) return null;
    final double? parsed = v is num
        ? v.toDouble()
        : double.tryParse(v.toString());
    if (parsed == null || parsed.isNaN || parsed.isInfinite) return null;
    // Valores negativos de sentinela (ex.: -1 ou -999 quando desconectado)
    if (parsed <= -99) return null;
    return parsed;
  }
}
