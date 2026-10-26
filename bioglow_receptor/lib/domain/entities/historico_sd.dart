/// Entidades dos dados armazenados no cartão SD da boia.
///
/// O ESP32 trabalha com "epoch local": segundos desde 1970 da hora LOCAL
/// do celular tratada como se fosse UTC (o ESP32 não tem fuso horário).
library;

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

double _toDouble(dynamic v) {
  if (v is num) return v.toDouble();
  return double.tryParse(v?.toString() ?? '') ?? 0.0;
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

/// Um ponto do relatório (pode representar vários registros agrupados).
///
/// JSON: [ts, rms, pico]
class PontoHistorico {
  final DateTime momento;
  final double rms;
  final int pico;

  const PontoHistorico({
    required this.momento,
    required this.rms,
    required this.pico,
  });

  static PontoHistorico? fromLista(dynamic v) {
    if (v is! List || v.length < 3) return null;
    return PontoHistorico(
      momento: dataDeEpochLocal(_toInt(v[0])),
      rms: _toDouble(v[1]),
      pico: _toInt(v[2]),
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
}
