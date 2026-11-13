import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';

/// Centraliza a criação, compartilhamento (WhatsApp, Drive, E-mail) e
/// salvamento de arquivos `.csv` reais das leituras da boia HidroBô.
abstract final class ExportadorCsv {
  static const MethodChannel _canal = MethodChannel('bioglow/arquivos');

  static String _dois(int n) => n.toString().padLeft(2, '0');

  /// Gera um nome de arquivo padronizado com data e hora atuais.
  /// Ex.: `hidrobo_ao_vivo_2026-11-10_12-45.csv`
  static String gerarNomeArquivo(String prefixo, [DateTime? momento]) {
    final d = momento ?? DateTime.now();
    return '${prefixo}_${d.year}-${_dois(d.month)}-${_dois(d.day)}_'
        '${_dois(d.hour)}-${_dois(d.minute)}.csv';
  }

  /// Abre um painel inferior (Bottom Sheet) permitindo ao pesquisador escolher
  /// entre compartilhar o arquivo `.csv`, salvar no aparelho ou copiar o texto.
  static Future<void> mostrarOpcoes(
    BuildContext context, {
    required String nomeArquivo,
    required String conteudoCsv,
    required int totalLinhas,
    required String tituloRelatorio,
  }) async {
    final scheme = Theme.of(context).colorScheme;
    final resp = Responsivo.of(context);

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      constraints: BoxConstraints(
        maxWidth: resp.isTablet ? 560 : double.infinity,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            resp.espaco(20),
            4,
            resp.espaco(20),
            resp.espaco(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(resp.espaco(10)),
                    decoration: BoxDecoration(
                      color: scheme.primary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      Icons.description_outlined,
                      color: scheme.primary,
                      size: resp.icone(24),
                    ),
                  ),
                  SizedBox(width: resp.espaco(12)),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tituloRelatorio,
                          style:
                              Theme.of(ctx).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '$nomeArquivo • $totalLinhas amostras',
                          style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 8),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: scheme.primary.withValues(alpha: 0.15),
                  foregroundColor: scheme.primary,
                  child: IconePng(
                    IconesApp.share,
                    size: resp.icone(19),
                    color: scheme.primary,
                  ),
                ),
                title: Text(
                  resp.isDesktop
                      ? 'Salvar em Downloads e mostrar na pasta'
                      : 'Compartilhar arquivo .CSV',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  resp.isDesktop
                      ? 'Grava a planilha em Downloads e destaca o arquivo no Explorer'
                      : 'Enviar arquivo para WhatsApp, E-mail, Google Drive, Telegram...',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  compartilharArquivo(
                    context,
                    nomeArquivo: nomeArquivo,
                    conteudoCsv: conteudoCsv,
                    titulo: tituloRelatorio,
                  );
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: scheme.secondaryContainer,
                  foregroundColor: scheme.onSecondaryContainer,
                  child: Icon(
                    Icons.save_alt_rounded,
                    size: resp.icone(20),
                  ),
                ),
                title: Text(
                  resp.isDesktop
                      ? 'Salvar arquivo .CSV como...'
                      : 'Salvar arquivo .CSV no aparelho',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  resp.isDesktop
                      ? 'Escolher pasta do computador para gravar a planilha'
                      : 'Escolher pasta (Downloads / Documentos) para gravar a planilha',
                ),
                onTap: () {
                  Navigator.of(ctx).pop();
                  salvarArquivoNoAparelho(
                    context,
                    nomeArquivo: nomeArquivo,
                    conteudoCsv: conteudoCsv,
                  );
                },
              ),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: CircleAvatar(
                  backgroundColor: scheme.surfaceContainerHighest,
                  foregroundColor: scheme.onSurfaceVariant,
                  child: Icon(
                    Icons.copy_rounded,
                    size: resp.icone(19),
                  ),
                ),
                title: const Text(
                  'Copiar texto CSV',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Copiar conteúdo para a área de transferência',
                ),
                onTap: () async {
                  Navigator.of(ctx).pop();
                  final messenger = ScaffoldMessenger.of(context);
                  await Clipboard.setData(ClipboardData(text: conteudoCsv));
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        'Texto CSV ($totalLinhas amostras) copiado para a área de transferência!',
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Aciona o compartilhamento nativo do arquivo `.csv`.
  static Future<void> compartilharArquivo(
    BuildContext context, {
    required String nomeArquivo,
    required String conteudoCsv,
    required String titulo,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await _canal.invokeMethod<bool>('compartilharCsv', {
          'nome': nomeArquivo,
          'conteudo': conteudoCsv,
          'titulo': titulo,
        });
        return;
      } on MissingPluginException {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Reinicie o app (Stop ⏹️ e Run ▶️) para ativar o compartilhamento nativo.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      } catch (e) {
        debugPrint('Falha ao compartilhar arquivo CSV via canal nativo: $e');
      }
    }

    // No Windows / Desktop: grava e abre o Explorer selecionando o arquivo
    final caminho = await _gravarArquivoLocalDesktop(nomeArquivo, conteudoCsv);
    if (caminho != null) {
      if (!kIsWeb && Platform.isWindows) {
        try {
          await Process.run('explorer.exe', ['/select,$caminho']);
        } catch (_) {}
      }
      messenger.showSnackBar(
        SnackBar(
          content: Text('Arquivo CSV gerado em: $caminho'),
          duration: const Duration(seconds: 5),
        ),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: conteudoCsv));
    messenger.showSnackBar(
      const SnackBar(
        content: Text('CSV copiado para a área de transferência.'),
      ),
    );
  }

  /// Abre o seletor nativo "Salvar como..." no Android/iOS ou no Windows.
  static Future<void> salvarArquivoNoAparelho(
    BuildContext context, {
    required String nomeArquivo,
    required String conteudoCsv,
  }) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        final salvo = await _canal.invokeMethod<bool>('salvarCsv', {
          'nome': nomeArquivo,
          'conteudo': conteudoCsv,
        });
        if (salvo == true) {
          messenger.showSnackBar(
            SnackBar(
              content: Text('Arquivo "$nomeArquivo" salvo com sucesso!'),
            ),
          );
        }
        return;
      } on MissingPluginException {
        messenger.showSnackBar(
          const SnackBar(
            content: Text(
              'Reinicie o app (Stop ⏹️ e Run ▶️) para ativar o seletor de pastas nativo.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        return;
      } catch (e) {
        debugPrint('Falha ao salvar CSV no aparelho: $e');
      }
    }

    // No Windows: abre a janela nativa "Salvar como..." do Windows
    if (!kIsWeb && Platform.isWindows) {
      try {
        final script = '''
Add-Type -AssemblyName System.Windows.Forms
\$dlg = New-Object System.Windows.Forms.SaveFileDialog
\$dlg.Filter = "Arquivo CSV (*.csv)|*.csv"
\$dlg.Title = "Salvar planilha CSV - Água Viva - Monitoramento"
\$dlg.FileName = "$nomeArquivo"
if (\$dlg.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
  Write-Output \$dlg.FileName
}
''';
        final res = await Process.run('powershell', [
          '-NoProfile',
          '-STA',
          '-Command',
          script,
        ]);
        final escolhido = res.stdout.toString().trim();
        if (escolhido.isNotEmpty) {
          final comBom = conteudoCsv.startsWith('\uFEFF')
              ? conteudoCsv
              : '\uFEFF$conteudoCsv';
          await File(escolhido).writeAsString(comBom, flush: true);
          messenger.showSnackBar(
            SnackBar(
              content: Text('Arquivo CSV salvo em: $escolhido'),
              duration: const Duration(seconds: 5),
            ),
          );
        }
        return;
      } catch (e) {
        debugPrint('Erro ao abrir diálogo do Windows: $e');
      }
    }

    final caminho = await _gravarArquivoLocalDesktop(nomeArquivo, conteudoCsv);
    if (caminho != null) {
      messenger.showSnackBar(
        SnackBar(
          content: Text('Arquivo CSV salvo em: $caminho'),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  static Future<String?> _gravarArquivoLocalDesktop(
    String nomeArquivo,
    String conteudoCsv,
  ) async {
    if (kIsWeb) return null;
    try {
      final home = Platform.environment['USERPROFILE'] ??
          Platform.environment['HOME'];
      Directory dir = Directory.systemTemp;
      if (home != null) {
        final downloads = Directory('$home${Platform.pathSeparator}Downloads');
        if (await downloads.exists()) {
          dir = downloads;
        }
      }
      final arquivo = File('${dir.path}${Platform.pathSeparator}$nomeArquivo');
      final comBom =
          conteudoCsv.startsWith('\uFEFF') ? conteudoCsv : '\uFEFF$conteudoCsv';
      await arquivo.writeAsString(comBom, flush: true);
      return arquivo.path;
    } catch (e) {
      debugPrint('Erro ao gravar arquivo local: $e');
      return null;
    }
  }
}
