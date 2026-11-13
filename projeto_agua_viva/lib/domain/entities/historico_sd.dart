/// Entidades dos dados armazenados no cartão SD da boia.
///
/// O ESP32 trabalha com "epoch local": segundos desde 1970 da hora LOCAL
/// do celular tratada como se fosse UTC (o ESP32 não tem fuso horário).
library;

import 'sensor_info.dart';

/// Converte um [DateTime] para o "epoch local" usado pelo ESP32 (segundos).
int epochLocalSegundos(DateTime dt) =>
    (dt.millisecondsSinceEpoch + dt.timeZoneOffset.inMilliseconds) ~/ 1000;

/// Converte um [DateTime] para o "epoch local" usado pelo ESP32 (milissegundos).
int epochLocalMs(DateTime dt) =>
    dt.millisecondsSinceEpoch + dt.timeZoneOffset.inMilliseconds;

/// Converte o "epoch local" (segundos) do ESP32 de volta para [DateTime] local.
DateTime dataDeEpochLocal(int segundos) {
  final u = DateTime.fromMillisecondsSinceEpoch(segundos * 1000, isUtc: true);
  return DateTime(u.year, u.month, u.day, u.hour, u.minute, u.second);
}

int _toInt(dynamic v) {
  if (v is num) return v.toInt();
  return int.tryParse(v?.toString() ?? '') ?? 0;
}

double? _toDoubleOpcional(dynamic v, {double minimoValido = -50.0}) {
  if (v == null) return null;
  final double? d = v is num ? v.toDouble() : double.tryParse(v.toString());
  if (d == null || d.isNaN || d.isInfinite || d < minimoValido) return null;
  return d;
}

/// Resposta do comando "resumo": quantos registros existem no SD a partir
/// de um instante.
///
/// JSON: {"tipo":"resumo","sd":true,"total":150,"inicio":S,"fim":S}
class ResumoSd {
  final bool sdOk;
  final int total;
  final DateTime? inicio;
  final DateTime? fim;

  const ResumoSd({
    required this.sdOk,
    required this.total,
    this.inicio,
    this.fim,
  });

  factory ResumoSd.fromJson(Map<String, dynamic> json) {
    final total = _toInt(json['total']);
    final ini = _toInt(json['inicio']);
    final fim = _toInt(json['fim']);
    return ResumoSd(
      sdOk: json['sd'] != false,
      total: total,
      inicio: total > 0 && ini > 0 ? dataDeEpochLocal(ini) : null,
      fim: total > 0 && fim > 0 ? dataDeEpochLocal(fim) : null,
    );
  }
}

/// Um ponto do relatório do cartão SD com os 4 sensores físico-químicos.
///
/// Formato esperado no protocolo de histórico do SD (5 elementos):
/// `[ts, ph, temperatura, condutividade, turbidez]`
class PontoHistorico {
  final DateTime momento;
  final double? ph;
  final double? temperatura;
  final double? condutividade;
  final double? turbidez;

  const PontoHistorico({
    required this.momento,
    this.ph,
    this.temperatura,
    this.condutividade,
    this.turbidez,
  });

  double? valorDoSensor(TipoSensor sensor) => switch (sensor) {
        TipoSensor.ph => ph,
        TipoSensor.temperatura => temperatura,
        TipoSensor.condutividade => condutividade,
        TipoSensor.turbidez => turbidez,
      };

  static PontoHistorico? fromLista(dynamic v) {
    if (v is! List || v.isEmpty) return null;
    final ts = _toInt(v[0]);
    if (ts <= 0) return null;

    // Se vier no formato de 5 elementos: [ts, ph, temp, cond, turb]
    return PontoHistorico(
      momento: dataDeEpochLocal(ts),
      ph: v.length > 1 ? _toDoubleOpcional(v[1], minimoValido: 0.0) : null,
      temperatura:
          v.length > 2 ? _toDoubleOpcional(v[2], minimoValido: -20.0) : null,
      condutividade:
          v.length > 3 ? _toDoubleOpcional(v[3], minimoValido: 0.0) : null,
      turbidez:
          v.length > 4 ? _toDoubleOpcional(v[4], minimoValido: 0.0) : null,
    );
  }
}

/// Resultado completo do comando "historico".
class HistoricoSd {
  final bool sdOk;

  /// Quantidade de registros no SD no período (antes do agrupamento).
  final int total;
  final List<PontoHistorico> pontos;

  const HistoricoSd({
    required this.sdOk,
    required this.total,
    required this.pontos,
  });

  /// Verifica se há pelo menos um registro gravado no SD para o [sensor].
  bool possuiDadosDoSensor(TipoSensor sensor) =>
      pontos.any((p) => p.valorDoSensor(sensor) != null);
}
