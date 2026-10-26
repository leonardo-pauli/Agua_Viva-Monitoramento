/// Uma leitura enviada pela boia (ESP32).
///
/// JSON esperado:
/// {"data":"01/09/2026","hora":"10:00:02.000","rms":123.45,"pico":678}
class LeituraEntity {
  final String data;
  final String hora;
  final double rms;
  final int pico;

  /// Momento em que o celular recebeu a leitura.
  final DateTime recebidoEm;

  const LeituraEntity({
    required this.data,
    required this.hora,
    required this.rms,
    required this.pico,
    required this.recebidoEm,
  });

  factory LeituraEntity.fromJson(Map<String, dynamic> json) {
    return LeituraEntity(
      data: json['data']?.toString() ?? '--/--/----',
      hora: json['hora']?.toString() ?? '--:--:--',
      rms: _toDouble(json['rms']),
      pico: _toDouble(json['pico']).round(),
      recebidoEm: DateTime.now(),
    );
  }

  static double _toDouble(dynamic v) {
    if (v is num) return v.toDouble();
    return double.tryParse(v?.toString() ?? '') ?? 0.0;
  }
}
