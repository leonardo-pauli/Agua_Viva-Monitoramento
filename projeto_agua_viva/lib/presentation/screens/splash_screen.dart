import 'package:flutter/material.dart';

import '../../domain/entities/sensor_info.dart';
import '../theme/app_theme.dart';

/// Tela de carregamento inicial (Splash Screen) do aplicativo HidroBô.
///
/// Exibe o ícone da boia sobre fundo roxo, o nome do aplicativo ("HidroBô")
/// e uma barra de progresso animada antes de liberar o painel principal.
class SplashScreen extends StatefulWidget {
  final VoidCallback onConcluir;

  const SplashScreen({super.key, required this.onConcluir});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _progresso;
  late final Animation<double> _escalaLogo;

  static const Color _roxoTopo = Color(0xFF7635BD);
  static const Color _roxoBase = Color(0xFF44167A);
  static const Color _roxoAcento = Color(0xFFB388FF);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _progresso = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeInOutCubic,
    );

    _escalaLogo = Tween<double>(begin: 0.88, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.45, curve: Curves.easeOutBack),
      ),
    );

    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        widget.onConcluir();
      }
    });

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _etapaTexto(double valor) {
    if (valor < 0.38) return 'Inicializando módulos de sensores...';
    if (valor < 0.78) return 'Preparando telemetria Wi-Fi e Cartão SD...';
    return 'Iniciando Água Viva - Monitoramento...';
  }

  @override
  Widget build(BuildContext context) {
    final resp = Responsivo.of(context);
    final tamanhoCardIcone = resp.isTablet ? 168.0 : 132.0;
    final larguraBarra = resp.isTablet ? 340.0 : 250.0;

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF1A0B2E),
              Color(0xFF0E131F),
              Color(0xFF090D16),
            ],
          ),
        ),
        child: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, _) {
                  final pct = (_progresso.value * 100).round();
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Ícone do app (boia_bioglow.png com fundo roxo)
                      Transform.scale(
                        scale: _escalaLogo.value,
                        child: Container(
                          width: tamanhoCardIcone,
                          height: tamanhoCardIcone,
                          padding: EdgeInsets.all(resp.espaco(16)),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(
                              tamanhoCardIcone * 0.24,
                            ),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [_roxoTopo, _roxoBase],
                            ),
                            border: Border.all(
                              color: _roxoAcento.withValues(alpha: 0.55),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _roxoTopo.withValues(alpha: 0.45),
                                blurRadius: 32,
                                spreadRadius: 2,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: Container(
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.35),
                                  Colors.white.withValues(alpha: 0.0),
                                ],
                              ),
                            ),
                            child: Image.asset(
                              kAssetBoiaBioglow,
                              fit: BoxFit.contain,
                              filterQuality: FilterQuality.high,
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: resp.espaco(26)),
                      // Nome do App
                      const Text(
                        'Água Viva - Monitoramento',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                          letterSpacing: 0.4,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Estação de Monitoramento da Qualidade da Água',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14.5,
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      SizedBox(height: resp.espaco(36)),
                      // Barra de Progresso (ProgressBar)
                      SizedBox(
                        width: larguraBarra,
                        child: Column(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: _progresso.value,
                                minHeight: resp.isTablet ? 10 : 8,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.12),
                                valueColor: const AlwaysStoppedAnimation<Color>(
                                  _roxoAcento,
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    _etapaTexto(_progresso.value),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Colors.white.withValues(alpha: 0.68),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '$pct%',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: _roxoAcento,
                                    fontFeatures: [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
