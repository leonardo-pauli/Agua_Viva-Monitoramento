import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'data/configuracoes_repository.dart';
import 'data/esp32_websocket_service.dart';
import 'domain/entities/configuracoes.dart';
import 'presentation/cubit/configuracoes_cubit.dart';
import 'presentation/cubit/dashboard_cubit.dart';
import 'presentation/screens/dashboard_screen.dart';
import 'presentation/screens/onboarding_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/theme/app_theme.dart';
import 'presentation/widgets/ausencia_monitor.dart';

/// Permite arrastar carrosséis (PageView) e listas horizontais tanto com o
/// toque (Android/iOS) quanto com mouse e trackpad (Windows/macOS/Linux).
class _ComportamentoScrollMultidispositivo extends MaterialScrollBehavior {
  const _ComportamentoScrollMultidispositivo();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
    PointerDeviceKind.unknown,
  };
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Carrega as preferências antes do primeiro frame para o app já abrir
  // com o tema e o endereço corretos.
  final prefs = await SharedPreferences.getInstance();
  runApp(BioglowApp(configuracoes: ConfiguracoesRepository(prefs)));
}

class BioglowApp extends StatefulWidget {
  final ConfiguracoesRepository configuracoes;

  const BioglowApp({super.key, required this.configuracoes});

  @override
  State<BioglowApp> createState() => _BioglowAppState();
}

class _BioglowAppState extends State<BioglowApp> {
  bool _carregandoSplash = true;
  late bool _mostrarTutorial;

  @override
  void initState() {
    super.initState();
    _mostrarTutorial = !widget.configuracoes.tutorialConcluido;
  }

  Future<void> _concluirTutorialInicial() async {
    await widget.configuracoes.marcarTutorialConcluido();
    if (!mounted) return;
    setState(() => _mostrarTutorial = false);
  }

  @override
  Widget build(BuildContext context) {
    // O serviço é compartilhado entre o dashboard (leituras ao vivo) e o
    // relatório (dados do cartão SD). Quem o encerra é o DashboardCubit.
    return BlocProvider(
      create: (_) => ConfiguracoesCubit(widget.configuracoes),
      child: RepositoryProvider(
        create: (ctx) => Esp32WebSocketService(
          url: ctx.read<ConfiguracoesCubit>().state.url,
        ),
        child: BlocProvider(
          create: (ctx) => DashboardCubit(
            ctx.read<Esp32WebSocketService>(),
            ctx.read<ConfiguracoesCubit>(),
          ),
          child: BlocSelector<
            ConfiguracoesCubit,
            Configuracoes,
            ({TemaApp tema, bool acessibilidade})
          >(
            selector: (c) => (
              tema: c.tema,
              acessibilidade: c.modoAcessibilidade,
            ),
            builder: (context, visual) => MaterialApp(
              title: 'Água Viva - Monitoramento',
              debugShowCheckedModeBanner: false,
              scrollBehavior: const _ComportamentoScrollMultidispositivo(),
              theme: temaBioglow(Brightness.light),
              darkTheme: temaBioglow(Brightness.dark),
              themeMode: modoDoTema(visual.tema),
              builder: (context, child) {
                final mq = MediaQuery.of(context);
                final resp = Responsivo(mq.size);
                final escalaSistema = mq.textScaler.scale(1.0);
                final escalaFinal = resp.escalaTexto(
                  escalaSistema,
                  modoAcessibilidade: visual.acessibilidade,
                );
                final themeAtual = Theme.of(context);
                return MediaQuery(
                  data: mq.copyWith(textScaler: TextScaler.linear(escalaFinal)),
                  child: Theme(
                    data: themeAtual.copyWith(
                      appBarTheme: themeAtual.appBarTheme.copyWith(
                        toolbarHeight: resp.alturaAppBar,
                      ),
                    ),
                    child: IconTheme.merge(
                      data: IconThemeData(size: resp.icone(22)),
                      child: child ?? const SizedBox.shrink(),
                    ),
                  ),
                );
              },
              home: _carregandoSplash
                  ? SplashScreen(
                      onConcluir: () =>
                          setState(() => _carregandoSplash = false),
                    )
                  : _mostrarTutorial
                  ? OnboardingScreen(onConcluir: _concluirTutorialInicial)
                  : const AusenciaMonitor(child: DashboardScreen()),
            ),
          ),
        ),
      ),
    );
  }
}
