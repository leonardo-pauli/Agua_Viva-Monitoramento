import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/sensor_info.dart';
import '../theme/app_theme.dart';

/// Limites do eixo Y de um gráfico para qualquer grandeza física da boia.
class EscalaY {
  final double max;
  final double intervalo;
  const EscalaY(this.max, this.intervalo);

  /// Escala fixa padrão de acordo com a grandeza física do [sensor].
  static EscalaY padraoDoSensor(TipoSensor sensor) => switch (sensor) {
        TipoSensor.ph => const EscalaY(14, 2),
        TipoSensor.temperatura => const EscalaY(50, 10),
        TipoSensor.condutividade => const EscalaY(2000, 500),
        TipoSensor.turbidez => const EscalaY(1000, 250),
      };

  /// Escala "automática": ajusta o máximo aos dados, arredondando para
  /// valores redondos (1, 2, 2,5 ou 5 x 10^n por divisão, 4 divisões).
  /// Com [auto] = false ou sem dados, usa a escala completa do sensor.
  factory EscalaY.calcular(
    Iterable<double> valores, {
    required bool auto,
    TipoSensor sensor = TipoSensor.condutividade,
  }) {
    final completa = padraoDoSensor(sensor);
    if (!auto || valores.isEmpty) return completa;
    final maior = valores.reduce(math.max);
    final pisoMinimo = switch (sensor) {
      TipoSensor.ph => 4.0,
      TipoSensor.temperatura => 8.0,
      TipoSensor.condutividade => 20.0,
      TipoSensor.turbidez => 10.0,
    };
    final passo = _passoRedondo(math.max(maior * 1.1, pisoMinimo) / 4);
    final max = passo * 4;
    if (max >= completa.max) return completa;
    return EscalaY(max, passo);
  }

  static double _passoRedondo(double x) {
    final potencia = math.pow(10, (math.log(x) / math.ln10).floor()).toDouble();
    final f = x / potencia;
    final n = f <= 1
        ? 1.0
        : f <= 2
            ? 2.0
            : f <= 2.5
                ? 2.5
                : f <= 5
                    ? 5.0
                    : 10.0;
    return n * potencia;
  }
}

/// Rótulo do eixo Y sem casas decimais desnecessárias.
Widget rotuloEixoY(double valor, TitleMeta meta) => Text(
      valor == valor.roundToDouble()
          ? valor.toStringAsFixed(0)
          : valor.toStringAsFixed(1),
      style: const TextStyle(fontSize: 11.5),
    );

/// Botão que alterna entre escala automática e completa do sensor atual.
class BotaoEscala extends StatelessWidget {
  final bool auto;
  final ValueChanged<bool> onChanged;
  final TipoSensor sensor;

  const BotaoEscala({
    super.key,
    required this.auto,
    required this.onChanged,
    this.sensor = TipoSensor.ph,
  });

  @override
  Widget build(BuildContext context) {
    final faixaFixa =
        '0 - ${sensor.escalaMax.toStringAsFixed(0)} ${sensor.unidade}';
    final scheme = Theme.of(context).colorScheme;
    return IconButton(
      visualDensity: VisualDensity.compact,
      tooltip: auto
          ? 'Escala automática (toque para $faixaFixa)'
          : 'Escala $faixaFixa (toque para automática)',
      isSelected: auto,
      icon: IconePng(
        IconesApp.screen,
        size: 18,
        color: scheme.onSurfaceVariant,
      ),
      selectedIcon: IconePng(
        IconesApp.screen,
        size: 18,
        color: scheme.primary,
      ),
      onPressed: () => onChanged(!auto),
    );
  }
}
