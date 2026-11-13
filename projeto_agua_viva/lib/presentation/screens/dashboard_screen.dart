import 'dart:async';
import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/configuracoes.dart';
import '../../domain/entities/leitura_entity.dart';
import '../../domain/entities/sensor_info.dart';
import '../cubit/configuracoes_cubit.dart';
import '../cubit/dashboard_cubit.dart';
import '../cubit/dashboard_state.dart';
import '../theme/app_theme.dart';
import '../widgets/dialogo_bioglow.dart';
import '../widgets/escala_grafico.dart';
import '../widgets/exportador_csv.dart';
import '../widgets/sensor_card.dart';
import 'configuracoes_screen.dart';
import 'onboarding_screen.dart';
import 'relatorio_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  TipoSensor _sensorGrafico = TipoSensor.ph;
  Timer? _timerSnackBarLimpar;

  @override
  void dispose() {
    _timerSnackBarLimpar?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final respAppBar = Responsivo.of(context);
    return Scaffold(
      drawer: _MenuLateralBioglow(
        onLimparHistorico: () => _confirmarLimpar(context),
      ),
      appBar: AppBar(
        toolbarHeight: respAppBar.alturaAppBar,
        titleSpacing: 4,
        leading: Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Menu principal',
            icon: const IconePng(IconesApp.menu, size: 20),
            onPressed: () => Scaffold.of(ctx).openDrawer(),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                respAppBar.isTablet ? 'Água Viva - Monitoramento' : 'Água Viva',
                maxLines: 1,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 19,
                ),
              ),
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                respAppBar.isTablet
                    ? 'Estação Boia • Qualidade da Água'
                    : 'Monitoramento • Qualidade da Água',
                maxLines: 1,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Relatório do cartão SD',
            icon: const IconePng(IconesApp.chart, size: 19),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RelatorioScreen())),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Exportar CSV ao vivo',
            icon: const IconePng(IconesApp.share, size: 18),
            onPressed: () => _exportarCsvAoVivo(context),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Configurações',
            icon: const IconePng(IconesApp.settings, size: 19),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const ConfiguracoesScreen()),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.all(6),
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
            tooltip: 'Limpar histórico',
            icon: const IconePng(IconesApp.trash, size: 18),
            onPressed: () => _confirmarLimpar(context),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: BlocBuilder<DashboardCubit, DashboardState>(
        builder: (context, state) {
          final ultima = state.ultima;
          final scheme = Theme.of(context).colorScheme;
          final resp = Responsivo.of(context);

          return ListView(
            padding: resp.paddingLista(topo: 8, base: 28),
            children: [
              _StatusTelemetriaCard(
                status: state.status,
                ultima: ultima,
                totalAmostras: state.historico.length,
                modoSimulacao: state.modoSimulacao,
              ),
              const SizedBox(height: 12),
              _BannerSimulacaoEDiagnostico(state: state),
              const SizedBox(height: 16),

              // ----------------------------------------------------------
              // 1. Painel dos 4 Sensores Físico-Químicos (pH, Temp, Cond, Turb)
              // ----------------------------------------------------------
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.water_drop_outlined,
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Sensores de Qualidade da Água',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Toque no card para ver o gráfico',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              GradeSensoresQualidadeAgua(
                leitura: ultima,
                sensorSelecionado: _sensorGrafico,
                onSelecionarSensor: (s) => setState(() => _sensorGrafico = s),
              ),
              const SizedBox(height: 20),

              // ----------------------------------------------------------
              // 2. Gráfico Temporal por Sensor
              // ----------------------------------------------------------
              Row(
                children: [
                  IconePng(IconesApp.chart, size: 18, color: scheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Série Temporal ao Vivo',
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SeletorSensorChips(
                selecionado: _sensorGrafico,
                onSelecionado: (s) => setState(() => _sensorGrafico = s),
                sensorPossuiDados: (s) =>
                    state.historico.any((l) => l.sensorAtivo(s)),
              ),
              const SizedBox(height: 10),
              _GraficoAoVivo(
                historico: state.historico,
                sensor: _sensorGrafico,
              ),
              const SizedBox(height: 20),

              // ----------------------------------------------------------
              // 3. Registro de Amostras (Tabela de Campo)
              // ----------------------------------------------------------
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 8,
                runSpacing: 4,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconePng(IconesApp.menu, size: 16, color: scheme.primary),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Amostras Recentes (${state.historico.length})',
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                    ],
                  ),
                  if (state.historico.isNotEmpty)
                    TextButton.icon(
                      onPressed: () => _exportarCsvAoVivo(context),
                      icon: IconePng(
                        IconesApp.share,
                        size: 15,
                        color: scheme.primary,
                      ),
                      label: const Text('Exportar CSV'),
                    ),
                ],
              ),
              const SizedBox(height: 6),
              if (state.historico.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.sensors_outlined,
                          size: 32,
                          color: scheme.outline,
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Aguardando pacote de telemetria da boia...',
                        ),
                      ],
                    ),
                  ),
                )
              else
                ...state.historico.reversed
                    .take(30)
                    .map((l) => _LinhaHistorico(l)),
            ],
          );
        },
      ),
    );
  }

  Future<void> _exportarCsvAoVivo(BuildContext context) async {
    final historico = context.read<DashboardCubit>().state.historico;
    if (historico.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ainda não há leituras para exportar.')),
      );
      return;
    }

    final config = context.read<ConfiguracoesCubit>().state;
    final buffer = StringBuffer()..writeln(LeituraEntity.cabecalhoCsv);
    for (final l in historico) {
      buffer.writeln(l.toCsvLine(config));
    }

    await ExportadorCsv.mostrarOpcoes(
      context,
      nomeArquivo: ExportadorCsv.gerarNomeArquivo('bioglow_ao_vivo'),
      conteudoCsv: buffer.toString(),
      totalLinhas: historico.length,
      tituloRelatorio: 'Exportar Leituras ao Vivo (.CSV)',
    );
  }

  Future<void> _confirmarLimpar(BuildContext context) async {
    final cubit = context.read<DashboardCubit>();
    if (cubit.state.historico.isEmpty) return;
    final messenger = ScaffoldMessenger.of(context);

    final total = cubit.state.historico.length;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return DialogoBioglow(
          corDestaque: scheme.error,
          icone: IconePng(IconesApp.trash, size: 22, color: scheme.error),
          titulo: 'Limpar histórico ao vivo?',
          subtitulo:
              '$total ${total == 1 ? 'leitura exibida' : 'leituras exibidas'} na tela',
          corpo: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'As leituras exibidas neste painel serão removidas da visualização atual.',
                style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: scheme.primary.withValues(alpha: 0.30),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.sd_card_outlined,
                      size: 18,
                      color: scheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Os dados gravados no cartão SD da boia não são afetados.',
                        style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurface,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          acaoCancelar: OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          acaoConfirmar: FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: scheme.error,
              foregroundColor: scheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            icon: const Icon(Icons.delete_sweep_rounded, size: 18),
            label: const Text('Limpar'),
          ),
        );
      },
    );
    if (ok != true) return;

    final removidas = cubit.limpar();
    const duracaoAviso = Duration(seconds: 4);
    messenger.hideCurrentSnackBar();
    _timerSnackBarLimpar?.cancel();
    final controller = messenger.showSnackBar(
      SnackBar(
        duration: duracaoAviso,
        behavior: SnackBarBehavior.floating,
        content: Text('${removidas.length} leituras removidas.'),
        action: SnackBarAction(
          label: 'Desfazer',
          onPressed: () {
            _timerSnackBarLimpar?.cancel();
            cubit.restaurar(removidas);
          },
        ),
      ),
    );
    _timerSnackBarLimpar = Timer(duracaoAviso, () {
      if (!mounted) return;
      try {
        controller.close();
      } catch (_) {}
    });
  }
}

