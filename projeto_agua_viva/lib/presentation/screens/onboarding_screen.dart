import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../domain/entities/sensor_info.dart';
import '../theme/app_theme.dart';
import '../widgets/faixa_sensor_dialog.dart';

/// Tela inicial de boas-vindas e tutorial interativo do aplicativo Bioglow.
///
/// Apresenta em ordem progressiva (com scroll horizontal e indicadores em
/// bolinhas) a proposta da boia, os 4 sensores físico-químicos (pH,
/// Temperatura, Condutividade e Turbidez), as tabelas/gráficos em tempo real
/// e o armazenamento autônomo no cartão MicroSD.
class OnboardingScreen extends StatefulWidget {
  /// Chamado quando o usuário conclui ou pula o tutorial.
  final VoidCallback onConcluir;

  /// Se verdadeiro, foi aberto a partir da tela de Configurações.
  final bool modoRevisao;

  const OnboardingScreen({
    super.key,
    required this.onConcluir,
    this.modoRevisao = false,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _controller = PageController();
  int _paginaAtual = 0;

  static const int _totalPaginas = 4;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finalizarTutorial() async {
    if (!widget.modoRevisao) {
      await mostrarEscolhaInicialFaixas(context);
    }
    if (!mounted) return;
    widget.onConcluir();
  }

  void _proximaPagina() {
    if (_paginaAtual < _totalPaginas - 1) {
      _controller.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeOutCubic,
      );
    } else {
      _finalizarTutorial();
    }
  }

  void _paginaAnterior() {
    if (_paginaAtual > 0) {
      _controller.previousPage(
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutCubic,
      );
    }
  }

  Color _corDaPagina(CoresBioglow cores, int index) => switch (index) {
        0 => const Color(0xFF00BCD4),
        1 => cores.ph,
        2 => cores.condutividade,
        _ => cores.turbidez,
      };

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;
    final corAtiva = _corDaPagina(cores, _paginaAtual);
    final naUltimaPagina = _paginaAtual == _totalPaginas - 1;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              corAtiva.withValues(alpha: 0.10),
              scheme.surface,
              scheme.surface,
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 740),
              child: Column(
                children: [
              // ----------------------------------------------------------
              // Barra superior (Selo + Botão Pular / Fechar)
              // ----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 16, 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 5,
                        ),
                        decoration: BoxDecoration(
                          color: corAtiva.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: corAtiva.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.water_drop_rounded,
                              size: 14,
                              color: corAtiva,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'ÁGUA VIVA • MONITORAMENTO',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.6,
                                    color: corAtiva,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (widget.modoRevisao || !naUltimaPagina) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: _finalizarTutorial,
                        child: Text(widget.modoRevisao ? 'Fechar' : 'Pular'),
                      ),
                    ],
                  ],
                ),
              ),

              // ----------------------------------------------------------
              // Carrossel de páginas (Scroll para a direita)
              // ----------------------------------------------------------
              Expanded(
                child: PageView(
                  controller: _controller,
                  physics: const BouncingScrollPhysics(),
                  onPageChanged: (index) =>
                      setState(() => _paginaAtual = index),
                  children: const [
                    _Slide1BoiaConexao(),
                    _Slide2QuatroSensores(),
                    _Slide3GraficosTabelas(),
                    _Slide4ArmazenamentoSd(),
                  ],
                ),
              ),

              // ----------------------------------------------------------
              // Rodapé: Bolinhas indicadoras + Botões de avanço
              // ----------------------------------------------------------
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                child: Column(
                  children: [
                    // Bolinhas sinalizadoras de página
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_totalPaginas, (index) {
                        final selecionado = index == _paginaAtual;
                        return GestureDetector(
                          onTap: () => _controller.animateToPage(
                            index,
                            duration: const Duration(milliseconds: 350),
                            curve: Curves.easeOutCubic,
                          ),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 280),
                            curve: Curves.easeOut,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            height: 9,
                            width: selecionado ? 28 : 9,
                            decoration: BoxDecoration(
                              color: selecionado
                                  ? corAtiva
                                  : scheme.outlineVariant,
                              borderRadius: BorderRadius.circular(10),
                              boxShadow: selecionado
                                  ? [
                                      BoxShadow(
                                        color: corAtiva.withValues(alpha: 0.4),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: 18),
                    if (Responsivo.of(context).isTablet)
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          if (_paginaAtual > 0)
                            OutlinedButton.icon(
                              onPressed: _paginaAnterior,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: const Text('Anterior'),
                            )
                          else
                            const SizedBox(width: 80),
                          const SizedBox(width: 12),
                          FilledButton.icon(
                            onPressed: _proximaPagina,
                            style: FilledButton.styleFrom(
                              backgroundColor: corAtiva,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            icon: Icon(
                              naUltimaPagina
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(
                              naUltimaPagina
                                  ? (widget.modoRevisao
                                      ? 'Concluir Tutorial'
                                      : 'Começar a Monitorar')
                                  : 'Próximo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            onPressed: _proximaPagina,
                            style: FilledButton.styleFrom(
                              backgroundColor: corAtiva,
                              foregroundColor: Colors.black87,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 14,
                              ),
                            ),
                            icon: Icon(
                              naUltimaPagina
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.arrow_forward_rounded,
                              size: 18,
                            ),
                            label: Text(
                              naUltimaPagina
                                  ? (widget.modoRevisao
                                      ? 'Concluir Tutorial'
                                      : 'Começar a Monitorar')
                                  : 'Próximo',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (_paginaAtual > 0) ...[
                            const SizedBox(height: 8),
                            OutlinedButton.icon(
                              onPressed: _paginaAnterior,
                              icon: const Icon(
                                Icons.arrow_back_rounded,
                                size: 18,
                              ),
                              label: const Text('Anterior'),
                            ),
                          ],
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  ),
);
  }
}

// ============================================================================
// SLIDE 1: A BOIA BIOGLOW E CONEXÃO EM CAMPO (COM IMAGEM REAL DA BOIA)
// ============================================================================

class _Slide1BoiaConexao extends StatelessWidget {
  const _Slide1BoiaConexao();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const corDestaque = Color(0xFF00BCD4);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Ilustração oficial da Boia Bioglow em destaque minimalista
          SizedBox(
            height: 235,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  width: 210,
                  height: 210,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        corDestaque.withValues(alpha: 0.22),
                        corDestaque.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 24),
                  child: Image.asset(
                    kAssetBoiaBioglow,
                    height: 195,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.medium,
                  ),
                ),
                Positioned(
                  top: 0,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: corDestaque.withValues(alpha: 0.45),
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.wifi_tethering,
                          color: corDestaque,
                          size: 15,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Wi-Fi: Bioglow_Boia',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Estação Aquática Autônoma',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'O Água Viva - Monitoramento transforma o seu celular ou tablet em uma central científica de '
            'monitoramento da qualidade da água em tempo real, projetada para '
            'pesquisadores em campo.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.45,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          const _ItemDestaqueTutorial(
            icone: Icons.wifi_rounded,
            cor: corDestaque,
            titulo: 'Rede Wi-Fi Própria na Boia',
            descricao:
                'Funciona em rios, represas ou no mar sem precisar de internet ou sinal de operadora.',
          ),
          const SizedBox(height: 10),
          const _ItemDestaqueTutorial(
            icone: Icons.update_rounded,
            cor: corDestaque,
            titulo: 'Sincronização Automática de Horário',
            descricao:
                'Assim que você conecta, o aplicativo ajusta o relógio interno da boia com a hora exata do seu celular.',
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// SLIDE 2: OS 4 SENSORES DE QUALIDADE DA ÁGUA (COM IMAGENS PNG DOS SENSORES)
// ============================================================================

class _Slide2QuatroSensores extends StatelessWidget {
  const _Slide2QuatroSensores();

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 4),
      child: Column(
        children: [
          Text(
            '4 Sensores Físico-Químicos',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'Toque em qualquer sensor abaixo para ampliar a visualização do '
            'módulo utilizado na boia:',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 14),
          // Grade 2x2 minimalista com os PNGs reais dos 4 sensores
          Row(
            children: [
              Expanded(
                child: _CardHardwareSensor(
                  sensor: TipoSensor.ph,
                  cor: cores.ph,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardHardwareSensor(
                  sensor: TipoSensor.temperatura,
                  cor: cores.temperatura,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _CardHardwareSensor(
                  sensor: TipoSensor.condutividade,
                  cor: cores.condutividade,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _CardHardwareSensor(
                  sensor: TipoSensor.turbidez,
                  cor: cores.turbidez,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _ItemDestaqueTutorial(
            icone: Icons.science_outlined,
            cor: cores.ph,
            titulo: 'Análise Combinada em Tempo Real',
            descricao:
                'O cruzamento de pH, Temperatura, Condutividade e Turbidez permite identificar anomalias ambientais instantaneamente.',
          ),
        ],
      ),
    );
  }
}

class _CardHardwareSensor extends StatelessWidget {
  final TipoSensor sensor;
  final Color cor;

  const _CardHardwareSensor({
    required this.sensor,
    required this.cor,
  });

  void _ampliarSensor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: cor.withValues(alpha: 0.45)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                height: 190,
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Image.asset(
                  sensor.assetImagem,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconeDoSensor(sensor), color: cor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    sensor.nome,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${sensor.subtitulo} • Unidade: ${sensor.unidade}',
                style: TextStyle(
                  fontSize: 13,
                  color: scheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: cor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  sensor.descricaoFaixa,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: cor,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Fechar'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _ampliarSensor(context),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.28),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: cor.withValues(alpha: 0.35),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Container claro suave para destacar os cabos escuros dos sensores
              Container(
                height: 86,
                width: double.infinity,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withValues(alpha: 0.92)
                      : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Image.asset(
                  sensor.assetImagem,
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.medium,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Icon(iconeDoSensor(sensor), color: cor, size: 15),
                  const SizedBox(width: 5),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sensor.nome,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                '${sensor.unidade} • ${sensor.descricaoFaixa}',
                maxLines: 2,
                style: TextStyle(
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

// ============================================================================
// SLIDE 3: GRÁFICOS INTERATIVOS, TABELAS E EXPORTAÇÃO CSV
// ============================================================================

class _Slide3GraficosTabelas extends StatelessWidget {
  const _Slide3GraficosTabelas();

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Ilustração de Gráfico + Tabela + Exportação CSV
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ChipDemo(texto: 'pH', cor: cores.ph, ativo: true),
                      const SizedBox(width: 6),
                      _ChipDemo(
                          texto: 'Temp.', cor: cores.temperatura, ativo: false),
                      const SizedBox(width: 6),
                      _ChipDemo(
                          texto: 'Condut.',
                          cor: cores.condutividade,
                          ativo: false),
                      const SizedBox(width: 6),
                      _ChipDemo(
                          texto: 'Turbidez', cor: cores.turbidez, ativo: false),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 90,
                  width: double.infinity,
                  child: CustomPaint(
                    size: const Size(double.infinity, 90),
                    painter: _CurvaGraficoDemoPainter(
                      corLinha: cores.ph,
                      corSecundaria: cores.condutividade,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Text(
                          '10:14:02  •  7.21 pH  •  24.5 °C  •  390 µS/cm',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                      const SizedBox(width: 6),
                      IconePng(
                        IconesApp.share,
                        size: 15,
                        color: cores.condutividade,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Gráficos, Tabelas e Alertas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Visualize o comportamento de cada sensor separadamente com '
            'escalas inteligentes e exporte os dados para suas planilhas.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ItemDestaqueTutorial(
            icone: Icons.ssid_chart_rounded,
            assetIconePng: IconesApp.chart,
            cor: cores.condutividade,
            titulo: 'Seleção de Grandeza com 1 Toque',
            descricao:
                'Toque em qualquer card de sensor para exibir sua curva temporal e a faixa ideal tracejada no gráfico.',
          ),
          const SizedBox(height: 10),
          _ItemDestaqueTutorial(
            icone: Icons.table_view_rounded,
            assetIconePng: IconesApp.share,
            cor: cores.ok,
            titulo: 'Tabelas em Tempo Real & Exportação CSV',
            descricao:
                'Confira o histórico cronológico na tela ou copie a tabela completa em CSV para usar no Excel.',
          ),
        ],
      ),
    );
  }
}

class _ChipDemo extends StatelessWidget {
  final String texto;
  final Color cor;
  final bool ativo;

  const _ChipDemo({
    required this.texto,
    required this.cor,
    required this.ativo,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: ativo ? cor.withValues(alpha: 0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: ativo ? cor : cor.withValues(alpha: 0.35),
        ),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 12,
          fontWeight: ativo ? FontWeight.w700 : FontWeight.w500,
          color: cor,
        ),
      ),
    );
  }
}

// ============================================================================
// SLIDE 4: ARMAZENAMENTO NO CARTÃO MICRO SD E RELATÓRIOS
// ============================================================================

class _Slide4ArmazenamentoSd extends StatelessWidget {
  const _Slide4ArmazenamentoSd();

  @override
  Widget build(BuildContext context) {
    final cores = CoresBioglow.of(context);
    final scheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      child: Column(
        children: [
          // Ilustração do Cartão SD + Linha do Tempo Autônoma
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.4),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _IconeEtapaSd(
                        icone: Icons.sd_storage_rounded,
                        rotulo: 'Boia grava\nno MicroSD',
                        cor: cores.turbidez,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Icon(
                        Icons.trending_flat_rounded,
                        color: scheme.outline,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: _IconeEtapaSd(
                        icone: Icons.notifications_active_outlined,
                        rotulo: 'Aviso ao\nretornar',
                        cor: cores.alerta,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 15),
                      child: Icon(
                        Icons.trending_flat_rounded,
                        color: scheme.outline,
                        size: 22,
                      ),
                    ),
                    Expanded(
                      child: _IconeEtapaSd(
                        icone: Icons.insights_rounded,
                        assetIconePng: IconesApp.chart,
                        rotulo: 'Relatório\n1h a 24h+',
                        cor: cores.condutividade,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cores.turbidez.withValues(alpha: 0.4),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        color: cores.turbidez,
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          '1.800 leituras salvas no SD enquanto você esteve fora',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Armazenamento no Cartão SD',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Você não precisa ficar o dia todo ao lado da boia. Mesmo sem o '
            'celular por perto, ela continua registrando tudo no cartão MicroSD.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  height: 1.4,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          _ItemDestaqueTutorial(
            icone: Icons.history_toggle_off_rounded,
            cor: cores.turbidez,
            titulo: 'Detecção Inteligente de Ausência',
            descricao:
                'Ao voltar ao local e abrir o app, ele informa quantas leituras foram gravadas desde a sua saída.',
          ),
          const SizedBox(height: 10),
          _ItemDestaqueTutorial(
            icone: Icons.analytics_outlined,
            assetIconePng: IconesApp.chart,
            cor: cores.ph,
            titulo: 'Síntese de Mínimo, Média e Máximo',
            descricao:
                'Consulte relatórios de 1 h, 6 h, 24 h ou todo o período do cartão SD com estatísticas prontas para sua pesquisa.',
          ),
        ],
      ),
    );
  }
}

class _IconeEtapaSd extends StatelessWidget {
  final IconData icone;
  final String? assetIconePng;
  final String rotulo;
  final Color cor;

  const _IconeEtapaSd({
    required this.icone,
    this.assetIconePng,
    required this.rotulo,
    required this.cor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 54,
          height: 54,
          decoration: BoxDecoration(
            color: cor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: cor.withValues(alpha: 0.5)),
          ),
          child: Center(
            child: assetIconePng != null
                ? IconePng(assetIconePng!, color: cor, size: 25)
                : Icon(icone, color: cor, size: 26),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          rotulo,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

// ============================================================================
// COMPONENTES VISUAIS E PAINTERS DAS ILUSTRAÇÕES
// ============================================================================

class _ItemDestaqueTutorial extends StatelessWidget {
  final IconData icone;
  final String? assetIconePng;
  final Color cor;
  final String titulo;
  final String descricao;

  const _ItemDestaqueTutorial({
    required this.icone,
    this.assetIconePng,
    required this.cor,
    required this.titulo,
    required this.descricao,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: assetIconePng != null
                ? IconePng(assetIconePng!, color: cor, size: 20)
                : Icon(icone, color: cor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 14.5,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  descricao,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CurvaGraficoDemoPainter extends CustomPainter {
  final Color corLinha;
  final Color corSecundaria;

  const _CurvaGraficoDemoPainter({
    required this.corLinha,
    required this.corSecundaria,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paintGuia = Paint()
      ..color = corSecundaria.withValues(alpha: 0.35)
      ..strokeWidth = 1;

    final yIdealTop = size.height * 0.25;
    final yIdealBot = size.height * 0.75;
    for (double x = 0; x < size.width; x += 10) {
      canvas.drawLine(
          Offset(x, yIdealTop), Offset(x + 5, yIdealTop), paintGuia);
      canvas.drawLine(
          Offset(x, yIdealBot), Offset(x + 5, yIdealBot), paintGuia);
    }

    final path = Path();
    final area = Path();
    const n = 40;
    for (var i = 0; i <= n; i++) {
      final t = i / n;
      final x = t * size.width;
      final y = size.height * 0.5 +
          math.sin(t * math.pi * 2.2) * (size.height * 0.22) +
          math.cos(t * math.pi * 5) * (size.height * 0.06);
      if (i == 0) {
        path.moveTo(x, y);
        area.moveTo(x, size.height);
        area.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        area.lineTo(x, y);
      }
    }
    area.lineTo(size.width, size.height);
    area.close();

    final paintArea = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          corLinha.withValues(alpha: 0.28),
          corLinha.withValues(alpha: 0.0),
        ],
      ).createShader(Offset.zero & size);

    final paintLinha = Paint()
      ..color = corLinha
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(area, paintArea);
    canvas.drawPath(path, paintLinha);
  }

  @override
  bool shouldRepaint(covariant _CurvaGraficoDemoPainter oldDelegate) =>
      oldDelegate.corLinha != corLinha;
}
