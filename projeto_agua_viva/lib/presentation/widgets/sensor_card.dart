import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/leitura_entity.dart';
import '../../domain/entities/sensor_info.dart';
import '../cubit/configuracoes_cubit.dart';
import '../theme/app_theme.dart';
import 'faixa_sensor_dialog.dart';

/// Barra horizontal de seleção de sensor para alternar os gráficos
/// (usada tanto no Dashboard ao vivo quanto no Relatório do cartão SD).
class SeletorSensorChips extends StatelessWidget {
  final TipoSensor selecionado;
  final ValueChanged<TipoSensor> onSelecionado;
  final bool Function(TipoSensor)? sensorPossuiDados;

  const SeletorSensorChips({
    super.key,
    required this.selecionado,
    required this.onSelecionado,
    this.sensorPossuiDados,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final resp = Responsivo.of(context);
    final dotSize = resp.isTablet ? 9.0 : 7.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final s in TipoSensor.values) ...[
            Builder(
              builder: (context) {
                final ativo = s == selecionado;
                final temDados = sensorPossuiDados?.call(s) ?? false;
                final corSensor = cores.corDoSensor(s);

                return Padding(
                  padding: EdgeInsets.only(right: resp.espaco(8)),
                  child: FilterChip(
                    selected: ativo,
                    showCheckmark: false,
                    padding: EdgeInsets.symmetric(
                      horizontal: resp.espaco(6),
                      vertical: resp.espaco(4),
                    ),
                    avatar: Icon(
                      iconeDoSensor(s),
                      size: resp.icone(16),
                      color: ativo
                          ? corSensor
                          : (temDados ? corSensor : scheme.outline),
                    ),
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          resp.isTablet ? s.nome : s.nomeCurto,
                          style: TextStyle(
                            fontWeight:
                                ativo ? FontWeight.w700 : FontWeight.w500,
                          ),
                        ),
                        SizedBox(width: resp.espaco(6)),
                        Container(
                          width: dotSize,
                          height: dotSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: temDados
                                ? cores.ok
                                : scheme.outline.withValues(alpha: 0.45),
                          ),
                        ),
                      ],
                    ),
                    selectedColor: corSensor.withValues(alpha: 0.16),
                    side: BorderSide(
                      color: ativo
                          ? corSensor.withValues(alpha: 0.7)
                          : scheme.outlineVariant.withValues(alpha: 0.5),
                    ),
                    onSelected: (_) => onSelecionado(s),
                  ),
                );
              },
            ),
          ],
        ],
      ),
    );
  }
}

/// Grade adaptativa (2x2 em celulares/tablets em retrato ou 4x1 em tablets em paisagem)
/// com os 4 sensores físico-químicos de qualidade da água.
class GradeSensoresQualidadeAgua extends StatelessWidget {
  final LeituraEntity? leitura;
  final TipoSensor sensorSelecionado;
  final ValueChanged<TipoSensor> onSelecionarSensor;

  const GradeSensoresQualidadeAgua({
    super.key,
    required this.leitura,
    required this.sensorSelecionado,
    required this.onSelecionarSensor,
  });

  @override
  Widget build(BuildContext context) {
    const sensores = TipoSensor.values;
    final resp = Responsivo.of(context);
    final gap = resp.espaco(12);

    Widget card(TipoSensor s) => Expanded(
          child: CardSensorFisicoQuimico(
            sensor: s,
            valor: leitura?.valorDoSensor(s),
            selecionado: sensorSelecionado == s,
            onTap: () => onSelecionarSensor(s),
          ),
        );

    if (resp.usarQuatroColunasSensores) {
      return Row(
        children: [
          card(sensores[0]),
          SizedBox(width: gap),
          card(sensores[1]),
          SizedBox(width: gap),
          card(sensores[2]),
          SizedBox(width: gap),
          card(sensores[3]),
        ],
      );
    }

    return Column(
      children: [
        Row(
          children: [
            card(sensores[0]), // pH
            SizedBox(width: gap),
            card(sensores[1]), // Temperatura
          ],
        ),
        SizedBox(height: gap),
        Row(
          children: [
            card(sensores[2]), // Condutividade
            SizedBox(width: gap),
            card(sensores[3]), // Turbidez
          ],
        ),
      ],
    );
  }
}

/// Card individual de um sensor físico-químico (pH, Temperatura, Condutividade, Turbidez).
class CardSensorFisicoQuimico extends StatelessWidget {
  final TipoSensor sensor;
  final double? valor;
  final bool selecionado;
  final VoidCallback? onTap;

  const CardSensorFisicoQuimico({
    super.key,
    required this.sensor,
    required this.valor,
    this.selecionado = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final resp = Responsivo.of(context);
    final corSensor = cores.corDoSensor(sensor);
    final faixa = context.select<ConfiguracoesCubit, FaixaIdealSensor>(
      (c) => c.state.faixaDoSensor(sensor),
    );
    final status = sensor.avaliar(valor, faixa: faixa);
    final corStatus = cores.corDoStatus(status, scheme);
    final conectado = valor != null;
    final dotSize = resp.isTablet ? 9.0 : 7.0;

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: selecionado
              ? corSensor.withValues(alpha: 0.8)
              : scheme.outlineVariant.withValues(alpha: 0.4),
          width: selecionado ? 1.8 : 1.0,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        onLongPress: () => mostrarDialogoFaixaSensor(context, sensor),
        child: Padding(
          padding: EdgeInsets.all(resp.espaco(14)),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: EdgeInsets.all(resp.espaco(7)),
                    decoration: BoxDecoration(
                      color: corSensor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      iconeDoSensor(sensor),
                      size: resp.icone(18),
                      color: corSensor,
                    ),
                  ),
                  Container(
                    width: dotSize,
                    height: dotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: corStatus,
                    ),
                  ),
                ],
              ),
              SizedBox(height: resp.espaco(8)),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  sensor.nome,
                  maxLines: 1,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
              SizedBox(height: resp.espaco(8)),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        sensor.formatarValor(valor),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: conectado
                              ? scheme.onSurface
                              : scheme.onSurfaceVariant.withValues(alpha: 0.55),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    sensor.unidade,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: corSensor,
                    ),
                  ),
                ],
              ),
              SizedBox(height: resp.espaco(8)),
              Text(
                conectado ? status.rotulo : 'Pino pendente',
                maxLines: 2,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: corStatus,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                sensor.formatarDescricaoFaixa(faixa),
                maxLines: 2,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