class _StatusTelemetriaCard extends StatelessWidget {
  final StatusConexao status;
  final LeituraEntity? ultima;
  final int totalAmostras;
  final bool modoSimulacao;

  const _StatusTelemetriaCard({
    required this.status,
    required this.ultima,
    required this.totalAmostras,
    required this.modoSimulacao,
  });

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;

    final (cor, icone, texto) = modoSimulacao
        ? (scheme.tertiary, Icons.science_rounded, 'Simulador Água Viva Ativo')
        : switch (status) {
            StatusConexao.conectado => (
              cores.ok,
              Icons.wifi_tethering_rounded,
              'Conectado à Boia Água Viva',
            ),
            StatusConexao.conectando => (
              cores.alerta,
              Icons.wifi_find_rounded,
              'Buscando sinal da boia...',
            ),
            StatusConexao.desconectado => (
              cores.erro,
              Icons.wifi_off_rounded,
              'Sem conexão com a boia',
            ),
          };

    final sensoresAtivos = ultima?.sensoresAtivosCount ?? 0;
    final resp = Responsivo.of(context);
    final botaoAcao = (status != StatusConexao.conectado && !modoSimulacao)
        ? FilledButton.tonalIcon(
            onPressed: () => context.read<DashboardCubit>().reconectar(),
            icon: const Icon(Icons.refresh, size: 16),
            label: const Text('Conectar'),
          )
        : OutlinedButton.icon(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const RelatorioScreen())),
            icon: const Icon(Icons.sd_card_outlined, size: 16),
            label: const Text('Dados SD'),
          );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: cor.withValues(alpha: 0.35)),
                      ),
                      child: Image.asset(
                        kAssetBoiaBioglow,
                        fit: BoxFit.contain,
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
                    Positioned(
                      right: -2,
                      bottom: -2,
                      child: Container(
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: scheme.surface,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(icone, color: cor, size: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        texto,
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        modoSimulacao
                            ? 'Gerando leituras de teste a cada 2 s para os 4 sensores'
                            : status == StatusConexao.conectado
                            ? context.select<ConfiguracoesCubit, String>(
                                (c) =>
                                    '${c.state.url} • Gravando no SD a cada 2 s',
                              )
                            : 'Conecte-se à rede Wi-Fi "Bioglow_Boia"',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (resp.isTablet) ...[const SizedBox(width: 8), botaoAcao],
              ],
            ),
            if (!resp.isTablet) ...[
              const SizedBox(height: 10),
              Align(alignment: Alignment.centerRight, child: botaoAcao),
            ],
            if (ultima != null) ...[
              const Divider(height: 20),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  _MiniInfoChip(
                    icone: Icons.schedule_rounded,
                    texto: '${ultima!.data} ${ultima!.hora}',
                  ),
                  _MiniInfoChip(
                    icone: Icons.sensors_rounded,
                    texto: '$sensoresAtivos/4 sensores ativos',
                  ),
                  _MiniInfoChip(
                    icone: Icons.analytics_outlined,
                    assetIconePng: IconesApp.chart,
                    texto: '$totalAmostras leituras',
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Banner inteligente de campo:
/// - Quando os sensores físicos ainda não estão conectados, oferece ativar o
///   Modo Simulação Científica com 1 toque para testar gráficos, alertas e CSV.
/// - Quando há leituras ativas (reais ou simuladas), mostra o diagnóstico
///   ambiental combinado e permite simular anomalias.
class _BannerSimulacaoEDiagnostico extends StatelessWidget {
  final DashboardState state;

  const _BannerSimulacaoEDiagnostico({required this.state});

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<DashboardCubit>();
    final config = context.watch<ConfiguracoesCubit>().state;
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final ultima = state.ultima;
    final sensoresAtivos = ultima?.sensoresAtivosCount ?? 0;

    if (!state.modoSimulacao && sensoresAtivos == 0) {
      final resp = Responsivo.of(context);
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.35)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.science_outlined, color: scheme.primary, size: 22),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Testar app sem os sensores físicos?',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 14.5,
                        ),
                      ),
                      Text(
                        'Simule leituras de pH, Temperatura, Condutividade e Turbidez em tempo real.',
                        style: TextStyle(
                          fontSize: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (resp.isTablet) ...[
                  const SizedBox(width: 8),
                  FilledButton.tonal(
                    onPressed: () => cubit.definirModoSimulacao(true),
                    child: const Text('Simular'),
                  ),
                ],
              ],
            ),
            if (!resp.isTablet) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                  onPressed: () => cubit.definirModoSimulacao(true),
                  child: const Text('Simular'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    // Avalia se algum sensor está em atenção na última leitura
    final sensoresEmAlerta = <String>[];
    if (ultima != null) {
      for (final s in TipoSensor.values) {
        final st = s.avaliar(
          ultima.valorDoSensor(s),
          faixa: config.faixaDoSensor(s),
        );
        if (st == StatusQualidadeSensor.atencao ||
            st == StatusQualidadeSensor.alerta) {
          sensoresEmAlerta.add(s.nomeCurto);
        }
      }
    }

    final emAlerta = sensoresEmAlerta.isNotEmpty;
    final corDiag = emAlerta ? cores.alerta : cores.ok;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: corDiag.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: corDiag.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                emAlerta
                    ? Icons.warning_amber_rounded
                    : Icons.verified_outlined,
                color: corDiag,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  emAlerta
                      ? 'Atenção ambiental: ${sensoresEmAlerta.join(", ")} fora da faixa ideal'
                      : 'Parâmetros da água dentro da faixa ideal',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: corDiag,
                  ),
                ),
              ),
            ],
          ),
          if (state.modoSimulacao) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                ActionChip(
                  avatar: Icon(
                    state.simulandoAnomalia
                        ? Icons.check_circle_outline
                        : Icons.warning_amber_rounded,
                    size: 16,
                    color: state.simulandoAnomalia ? cores.ok : cores.alerta,
                  ),
                  label: Text(
                    state.simulandoAnomalia
                        ? 'Restaurar água normal'
                        : 'Simular anomalia ambiental',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  onPressed: cubit.alternarAnomaliaSimulada,
                ),
                ActionChip(
                  avatar: const Icon(Icons.stop_circle_outlined, size: 16),
                  label: const Text(
                    'Sair da simulação',
                    style: TextStyle(fontSize: 12.5),
                  ),
                  onPressed: () => cubit.definirModoSimulacao(false),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _MiniInfoChip extends StatelessWidget {
  final IconData icone;
  final String? assetIconePng;
  final String texto;

  const _MiniInfoChip({
    required this.icone,
    this.assetIconePng,
    required this.texto,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (assetIconePng != null)
          IconePng(assetIconePng!, size: 13, color: scheme.onSurfaceVariant)
        else
          Icon(icone, size: 14, color: scheme.onSurfaceVariant),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            texto,
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurfaceVariant,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ],
    );
  }
}

class _GraficoAoVivo extends StatefulWidget {
  final List<LeituraEntity> historico;
  final TipoSensor sensor;

  const _GraficoAoVivo({required this.historico, required this.sensor});

  @override
  State<_GraficoAoVivo> createState() => _GraficoAoVivoState();
}

class _GraficoAoVivoState extends State<_GraficoAoVivo> {
  static final double _lacunaSeg =
      Configuracoes.intervaloLeitura.inMilliseconds * 3 / 1000;

  bool? _autoEscalaManual;
  List<LeituraEntity>? _historicoCongelado;

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final config = context.watch<ConfiguracoesCubit>().state;
    final janelaSeg = config.janelaAoVivo.inSeconds.toDouble();
    final autoEscala = _autoEscalaManual ?? config.escalaAutomatica;
    final sensor = widget.sensor;

    final pausado = _historicoCongelado != null;
    final historico = _historicoCongelado ?? widget.historico;
    final seriePrincipal = <FlSpot>[];
    final visiveis = <double>[];

    if (historico.isNotEmpty) {
      final ref = historico.last.recebidoEm;
      double? xAnterior;

      for (final l in historico) {
        final x = l.recebidoEm.difference(ref).inMilliseconds / 1000.0;
        final valor = l.valorDoSensor(sensor);
        if (valor == null) continue;

        if (xAnterior != null && x - xAnterior > _lacunaSeg) {
          seriePrincipal.add(FlSpot.nullSpot);
        }

        seriePrincipal.add(FlSpot(x, valor));
        if (x >= -janelaSeg) visiveis.add(valor);
        xAnterior = x;
      }
    }

    final escala = EscalaY.calcular(visiveis, auto: autoEscala, sensor: sensor);
    final corPrincipal = cores.corDoSensor(sensor);

    final minV = visiveis.isEmpty ? null : visiveis.reduce(math.min);
    final maxV = visiveis.isEmpty ? null : visiveis.reduce(math.max);
    final medV = visiveis.isEmpty
        ? null
        : visiveis.reduce((a, b) => a + b) / visiveis.length;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 12),
        child: Column(
          children: [
            Row(
              children: [
                const SizedBox(width: 8),
                Icon(iconeDoSensor(sensor), size: 16, color: corPrincipal),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${sensor.nome} (${sensor.unidade})',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (seriePrincipal.isNotEmpty)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: pausado
                        ? 'Retomar gráfico ao vivo'
                        : 'Congelar gráfico para inspeção',
                    icon: Icon(
                      pausado ? Icons.play_arrow_rounded : Icons.pause_rounded,
                      size: 20,
                      color: pausado ? cores.alerta : scheme.onSurfaceVariant,
                    ),
                    onPressed: () => setState(() {
                      _historicoCongelado = pausado
                          ? null
                          : List.of(widget.historico);
                    }),
                  ),
                BotaoEscala(
                  auto: autoEscala,
                  sensor: sensor,
                  onChanged: (v) => setState(() => _autoEscalaManual = v),
                ),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: Responsivo.of(context).alturaGraficoAoVivo,
              child: seriePrincipal.isEmpty
                  ? _EstadoSensorAguardandoGrafico(sensor: sensor)
                  : Padding(
                      padding: const EdgeInsets.only(right: 8, top: 4),
                      child: LineChart(
                        LineChartData(
                          minY: 0,
                          maxY: escala.max,
                          minX: -janelaSeg,
                          maxX: 0,
                          clipData: const FlClipData.all(),
                          gridData: FlGridData(
                            drawVerticalLine: false,
                            horizontalInterval: escala.intervalo,
                          ),
                          borderData: FlBorderData(show: false),
                          extraLinesData: _faixaIdealHorizontal(
                            config.faixaDoSensor(sensor),
                            scheme,
                          ),
                          lineTouchData: LineTouchData(
                            touchTooltipData: LineTouchTooltipData(
                              fitInsideHorizontally: true,
                              fitInsideVertically: true,
                              getTooltipItems: (spots) => spots.map((s) {
                                final segAtras = (-s.x).round();
                                final tempoStr = segAtras <= 1
                                    ? 'agora'
                                    : 'há ${segAtras}s';
                                return LineTooltipItem(
                                  '${sensor.formatarValor(s.y, incluirUnidade: true)}\n$tempoStr',
                                  TextStyle(
                                    color: corPrincipal,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 13,
                                  ),
                                );
                              }).toList(),
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(),
                            rightTitles: const AxisTitles(),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: Responsivo.of(
                                  context,
                                ).alturaEixoX(),
                                interval: 60,
                                getTitlesWidget: (v, meta) => Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    v == 0 ? 'agora' : '${v ~/ 60} min',
                                    style: const TextStyle(fontSize: 11.5),
                                  ),
                                ),
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: Responsivo.of(
                                  context,
                                ).larguraEixoY,
                                interval: escala.intervalo,
                                getTitlesWidget: rotuloEixoY,
                              ),
                            ),
                          ),
                          lineBarsData: [_linha(seriePrincipal, corPrincipal)],
                        ),
                        duration: Duration.zero,
                      ),
                    ),
            ),
            if (visiveis.isNotEmpty) ...[
              const Divider(height: 18),
              Builder(
                builder: (context) {
                  final resp = Responsivo.of(context);
                  final minimoCard = _EstatisticaRapida(
                    rotulo: 'Mínimo',
                    valor: '${sensor.formatarValor(minV)} ${sensor.unidade}',
                    cor: scheme.onSurfaceVariant,
                  );
                  final mediaCard = _EstatisticaRapida(
                    rotulo: 'Média na janela',
                    valor: '${sensor.formatarValor(medV)} ${sensor.unidade}',
                    cor: corPrincipal,
                    destaque: true,
                  );
                  final maximoCard = _EstatisticaRapida(
                    rotulo: 'Máximo',
                    valor: '${sensor.formatarValor(maxV)} ${sensor.unidade}',
                    cor: scheme.onSurfaceVariant,
                  );

                  if (resp.isTablet) {
                    return Row(
                      children: [
                        Expanded(child: minimoCard),
                        const SizedBox(width: 8),
                        Expanded(child: mediaCard),
                        const SizedBox(width: 8),
                        Expanded(child: maximoCard),
                      ],
                    );
                  }

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Expanded(child: minimoCard),
                          const SizedBox(width: 8),
                          Expanded(child: maximoCard),
                        ],
                      ),
                      const SizedBox(height: 8),
                      mediaCard,
                    ],
                  );
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  ExtraLinesData _faixaIdealHorizontal(
    FaixaIdealSensor faixa,
    ColorScheme scheme,
  ) {
    return ExtraLinesData(
      horizontalLines: [
        HorizontalLine(
          y: faixa.min,
          color: scheme.outline.withValues(alpha: 0.45),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
        HorizontalLine(
          y: faixa.max,
          color: scheme.outline.withValues(alpha: 0.45),
          strokeWidth: 1,
          dashArray: [4, 4],
        ),
      ],
    );
  }

  LineChartBarData _linha(List<FlSpot> spots, Color cor) {
    return LineChartBarData(
      spots: spots,
      color: cor,
      barWidth: 2.2,
      isCurved: false,
      dotData: const FlDotData(show: false),
      belowBarData: BarAreaData(show: true, color: cor.withValues(alpha: 0.10)),
    );
  }
}

