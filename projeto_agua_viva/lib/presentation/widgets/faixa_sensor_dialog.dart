import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/sensor_info.dart';
import '../cubit/configuracoes_cubit.dart';
import '../theme/app_theme.dart';
import 'dialogo_bioglow.dart';

double? _parseNumeroFlexivel(String? texto) {
  if (texto == null) return null;
  final limpo = texto.trim().replaceAll(',', '.');
  if (limpo.isEmpty) return null;
  return double.tryParse(limpo);
}

/// Abre o diálogo para editar a faixa ideal (Mínimo e Máximo) de um único [sensor].
Future<void> mostrarDialogoFaixaSensor(
  BuildContext context,
  TipoSensor sensor,
) async {
  final cubit = context.read<ConfiguracoesCubit>();
  final faixaAtual = cubit.state.faixaDoSensor(sensor);

  final novaFaixa = await showDialog<FaixaIdealSensor>(
    context: context,
    builder: (_) => _DialogoFaixaUnicoSensor(
      sensor: sensor,
      faixaInicial: faixaAtual,
    ),
  );

  if (novaFaixa == null || !context.mounted) return;
  await cubit.definirFaixaSensor(sensor, novaFaixa);
}

/// Abre o diálogo para configurar simultaneamente o Mínimo e o Máximo dos 4 sensores.
/// Retorna `true` se o usuário salvou as faixas.
Future<bool> mostrarDialogoTodasFaixasSensores(BuildContext context) async {
  final cubit = context.read<ConfiguracoesCubit>();
  final faixasIniciais = {
    for (final s in TipoSensor.values) s: cubit.state.faixaDoSensor(s),
  };

  final novasFaixas = await showDialog<Map<TipoSensor, FaixaIdealSensor>>(
    context: context,
    builder: (_) => _DialogoTodasFaixasSensores(faixasIniciais: faixasIniciais),
  );

  if (novasFaixas == null || !context.mounted) return false;
  await cubit.definirTodasFaixas(novasFaixas);
  return true;
}

/// Pergunta ao usuário, ao concluir o tutorial inicial pela primeira vez, se
/// deseja personalizar as faixas ideais agora ou seguir com os valores comuns.
Future<void> mostrarEscolhaInicialFaixas(BuildContext context) async {
  final personalizarAgora = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) {
      final scheme = Theme.of(ctx).colorScheme;
      final cores = CoresBioglow.of(ctx);

      return AlertDialog(
        icon: Icon(
          Icons.tune_rounded,
          size: 30,
          color: scheme.primary,
        ),
        title: const Text(
          'Faixas Ideais dos Sensores',
          textAlign: TextAlign.center,
        ),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Você pode definir o valor mínimo e máximo ideal de cada '
                  'sensor para o seu estudo, ou começar com os valores comuns '
                  'de referência:',
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: 12),
                for (final s in TipoSensor.values)
                  Container(
                    width: double.infinity,
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: cores.corDoSensor(s).withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: cores.corDoSensor(s).withValues(alpha: 0.30),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              iconeDoSensor(s),
                              size: 18,
                              color: cores.corDoSensor(s),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                s.nome,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Faixa comum: ${s.formatarValor(s.idealMin)} – ${s.formatarValor(s.idealMax)} ${s.unidade}',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: cores.corDoSensor(s),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info_outline_rounded,
                        size: 16,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Esses limites podem ser alterados a qualquer momento '
                          'na tela de Configurações.',
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        actionsAlignment: MainAxisAlignment.end,
        actionsOverflowButtonSpacing: 8,
        actions: [
          OutlinedButton.icon(
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: const Text('Personalizar agora'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(ctx).pop(false),
            icon: const Icon(Icons.check_rounded, size: 18),
            label: const Text('Seguir com comuns'),
          ),
        ],
      );
    },
  );

  if (personalizarAgora == true && context.mounted) {
    await mostrarDialogoTodasFaixasSensores(context);
  }
}

class _CamposMinMaxFaixa extends StatelessWidget {
  final TipoSensor sensor;
  final TextEditingController minCtrl;
  final TextEditingController maxCtrl;
  final Color corSensor;
  final bool autofocusMin;
  final TextInputAction textInputActionMax;
  final VoidCallback? onChanged;
  final VoidCallback? onSubmittedMax;

  const _CamposMinMaxFaixa({
    required this.sensor,
    required this.minCtrl,
    required this.maxCtrl,
    required this.corSensor,
    this.autofocusMin = false,
    this.textInputActionMax = TextInputAction.done,
    this.onChanged,
    this.onSubmittedMax,
  });

