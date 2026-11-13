import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/configuracoes.dart';
import '../../domain/entities/sensor_info.dart';
import '../cubit/configuracoes_cubit.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogo_bioglow.dart';
import '../widgets/faixa_sensor_dialog.dart';
import 'onboarding_screen.dart';

class ConfiguracoesScreen extends StatelessWidget {
  const ConfiguracoesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<ConfiguracoesCubit>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: Responsivo.of(context).alturaAppBar,
        title: const Row(
          children: [
            IconePng(IconesApp.settings, size: 20),
            SizedBox(width: 8),
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('Configurações', maxLines: 1),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Voltar ao Início',
            icon: const IconePng(IconesApp.home, size: 20),
            onPressed: () =>
                Navigator.of(context).popUntil((route) => route.isFirst),
          ),
        ],
      ),
      body: BlocBuilder<ConfiguracoesCubit, Configuracoes>(
        builder: (context, c) => ListView(
          padding: Responsivo.of(context).paddingLista(topo: 4, base: 24),
          children: [
            // ---------------------------------------------------------
            const _Secao('Conexão com a boia'),
            const _TileStatusConexao(),
            ListTile(
              leading: const Icon(Icons.router_outlined),
              title: const Text('Endereço da boia'),
              subtitle: Text(c.url),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () => _editarEndereco(context, c),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.battery_saver_outlined),
              title: const Text('Manter conexão em segundo plano'),
              subtitle: Text(
                c.manterConexaoEmSegundoPlano
                    ? 'Recebe leituras com o app minimizado (gasta mais bateria)'
                    : 'Desconecta após 30 s fora do app para poupar bateria',
              ),
              value: c.manterConexaoEmSegundoPlano,
              onChanged: cubit.definirManterConexao,
            ),

            // ---------------------------------------------------------
            const _Secao('Ao vivo'),
            _ListTileOpcoes<int>(
              icone: Icons.timeline,
              assetIconePng: IconesApp.sliders,
              titulo: 'Janela do gráfico',
              descricao: 'Quanto tempo de leituras fica visível',
              valor: c.janelaAoVivoMin,
              opcoes: Configuracoes.opcoesJanelaMin,
              rotulo: (v) => '$v min',
              onChanged: cubit.definirJanelaAoVivo,
            ),

            // ---------------------------------------------------------
            const _Secao('Relatório do cartão SD'),
            _ListTileOpcoes<int>(
              icone: Icons.scatter_plot_outlined,
              assetIconePng: IconesApp.chart,
              titulo: 'Pontos no gráfico',
              descricao: 'Mais pontos = mais detalhe, download mais lento',
              valor: c.maxPontosRelatorio,
              opcoes: Configuracoes.opcoesPontosRelatorio,
              rotulo: (v) => '$v',
              onChanged: cubit.definirMaxPontosRelatorio,
            ),
            SwitchListTile(
              secondary: const Icon(Icons.notifications_active_outlined),
              title: const Text('Avisar ao voltar ao app'),
              subtitle: const Text(
                'Mostra quantos dados a boia gravou enquanto você esteve fora',
              ),
              value: c.avisoAusencia,
              onChanged: cubit.definirAvisoAusencia,
            ),
            _ListTileOpcoes<int>(
              icone: Icons.timer_outlined,
              titulo: 'Tempo fora para avisar',
              valor: c.limiteAusenciaMin,
              opcoes: Configuracoes.opcoesAusenciaMin,
              rotulo: (v) => v >= 60 ? '${v ~/ 60} h' : '$v min',
              onChanged: c.avisoAusencia ? cubit.definirLimiteAusencia : null,
            ),

            // ---------------------------------------------------------
            const _Secao('Aparência'),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.brightness_6_outlined,
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                      const SizedBox(width: 16),
                      Text(
                        'Tema',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _SeletorTemaCards(
                    temaAtual: c.tema,
                    onChanged: cubit.definirTema,
                  ),
                ],
              ),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.accessibility_new_rounded),
              title: const Text('Modo Acessibilidade (Fontes Grandes)'),
              subtitle: Text(
                c.modoAcessibilidade
                    ? 'Fontes ampliadas ativas para melhor visualização'
                    : 'Amplia todas as fontes do app para facilitar a leitura',
              ),
              value: c.modoAcessibilidade,
              onChanged: cubit.definirModoAcessibilidade,
            ),
            SwitchListTile(
              secondary: const IconePng(IconesApp.sliders, size: 22),
              title: const Text('Escala automática nos gráficos'),
              subtitle: Text(
                c.escalaAutomatica
                    ? 'Eixo vertical ajustado aos valores medidos'
                    : 'Eixo vertical fixo na escala total de cada sensor',
              ),
              value: c.escalaAutomatica,
              onChanged: cubit.definirEscalaAutomatica,
            ),

            // ---------------------------------------------------------
            const _Secao('Faixas Ideais e Sensores da Boia'),
            ListTile(
              leading: Icon(
                Icons.tune_rounded,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Definir todas as faixas ideais'),
              subtitle: Text(
                c.possuiAlgumaFaixaPersonalizada
                    ? 'Alguns sensores usam valores personalizados pelo usuário'
                    : 'Configurar valor mínimo e máximo ideal dos 4 sensores',
              ),
              trailing: c.possuiAlgumaFaixaPersonalizada
                  ? TextButton(
                      onPressed: () async {
                        await cubit.restaurarTodasFaixasPadrao();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Faixas dos sensores restauradas para os valores comuns.',
                            ),
                          ),
                        );
                      },
                      child: const Text('Usar comuns'),
                    )
                  : const Icon(Icons.edit_outlined),
              onTap: () => mostrarDialogoTodasFaixasSensores(context),
            ),
            for (final s in TipoSensor.values)
              ListTile(
                leading: Icon(
                  iconeDoSensor(s),
                  color: CoresBioglow.of(context).corDoSensor(s),
                ),
                title: Row(
                  children: [
                    Flexible(child: Text(s.nome)),
                    if (c.temFaixaPersonalizada(s)) ...[
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: CoresBioglow.of(
                            context,
                          ).corDoSensor(s).withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Personalizada',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: CoresBioglow.of(context).corDoSensor(s),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                subtitle: Text(
                  '${c.descricaoFaixaDoSensor(s)} • Unidade: ${s.unidade} (toque para editar)',
                ),
                trailing: const Icon(Icons.edit_outlined, size: 19),
                onTap: () => mostrarDialogoFaixaSensor(context, s),
              ),
            ListTile(
              leading: IconePng(
                IconesApp.help,
                size: 22,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Tutorial do aplicativo'),
              subtitle: const Text(
                'Rever apresentação dos sensores, tabelas, gráficos e cartão SD',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (ctx) => OnboardingScreen(
                    modoRevisao: true,
                    onConcluir: () => Navigator.of(ctx).pop(),
                  ),
                ),
              ),
            ),

            // ---------------------------------------------------------
            const _Secao('Sobre'),
            const ListTile(
              leading: IconePng(IconesApp.help, size: 22),
              title: Text('Água Viva - Monitoramento'),
              subtitle: Text('Versão 0.3.0 • Estação Multiparamétrica (ESP32)'),
            ),

            // ---------------------------------------------------------
            const Divider(height: 32),
            ListTile(
              leading: Icon(
                Icons.restore,
                color: Theme.of(context).colorScheme.error,
              ),
              title: Text(
                'Restaurar padrões',
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              onTap: () => _confirmarRestaurar(context),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Future<void> _editarEndereco(BuildContext context, Configuracoes c) async {
    final resultado = await showDialog<(String, int)>(
      context: context,
      builder: (_) => _DialogoEndereco(host: c.host, porta: c.porta),
    );
    if (resultado == null || !context.mounted) return;
    final (host, porta) = resultado;
    context.read<ConfiguracoesCubit>().definirEndereco(host, porta);
  }

  Future<void> _confirmarRestaurar(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return DialogoBioglow(
          corDestaque: scheme.primary,
          icone: Icon(Icons.restore_rounded, color: scheme.primary, size: 22),
          titulo: 'Restaurar padrões?',
          subtitulo: 'Redefinir preferências do aplicativo',
          corpo: Text(
            'Todas as configurações de conexão, aparência e faixas ideais voltarão aos valores originais.',
            style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
          ),
          acaoCancelar: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          acaoConfirmar: FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Restaurar'),
          ),
        );
      },
    );
    if (ok != true || !context.mounted) return;
    await context.read<ConfiguracoesCubit>().restaurarPadroes();
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Configurações restauradas.')));
  }
}

