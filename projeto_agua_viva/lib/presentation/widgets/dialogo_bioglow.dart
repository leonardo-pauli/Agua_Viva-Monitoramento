import 'package:flutter/material.dart';

/// Estrutura visual padronizada e responsiva para diálogos do aplicativo
/// (edição com teclado aberto, configurações e confirmações destrutivas).
class DialogoBioglow extends StatelessWidget {
  final Widget icone;
  final String titulo;
  final String? subtitulo;
  final Color? corDestaque;
  final double maxWidth;
  final Widget corpo;
  final Widget? acaoEsquerda;
  final Widget acaoCancelar;
  final Widget acaoConfirmar;

  const DialogoBioglow({
    super.key,
    required this.icone,
    required this.titulo,
    this.subtitulo,
    this.corDestaque,
    this.maxWidth = 410,
    required this.corpo,
    this.acaoEsquerda,
    required this.acaoCancelar,
    required this.acaoConfirmar,
  });

  /// Decoração padrão e moderna para campos de entrada de texto nos diálogos.
  static InputDecoration decoracaoCampo(
    BuildContext context, {
    required String label,
    String? hint,
    String? prefixText,
    String? suffixText,
    Color? corFoco,
    EdgeInsetsGeometry? contentPadding,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final corAtiva = corFoco ?? scheme.primary;
    final bordaBase = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(
        color: scheme.outlineVariant.withValues(alpha: 0.7),
      ),
    );

    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.34),
      contentPadding: contentPadding ??
          const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      suffixText: suffixText,
      suffixStyle: TextStyle(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: scheme.onSurfaceVariant,
      ),
      border: bordaBase,
      enabledBorder: bordaBase,
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: corAtiva, width: 1.8),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.error, width: 1.8),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final destaque = corDestaque ?? scheme.primary;

    return Dialog(
      backgroundColor: scheme.surfaceContainerHigh,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: BorderSide(
          color: destaque.withValues(alpha: 0.25),
          width: 1,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 14),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: destaque.withValues(alpha: 0.14),
                            borderRadius: BorderRadius.circular(13),
                            border: Border.all(
                              color: destaque.withValues(alpha: 0.35),
                            ),
                          ),
                          alignment: Alignment.center,
                          child: icone,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                titulo,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w800,
                                      height: 1.2,
                                    ),
                              ),
                              if (subtitulo != null) ...[
                                const SizedBox(height: 3),
                                Text(
                                  subtitulo!,
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: scheme.onSurfaceVariant,
                                      ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    corpo,
                  ],
                ),
              ),
            ),
            Divider(
              height: 1,
              color: scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: acaoEsquerda != null
                  ? Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        acaoEsquerda!,
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            acaoCancelar,
                            const SizedBox(width: 8),
                            acaoConfirmar,
                          ],
                        ),
                      ],
                    )
                  : Row(
                      children: [
                        Expanded(child: acaoCancelar),
                        const SizedBox(width: 10),
                        Expanded(child: acaoConfirmar),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