class _EstadoSensorAguardandoGrafico extends StatelessWidget {
  final TipoSensor sensor;

  const _EstadoSensorAguardandoGrafico({required this.sensor});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cores = CoresBioglow.of(context);
    final cor = cores.corDoSensor(sensor);
    final descricaoFaixa = context.select<ConfiguracoesCubit, String>(
      (c) => c.state.descricaoFaixaDoSensor(sensor),
    );

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(iconeDoSensor(sensor), size: 32, color: cor),
            const SizedBox(height: 8),
            Text(
              'Aguardando leituras de ${sensor.nome}',
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Text(
              '$descricaoFaixa • Unidade: ${sensor.unidade}\n'
              'Assim que o sensor enviar dados pelo ESP32, '
              'a curva em tempo real aparecerá automaticamente aqui.',
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EstatisticaRapida extends StatelessWidget {
  final String rotulo;
  final String valor;
  final Color cor;
  final bool destaque;

  const _EstatisticaRapida({
    required this.rotulo,
    required this.valor,
    required this.cor,
    this.destaque = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: destaque
            ? cor.withValues(alpha: 0.10)
            : scheme.surfaceContainerHighest.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: destaque
              ? cor.withValues(alpha: 0.32)
              : scheme.outlineVariant.withValues(alpha: 0.25),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              rotulo,
              maxLines: 1,
              style: TextStyle(
                fontSize: 12,
                color: destaque ? cor : scheme.onSurfaceVariant,
                fontWeight: destaque ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              valor,
              maxLines: 1,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: cor,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinhaHistorico extends StatelessWidget {
  final LeituraEntity l;
  const _LinhaHistorico(this.l);

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final temAlgumSensor =
        l.ph != null ||
        l.temperatura != null ||
        l.condutividade != null ||
        l.turbidez != null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.schedule_rounded,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${l.data}  •  ${l.hora}',
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurfaceVariant,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (!temAlgumSensor)
                Text(
                  'Pinos dos sensores pendentes',
                  style: TextStyle(fontSize: 12.5, color: scheme.outline),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (l.ph != null)
                      _TagValor(
                        rotulo: 'pH ${l.ph!.toStringAsFixed(2)}',
                        cor: cores.ph,
                      ),
                    if (l.temperatura != null)
                      _TagValor(
                        rotulo: '${l.temperatura!.toStringAsFixed(1)} °C',
                        cor: cores.temperatura,
                      ),
                    if (l.condutividade != null)
                      _TagValor(
                        rotulo: '${l.condutividade!.toStringAsFixed(0)} µS/cm',
                        cor: cores.condutividade,
                      ),
                    if (l.turbidez != null)
                      _TagValor(
                        rotulo: '${l.turbidez!.toStringAsFixed(1)} NTU',
                        cor: cores.turbidez,
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TagValor extends StatelessWidget {
  final String rotulo;
  final Color cor;

  const _TagValor({required this.rotulo, required this.cor});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: cor.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        rotulo,
        style: TextStyle(
          fontSize: 12.5,
          fontWeight: FontWeight.w600,
          color: cor,
          fontFeatures: const [FontFeature.tabularFigures()],
        ),
      ),
    );
  }
}

class _MenuLateralBioglow extends StatelessWidget {
  final VoidCallback onLimparHistorico;

  const _MenuLateralBioglow({required this.onLimparHistorico});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final resp = Responsivo.of(context);

    return Drawer(
      width: resp.larguraDrawer,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Color(0xFF7635BD), Color(0xFF44167A)],
                      ),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFB388FF).withValues(alpha: 0.45),
                      ),
                    ),
                    child: Image.asset(
                      kAssetBoiaBioglow,
                      fit: BoxFit.contain,
                      filterQuality: FilterQuality.medium,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Água Viva - Monitoramento',
                          style: Theme.of(context).textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Estação Boia Multiparamétrica',
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 16),
            ListTile(
              selected: true,
              leading: IconePng(
                IconesApp.home,
                size: 20,
                color: scheme.primary,
              ),
              title: const Text('Início • Painel ao Vivo'),
              onTap: () => Navigator.of(context).pop(),
            ),
            ListTile(
              leading: const IconePng(IconesApp.chart, size: 20),
              title: const Text('Relatório do Cartão SD'),
              subtitle: const Text('Histórico gravado na boia'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const RelatorioScreen()),
                );
              },
            ),
            ListTile(
              leading: const IconePng(IconesApp.settings, size: 20),
              title: const Text('Configurações'),
              subtitle: const Text('Rede Wi-Fi, IP da boia e aparência'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => const ConfiguracoesScreen(),
                  ),
                );
              },
            ),
            ListTile(
              leading: const IconePng(IconesApp.help, size: 20),
              title: const Text('Tutorial do Aplicativo'),
              subtitle: const Text('Guia dos 4 sensores e operação'),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (ctx) => OnboardingScreen(
                      modoRevisao: true,
                      onConcluir: () => Navigator.of(ctx).pop(),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 16),
            BlocBuilder<DashboardCubit, DashboardState>(
              builder: (context, state) => SwitchListTile(
                secondary: Icon(
                  Icons.science_outlined,
                  color: state.modoSimulacao ? scheme.primary : null,
                ),
                title: const Text('Modo Simulação (Demo)'),
                subtitle: const Text('Gerar dados de teste dos 4 sensores'),
                value: state.modoSimulacao,
                onChanged: (v) {
                  context.read<DashboardCubit>().definirModoSimulacao(v);
                },
              ),
            ),
            const Spacer(),
            const Divider(height: 16),
            ListTile(
              leading: IconePng(IconesApp.trash, size: 20, color: scheme.error),
              title: Text(
                'Limpar leituras ao vivo',
                style: TextStyle(color: scheme.error),
              ),
              onTap: () {
                Navigator.of(context).pop();
                onLimparHistorico();
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }
}