class _SeletorTemaCards extends StatelessWidget {
  final TemaApp temaAtual;
  final ValueChanged<TemaApp> onChanged;

  const _SeletorTemaCards({required this.temaAtual, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const opcoes = [
      (TemaApp.sistema, Icons.brightness_auto_outlined, 'Sistema'),
      (TemaApp.claro, Icons.light_mode_outlined, 'Claro'),
      (TemaApp.escuro, Icons.dark_mode_outlined, 'Escuro'),
    ];

    return Row(
      children: [
        for (var i = 0; i < opcoes.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Builder(
              builder: (context) {
                final (valor, icone, rotulo) = opcoes[i];
                final selecionado = valor == temaAtual;
                return InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => onChanged(valor),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 180),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: selecionado
                          ? scheme.secondaryContainer
                          : scheme.surfaceContainerHighest.withValues(
                              alpha: 0.25,
                            ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: selecionado
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.55),
                        width: selecionado ? 1.5 : 1.0,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icone,
                          size: 20,
                          color: selecionado
                              ? scheme.onSecondaryContainer
                              : scheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 6),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            rotulo,
                            maxLines: 1,
                            softWrap: false,
                            style: TextStyle(
                              fontWeight: selecionado
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: selecionado
                                  ? scheme.onSecondaryContainer
                                  : scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _Secao extends StatelessWidget {
  final String titulo;
  const _Secao(this.titulo);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 4),
      child: Semantics(
        header: true,
        child: Text(
          titulo,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

class _TileStatusConexao extends StatelessWidget {
  const _TileStatusConexao();

  @override
  Widget build(BuildContext context) {
    final service = context.read<Esp32WebSocketService>();
    final cores = CoresBioglow.of(context);

    return StreamBuilder<StatusConexao>(
      stream: service.status,
      initialData: service.statusAtual,
      builder: (context, snapshot) {
        final status = snapshot.data ?? StatusConexao.desconectado;
        final (icone, cor, texto) = switch (status) {
          StatusConexao.conectado => (
            Icons.check_circle_outline,
            cores.ok,
            'Conectado à boia',
          ),
          StatusConexao.conectando => (
            Icons.sync,
            cores.alerta,
            'Conectando à boia...',
          ),
          StatusConexao.desconectado => (
            Icons.error_outline,
            cores.erro,
            'Desconectado da boia',
          ),
        };

        return ListTile(
          leading: Icon(icone, color: cor),
          title: Text(texto, style: TextStyle(color: cor)),
          subtitle: const Text('Toque para testar ou reconectar'),
          trailing: TextButton.icon(
            onPressed: () => service.reconectar(),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Testar'),
          ),
          onTap: () => service.reconectar(),
        );
      },
    );
  }
}

/// ListTile com um menu suspenso de opções à direita.
class _ListTileOpcoes<T> extends StatelessWidget {
  final IconData icone;
  final String? assetIconePng;
  final String titulo;
  final String? descricao;
  final T valor;
  final List<T> opcoes;
  final String Function(T) rotulo;
  final ValueChanged<T>? onChanged;

  const _ListTileOpcoes({
    required this.icone,
    this.assetIconePng,
    required this.titulo,
    this.descricao,
    required this.valor,
    required this.opcoes,
    required this.rotulo,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final habilitado = onChanged != null;
    return ListTile(
      enabled: habilitado,
      leading: assetIconePng != null
          ? IconePng(assetIconePng!, size: 22)
          : Icon(icone),
      title: Text(titulo),
      subtitle: descricao == null ? null : Text(descricao!),
      trailing: DropdownButton<T>(
        value: valor,
        underline: const SizedBox.shrink(),
        onChanged: habilitado ? (v) => v == null ? null : onChanged!(v) : null,
        items: [
          for (final o in opcoes)
            DropdownMenuItem(value: o, child: Text(rotulo(o))),
        ],
      ),
    );
  }
}

class _DialogoEndereco extends StatefulWidget {
  final String host;
  final int porta;
  const _DialogoEndereco({required this.host, required this.porta});

  @override
  State<_DialogoEndereco> createState() => _DialogoEnderecoState();
}

class _DialogoEnderecoState extends State<_DialogoEndereco> {
  final _form = GlobalKey<FormState>();
  late final _host = TextEditingController(text: widget.host);
  late final _porta = TextEditingController(text: '${widget.porta}');

  @override
  void dispose() {
    _host.dispose();
    _porta.dispose();
    super.dispose();
  }

  void _salvar() {
    if (!_form.currentState!.validate()) return;
    Navigator.of(
      context,
    ).pop((_host.text.trim(), int.parse(_porta.text.trim())));
  }

  void _padrao() {
    _host.text = Configuracoes.hostPadrao;
    _porta.text = '${Configuracoes.portaPadrao}';
    _form.currentState?.validate();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DialogoBioglow(
      corDestaque: scheme.primary,
      icone: Icon(Icons.router_outlined, color: scheme.primary, size: 22),
      titulo: 'Endereço da boia',
      subtitulo: 'Conexão WebSocket local (Wi-Fi)',
      corpo: Form(
        key: _form,
        autovalidateMode: AutovalidateMode.onUserInteraction,
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
                  Icon(
                    Icons.wifi_tethering_rounded,
                    size: 16,
                    color: scheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Padrão da boia: ws://${Configuracoes.hostPadrao}:${Configuracoes.portaPadrao}',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _host,
              autofocus: true,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.next,
              scrollPadding: const EdgeInsets.only(bottom: 84),
              decoration: DialogoBioglow.decoracaoCampo(
                context,
                label: 'IP ou nome',
                hint: Configuracoes.hostPadrao,
                prefixText: 'ws://',
              ),
              validator: Configuracoes.validarHost,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _porta,
              keyboardType: TextInputType.number,
              textInputAction: TextInputAction.done,
              scrollPadding: const EdgeInsets.only(bottom: 84),
              decoration: DialogoBioglow.decoracaoCampo(
                context,
                label: 'Porta',
                hint: '${Configuracoes.portaPadrao}',
              ),
              validator: Configuracoes.validarPorta,
              onFieldSubmitted: (_) => _salvar(),
            ),
          ],
        ),
      ),
      acaoEsquerda: TextButton.icon(
        onPressed: _padrao,
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