  @override
  Widget build(BuildContext context) {
    final fatorFonte = MediaQuery.textScalerOf(context).scale(14.0) / 14.0;
    const paddingCampo = EdgeInsets.symmetric(horizontal: 10, vertical: 12);

    return LayoutBuilder(
      builder: (context, constraints) {
        final empilharVerticalmente =
            constraints.maxWidth < 260 || fatorFonte >= 1.25;

        final campoMin = TextFormField(
          controller: minCtrl,
          autofocus: autofocusMin,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: TextInputAction.next,
          scrollPadding: const EdgeInsets.only(bottom: 84),
          decoration: DialogoBioglow.decoracaoCampo(
            context,
            label: 'Mínimo',
            suffixText: sensor.unidade,
            corFoco: corSensor,
            contentPadding: paddingCampo,
          ),
          onChanged: onChanged != null ? (_) => onChanged!() : null,
        );

        final campoMax = TextFormField(
          controller: maxCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textInputAction: textInputActionMax,
          scrollPadding: const EdgeInsets.only(bottom: 84),
          decoration: DialogoBioglow.decoracaoCampo(
            context,
            label: 'Máximo',
            suffixText: sensor.unidade,
            corFoco: corSensor,
            contentPadding: paddingCampo,
          ),
          onChanged: onChanged != null ? (_) => onChanged!() : null,
          onFieldSubmitted:
              onSubmittedMax != null ? (_) => onSubmittedMax!() : null,
        );

        if (empilharVerticalmente) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              campoMin,
              const SizedBox(height: 10),
              campoMax,
            ],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: campoMin),
            const SizedBox(width: 10),
            Expanded(child: campoMax),
          ],
        );
      },
    );
  }
}

Widget _bannerErroFaixa(BuildContext context, String mensagem) {
  final scheme = Theme.of(context).colorScheme;
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: scheme.error.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: scheme.error.withValues(alpha: 0.40)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.error_outline_rounded, size: 16, color: scheme.error),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensagem,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.error,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DialogoFaixaUnicoSensor extends StatefulWidget {
  final TipoSensor sensor;
  final FaixaIdealSensor faixaInicial;

  const _DialogoFaixaUnicoSensor({
    required this.sensor,
    required this.faixaInicial,
  });

  @override
  State<_DialogoFaixaUnicoSensor> createState() =>
      _DialogoFaixaUnicoSensorState();
}

class _DialogoFaixaUnicoSensorState extends State<_DialogoFaixaUnicoSensor> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _minCtrl;
  late final TextEditingController _maxCtrl;
  String? _erroFaixa;

  @override
  void initState() {
    super.initState();
    _minCtrl = TextEditingController(
      text: widget.sensor.formatarValor(widget.faixaInicial.min),
    );
    _maxCtrl = TextEditingController(
      text: widget.sensor.formatarValor(widget.faixaInicial.max),
    );
  }

  @override
  void dispose() {
    _minCtrl.dispose();
    _maxCtrl.dispose();
    super.dispose();
  }

  void _restaurarPadrao() {
    setState(() {
      _minCtrl.text = widget.sensor.formatarValor(widget.sensor.idealMin);
      _maxCtrl.text = widget.sensor.formatarValor(widget.sensor.idealMax);
      _erroFaixa = null;
    });
  }

  void _salvar() {
    final min = _parseNumeroFlexivel(_minCtrl.text);
    final max = _parseNumeroFlexivel(_maxCtrl.text);
    final erro = widget.sensor.validarFaixa(min, max);
    if (erro != null) {
      setState(() => _erroFaixa = erro);
      return;
    }
    Navigator.of(context).pop(FaixaIdealSensor(min: min!, max: max!));
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.sensor;
    final cores = CoresBioglow.of(context);
    final cor = cores.corDoSensor(s);
    final scheme = Theme.of(context).colorScheme;

    return DialogoBioglow(
      corDestaque: cor,
      icone: Icon(iconeDoSensor(s), color: cor, size: 22),
      titulo: 'Faixa Ideal • ${s.nome}',
      subtitulo:
          'Escala: ${s.formatarValor(s.escalaMin)} a ${s.formatarValor(s.escalaMax)} ${s.unidade}',
      corpo: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest.withValues(alpha: 0.32),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline_rounded, size: 16, color: cor),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Padrão comum: ${s.formatarValor(s.idealMin)} – '
                      '${s.formatarValor(s.idealMax)} ${s.unidade}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w500,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _CamposMinMaxFaixa(
              sensor: s,
              minCtrl: _minCtrl,
              maxCtrl: _maxCtrl,
              corSensor: cor,
              autofocusMin: true,
              onChanged: () {
                if (_erroFaixa != null) {
                  setState(() => _erroFaixa = null);
                }
              },
              onSubmittedMax: _salvar,
            ),
            if (_erroFaixa != null) ...[
              const SizedBox(height: 10),
              _bannerErroFaixa(context, _erroFaixa!),
            ],
          ],
        ),
      ),
      acaoEsquerda: TextButton.icon(
        onPressed: _restaurarPadrao,
        icon: const Icon(Icons.restart_alt_rounded, size: 17),
        label: const Text('Padrão'),
      ),
      acaoCancelar: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      acaoConfirmar: FilledButton.icon(
        onPressed: _salvar,
        icon: const Icon(Icons.check_rounded, size: 18),
        label: const Text('Salvar'),
      ),
    );
  }
}

class _DialogoTodasFaixasSensores extends StatefulWidget {
  final Map<TipoSensor, FaixaIdealSensor> faixasIniciais;

  const _DialogoTodasFaixasSensores({required this.faixasIniciais});

  @override
  State<_DialogoTodasFaixasSensores> createState() =>
      _DialogoTodasFaixasSensoresState();
}

class _DialogoTodasFaixasSensoresState
    extends State<_DialogoTodasFaixasSensores> {
  late final Map<TipoSensor, TextEditingController> _minCtrls;
  late final Map<TipoSensor, TextEditingController> _maxCtrls;
  final Map<TipoSensor, String?> _erros = {};

  @override
  void initState() {
    super.initState();
    _minCtrls = {
      for (final s in TipoSensor.values)
        s: TextEditingController(
          text: s.formatarValor(
            (widget.faixasIniciais[s] ?? s.faixaPadrao).min,
          ),
        ),
    };
    _maxCtrls = {
      for (final s in TipoSensor.values)
        s: TextEditingController(
          text: s.formatarValor(
            (widget.faixasIniciais[s] ?? s.faixaPadrao).max,
          ),
        ),
    };
  }

  @override
  void dispose() {
    for (final c in _minCtrls.values) {
      c.dispose();
    }
    for (final c in _maxCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _restaurarTodosPadroes() {
    setState(() {
      _erros.clear();
      for (final s in TipoSensor.values) {
        _minCtrls[s]!.text = s.formatarValor(s.idealMin);
        _maxCtrls[s]!.text = s.formatarValor(s.idealMax);
      }
    });
  }

  void _salvar() {
    final resultado = <TipoSensor, FaixaIdealSensor>{};
    bool temErro = false;

    setState(() {
      _erros.clear();
      for (final s in TipoSensor.values) {
        final min = _parseNumeroFlexivel(_minCtrls[s]!.text);
        final max = _parseNumeroFlexivel(_maxCtrls[s]!.text);
        final erro = s.validarFaixa(min, max);
        if (erro != null) {
          _erros[s] = erro;
          temErro = true;
        } else {
          resultado[s] = FaixaIdealSensor(min: min!, max: max!);
        }
      }
    });

    if (temErro) return;
    Navigator.of(context).pop(resultado);
  }

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;

    return DialogoBioglow(
      corDestaque: scheme.primary,
      maxWidth: 440,
      icone: Icon(Icons.tune_rounded, color: scheme.primary, size: 22),
      titulo: 'Definir Faixas Ideais',
      subtitulo: 'Ajuste os limites dos 4 sensores da boia',
      corpo: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final s in TipoSensor.values) ...[
            Builder(
              builder: (context) {
                final cor = cores.corDoSensor(s);
                final erro = _erros[s];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerHighest.withValues(
                      alpha: 0.28,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: erro != null
                          ? scheme.error
                          : cor.withValues(alpha: 0.35),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(iconeDoSensor(s), color: cor, size: 17),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '${s.nome} (${s.unidade})',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Comum: ${s.formatarValor(s.idealMin)}–${s.formatarValor(s.idealMax)} ${s.unidade}',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _CamposMinMaxFaixa(
                        sensor: s,
                        minCtrl: _minCtrls[s]!,
                        maxCtrl: _maxCtrls[s]!,
                        corSensor: cor,
                        textInputActionMax: s == TipoSensor.values.last
                            ? TextInputAction.done
                            : TextInputAction.next,
                        onChanged: () {
                          if (_erros.containsKey(s)) {
                            setState(() => _erros.remove(s));
                          }
                        },
                        onSubmittedMax:
                            s == TipoSensor.values.last ? _salvar : null,
                      ),
                      if (erro != null) ...[
                        const SizedBox(height: 8),
                        _bannerErroFaixa(context, erro),
                      ],
                    ],
                  ),
                );
              },
            ),
          ],
        ],
      ),
      acaoEsquerda: TextButton.icon(
        onPressed: _restaurarTodosPadroes,
        icon: const Icon(Icons.restart_alt_rounded, size: 17),
        label: const Text('Valores comuns'),
      ),
      acaoCancelar: OutlinedButton(
        onPressed: () => Navigator.of(context).pop(),
        child: const Text('Cancelar'),
      ),
      acaoConfirmar: FilledButton(
        onPressed: _salvar,
        child: const Text('Salvar faixas'),
      ),
    );
  }
}
