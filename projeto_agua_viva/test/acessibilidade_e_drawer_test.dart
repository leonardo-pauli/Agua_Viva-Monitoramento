import 'package:bioglow_receptor/data/configuracoes_repository.dart';
import 'package:bioglow_receptor/data/esp32_websocket_service.dart';
import 'package:bioglow_receptor/domain/entities/leitura_entity.dart';
import 'package:bioglow_receptor/domain/entities/sensor_info.dart';
import 'package:bioglow_receptor/presentation/cubit/configuracoes_cubit.dart';
import 'package:bioglow_receptor/presentation/cubit/dashboard_cubit.dart';
import 'package:bioglow_receptor/presentation/screens/configuracoes_screen.dart';
import 'package:bioglow_receptor/presentation/screens/dashboard_screen.dart';
import 'package:bioglow_receptor/presentation/screens/relatorio_screen.dart';
import 'package:bioglow_receptor/presentation/theme/app_theme.dart';
import 'package:bioglow_receptor/presentation/widgets/faixa_sensor_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeEsp32WebSocketService extends Esp32WebSocketService {
  @override
  Future<void> conectar() async {}

  @override
  Future<void> reconectar() async {}

  @override
  Future<void> pausar() async {}

  @override
  void retomar() {}

  @override
  void definirUrl(String novaUrl) {}
}

void main() {
  group('Responsivo.fatorTexto (acessibilidade por tipo de tela)', () {
    test('adapta o fator de fonte para celular, tablet e desktop', () {
      // Celulares (Android)
      expect(
        const Responsivo(
          Size(320, 640),
          plataforma: TargetPlatform.android,
        ).fatorTexto,
        1.04,
      );
      expect(
        const Responsivo(
          Size(390, 844),
          plataforma: TargetPlatform.android,
        ).fatorTexto,
        1.14,
      );
      expect(
        const Responsivo(
          Size(450, 920),
          plataforma: TargetPlatform.android,
        ).fatorTexto,
        1.20,
      );

      // Tablets (Android)
      expect(
        const Responsivo(
          Size(700, 1000),
          plataforma: TargetPlatform.android,
        ).fatorTexto,
        1.38,
      );
      expect(
        const Responsivo(
          Size(800, 1280),
          plataforma: TargetPlatform.android,
        ).fatorTexto,
        1.45,
      );

      // Desktop (Windows)
      expect(
        const Responsivo(
          Size(900, 700),
          plataforma: TargetPlatform.windows,
        ).fatorTexto,
        1.18,
      );
      expect(
        const Responsivo(
          Size(1200, 800),
          plataforma: TargetPlatform.windows,
        ).fatorTexto,
        1.22,
      );
      expect(
        const Responsivo(
          Size(1600, 900),
          plataforma: TargetPlatform.windows,
        ).fatorTexto,
        1.26,
      );
    });

    test('adapta alturaAppBar para celular, tablet e desktop', () {
      expect(
        const Responsivo(
          Size(390, 844),
          plataforma: TargetPlatform.android,
        ).alturaAppBar,
        64,
      );
      expect(
        const Responsivo(
          Size(700, 1000),
          plataforma: TargetPlatform.android,
        ).alturaAppBar,
        76,
      );
      expect(
        const Responsivo(
          Size(800, 1280),
          plataforma: TargetPlatform.android,
        ).alturaAppBar,
        82,
      );
      expect(
        const Responsivo(
          Size(900, 700),
          plataforma: TargetPlatform.windows,
        ).alturaAppBar,
        76,
      );
      expect(
        const Responsivo(
          Size(1280, 800),
          plataforma: TargetPlatform.windows,
        ).alturaAppBar,
        82,
      );
    });

    test('escalaTexto aumenta todas as fontes quando modoAcessibilidade está ativo', () {
      const mobile = Responsivo(Size(390, 844), plataforma: TargetPlatform.android);
      const tablet = Responsivo(Size(800, 1280), plataforma: TargetPlatform.android);
      const desktop = Responsivo(Size(1280, 800), plataforma: TargetPlatform.windows);

      expect(mobile.escalaTexto(1.0, modoAcessibilidade: false), closeTo(1.14, 0.001));
      expect(mobile.escalaTexto(1.0, modoAcessibilidade: true), closeTo(1.425, 0.001));
      expect(tablet.escalaTexto(1.0, modoAcessibilidade: false), closeTo(1.45, 0.001));
      expect(tablet.escalaTexto(1.0, modoAcessibilidade: true), closeTo(1.8125, 0.001));
      expect(desktop.escalaTexto(1.0, modoAcessibilidade: false), closeTo(1.22, 0.001));
      expect(desktop.escalaTexto(1.0, modoAcessibilidade: true), closeTo(1.525, 0.001));
      expect(tablet.escalaTexto(2.0, modoAcessibilidade: false), 2.15);
      expect(tablet.escalaTexto(2.0, modoAcessibilidade: true), 2.50);
    });
  });

  group('Faixas ideais somente em Configurações (removida do Drawer)', () {
    testWidgets(
      'barra lateral esquerda não exibe opção de faixas ideais e não gera overflow',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cfgCubit),
              BlocProvider.value(value: dashCubit),
            ],
            child: RepositoryProvider<Esp32WebSocketService>.value(
              value: wsService,
              child: MaterialApp(
                theme: temaBioglow(Brightness.dark),
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  final resp = Responsivo(mq.size);
                  final escalaFinal =
                      (mq.textScaler.scale(1.0) * resp.fatorTexto).clamp(
                        1.0,
                        2.15,
                      );
                  return MediaQuery(
                    data: mq.copyWith(
                      textScaler: TextScaler.linear(escalaFinal),
                    ),
                    child: child!,
                  );
                },
                home: const DashboardScreen(),
              ),
            ),
          ),
        );

        await tester.pump();
        await tester.tap(find.byTooltip('Menu principal'));
        await tester.pumpAndSettle();

        expect(find.text('Água Viva - Monitoramento'), findsOneWidget);
        expect(find.text('Início • Painel ao Vivo'), findsOneWidget);
        expect(find.text('Relatório do Cartão SD'), findsOneWidget);
        expect(find.text('Configurações'), findsOneWidget);
        expect(find.text('Faixas Ideais dos Sensores'), findsNothing);
        expect(
          find.text('Definir mínimo e máximo de cada sensor'),
          findsNothing,
        );

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets('ConfiguracoesScreen mantém a definição de faixas ideais', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final wsService = _FakeEsp32WebSocketService();

      await tester.pumpWidget(
        BlocProvider.value(
          value: cfgCubit,
          child: RepositoryProvider<Esp32WebSocketService>.value(
            value: wsService,
            child: MaterialApp(
              theme: temaBioglow(Brightness.dark),
              home: const ConfiguracoesScreen(),
            ),
          ),
        ),
      );

      await tester.pump();

      await tester.scrollUntilVisible(
        find.text('Definir todas as faixas ideais'),
        300,
      );
      expect(find.text('Definir todas as faixas ideais'), findsOneWidget);

      await cfgCubit.close();
      await wsService.dispose();
    });
  });

  group('Layout responsivo sem quebras em celular estreito (360x740)', () {
    Widget comEscalaResponsiva({
      required ConfiguracoesCubit cfgCubit,
      required DashboardCubit dashCubit,
      required Esp32WebSocketService wsService,
      required Widget home,
    }) {
      return MultiBlocProvider(
        providers: [
          BlocProvider.value(value: cfgCubit),
          BlocProvider.value(value: dashCubit),
        ],
        child: RepositoryProvider<Esp32WebSocketService>.value(
          value: wsService,
          child: MaterialApp(
            theme: temaBioglow(Brightness.dark),
            builder: (context, child) {
              final mq = MediaQuery.of(context);
              final resp = Responsivo(mq.size);
              final escalaFinal = resp.escalaTexto(
                mq.textScaler.scale(1.0),
                modoAcessibilidade: cfgCubit.state.modoAcessibilidade,
              );
              return MediaQuery(
                data: mq.copyWith(textScaler: TextScaler.linear(escalaFinal)),
                child: child!,
              );
            },
            home: home,
          ),
        ),
      );
    }

    testWidgets('ConfiguracoesScreen renderiza seletor de tema em cards', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final wsService = _FakeEsp32WebSocketService();
      final dashCubit = DashboardCubit(wsService, cfgCubit);

      await tester.pumpWidget(
        comEscalaResponsiva(
          cfgCubit: cfgCubit,
          dashCubit: dashCubit,
          wsService: wsService,
          home: const ConfiguracoesScreen(),
        ),
      );

      await tester.scrollUntilVisible(find.text('Sistema'), 300);
      expect(find.text('Sistema'), findsOneWidget);
      expect(find.text('Claro'), findsOneWidget);
      expect(find.text('Escuro'), findsOneWidget);

      await dashCubit.close();
      await cfgCubit.close();
      await wsService.dispose();
    });

    testWidgets('DashboardScreen exibe amostras em cards separados abaixo da hora', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final wsService = _FakeEsp32WebSocketService();
      final dashCubit = DashboardCubit(wsService, cfgCubit);
      dashCubit.restaurar([
        LeituraEntity(
          data: '13/11/2026',
          hora: '12:03:11',
          recebidoEm: DateTime(2026, 11, 13, 12, 3, 11),
          ph: 7.06,
          temperatura: 25.1,
          condutividade: 323,
          turbidez: 11.7,
        ),
      ]);

      await tester.pumpWidget(
        comEscalaResponsiva(
          cfgCubit: cfgCubit,
          dashCubit: dashCubit,
          wsService: wsService,
          home: const DashboardScreen(),
        ),
      );
      await tester.pump();

      await tester.scrollUntilVisible(find.text('Amostras Recentes (1)'), 300);
      expect(find.text('Amostras Recentes (1)'), findsOneWidget);
      expect(find.text('13/11/2026  •  12:03:11'), findsOneWidget);
      expect(find.text('pH 7.06'), findsOneWidget);
      expect(find.text('323 µS/cm'), findsOneWidget);

      await dashCubit.close();
      await cfgCubit.close();
      await wsService.dispose();
    });

    testWidgets('RelatorioScreen e dialogo inicial de faixas renderizam sem overflow', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 740);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final wsService = _FakeEsp32WebSocketService();
      final dashCubit = DashboardCubit(wsService, cfgCubit);
      dashCubit.definirModoSimulacao(true);

      await tester.pumpWidget(
        comEscalaResponsiva(
          cfgCubit: cfgCubit,
          dashCubit: dashCubit,
          wsService: wsService,
          home: const RelatorioScreen(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Amostras SD'), findsOneWidget);
      expect(find.text('Mínimo (pH)'), findsOneWidget);

      // Testa também o diálogo inicial de faixas ideais
      mostrarEscolhaInicialFaixas(
        tester.element(find.byType(RelatorioScreen)),
      );
      await tester.pumpAndSettle();
      expect(find.text('Condutividade'), findsOneWidget);
      expect(
        find.text('Faixa comum: 50.0 – 1500.0 µS/cm'),
        findsOneWidget,
      );
      await tester.tap(find.text('Seguir com comuns'));
      await tester.pumpAndSettle();

      await dashCubit.close();
      await cfgCubit.close();
      await wsService.dispose();
    });

    testWidgets('AppBar amplia espessura em tablet/desktop e exibe novo nome', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1280, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final wsService = _FakeEsp32WebSocketService();
      final dashCubit = DashboardCubit(wsService, cfgCubit);

      await tester.pumpWidget(
        comEscalaResponsiva(
          cfgCubit: cfgCubit,
          dashCubit: dashCubit,
          wsService: wsService,
          home: const DashboardScreen(),
        ),
      );
      await tester.pump();

      expect(find.text('Água Viva - Monitoramento'), findsOneWidget);
      expect(tester.getSize(find.byType(AppBar)).height, 82);

      await dashCubit.close();
      await cfgCubit.close();
      await wsService.dispose();
    });

    testWidgets(
      'gráfico de condutividade exibe Mínimo, Média e Máximo em cards sem overflow e usa ícone screen',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);
        final agora = DateTime.now();
        dashCubit.restaurar([
          LeituraEntity(
            data: '13/11/2026',
            hora: '13:15:00',
            recebidoEm: agora.subtract(const Duration(seconds: 20)),
            ph: 7.10,
            temperatura: 25.0,
            condutividade: 424.8,
            turbidez: 12.0,
          ),
          LeituraEntity(
            data: '13/11/2026',
            hora: '13:16:00',
            recebidoEm: agora.subtract(const Duration(seconds: 10)),
            ph: 7.20,
            temperatura: 25.1,
            condutividade: 551.2,
            turbidez: 13.0,
          ),
          LeituraEntity(
            data: '13/11/2026',
            hora: '13:16:30',
            recebidoEm: agora,
            ph: 7.30,
            temperatura: 25.2,
            condutividade: 1108.1,
            turbidez: 14.0,
          ),
        ]);

        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: const DashboardScreen(),
          ),
        );
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('Série Temporal ao Vivo'),
          300,
        );
        final chipCondut = find.text(TipoSensor.condutividade.nomeCurto);
        await tester.ensureVisible(chipCondut);
        await tester.tap(chipCondut);
        await tester.pump();

        await tester.scrollUntilVisible(
          find.text('Média na janela'),
          200,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('Condutividade (µS/cm)'), findsOneWidget);
        expect(find.text('Mínimo'), findsOneWidget);
        expect(find.text('Média na janela'), findsOneWidget);
        expect(find.text('Máximo'), findsOneWidget);
        expect(find.text('424.8 µS/cm'), findsOneWidget);
        expect(find.text('694.7 µS/cm'), findsOneWidget);
        expect(find.text('1108.1 µS/cm'), findsOneWidget);

        final iconesTela = tester
            .widgetList<IconePng>(find.byType(IconePng))
            .where((w) => w.asset == IconesApp.screen);
        expect(iconesTela, isNotEmpty);

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets(
      'popup de limpeza do histórico fecha automaticamente mesmo com acessibilidade ativa',
      (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);
        dashCubit.restaurar([
          LeituraEntity(
            data: '13/11/2026',
            hora: '13:20:00',
            recebidoEm: DateTime(2026, 11, 13, 13, 20),
            ph: 7.1,
            temperatura: 25.0,
            condutividade: 400.0,
            turbidez: 10.0,
          ),
        ]);

        await tester.pumpWidget(
          MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cfgCubit),
              BlocProvider.value(value: dashCubit),
            ],
            child: RepositoryProvider<Esp32WebSocketService>.value(
              value: wsService,
              child: MaterialApp(
                theme: temaBioglow(Brightness.dark),
                builder: (context, child) {
                  final mq = MediaQuery.of(context);
                  return MediaQuery(
                    data: mq.copyWith(accessibleNavigation: true),
                    child: child!,
                  );
                },
                home: const DashboardScreen(),
              ),
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.byTooltip('Limpar histórico'));
        await tester.pump(const Duration(milliseconds: 300));
        await tester.tap(find.text('Limpar'));
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('1 leituras removidas.'), findsOneWidget);
        expect(find.text('Desfazer'), findsOneWidget);

        await tester.pump(const Duration(seconds: 4));
        await tester.pump(const Duration(seconds: 1));
        expect(find.text('1 leituras removidas.'), findsNothing);

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets(
      'opção de acessibilidade em Configurações amplia fontes e mantém layout sem overflow',
      (tester) async {
        tester.view.physicalSize = const Size(360, 740);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);

        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: const ConfiguracoesScreen(),
          ),
        );
        await tester.pump();

        final labelSwitch = find.text('Modo Acessibilidade (Fontes Grandes)');
        await tester.scrollUntilVisible(labelSwitch, 300);
        expect(labelSwitch, findsOneWidget);
        expect(cfgCubit.state.modoAcessibilidade, isFalse);

        await tester.tap(labelSwitch);
        await tester.pump();
        expect(cfgCubit.state.modoAcessibilidade, isTrue);

        // Verifica persistência ao recarregar repositório
        final recarregado = ConfiguracoesRepository(prefs).carregar();
        expect(recarregado.modoAcessibilidade, isTrue);

        // Valida DashboardScreen renderizando com modoAcessibilidade ativo
        dashCubit.restaurar([
          LeituraEntity(
            data: '13/11/2026',
            hora: '13:35:00',
            recebidoEm: DateTime(2026, 11, 13, 13, 35),
            ph: 7.2,
            temperatura: 25.0,
            condutividade: 950.0,
            turbidez: 15.0,
          ),
        ]);
        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: const DashboardScreen(),
          ),
        );
        await tester.pump();

        final contextHome = tester.element(find.byType(DashboardScreen));
        expect(
          MediaQuery.textScalerOf(contextHome).scale(1.0),
          greaterThan(1.3),
        );

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets(
      'diálogo de faixa individual (Condutividade) não gera overflow com teclado aberto',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);

        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => mostrarDialogoFaixaSensor(
                      ctx,
                      TipoSensor.condutividade,
                    ),
                    child: const Text('Editar'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Editar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Faixa Ideal • Condutividade'), findsOneWidget);
        expect(find.text('Salvar'), findsOneWidget);

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets(
      'diálogo de todas as faixas ideais não gera overflow com teclado aberto e fontes grandes',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        cfgCubit.definirModoAcessibilidade(true);
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);

        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: Scaffold(
              body: Builder(
                builder: (ctx) => Center(
                  child: ElevatedButton(
                    onPressed: () => mostrarDialogoTodasFaixasSensores(ctx),
                    child: const Text('Todas'),
                  ),
                ),
              ),
            ),
          ),
        );

        await tester.tap(find.text('Todas'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('Definir Faixas Ideais'), findsOneWidget);
        expect(find.text('Salvar faixas'), findsOneWidget);

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );

    testWidgets(
      'diálogo de endereço da boia não gera overflow com teclado aberto',
      (tester) async {
        tester.view.physicalSize = const Size(360, 720);
        tester.view.devicePixelRatio = 1.0;
        tester.view.viewInsets = const FakeViewPadding(bottom: 340);
        addTearDown(tester.view.reset);

        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
        final wsService = _FakeEsp32WebSocketService();
        final dashCubit = DashboardCubit(wsService, cfgCubit);

        await tester.pumpWidget(
          comEscalaResponsiva(
            cfgCubit: cfgCubit,
            dashCubit: dashCubit,
            wsService: wsService,
            home: const ConfiguracoesScreen(),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Endereço da boia'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));

        expect(find.text('IP ou nome'), findsOneWidget);
        expect(find.text('Porta'), findsOneWidget);

        await dashCubit.close();
        await cfgCubit.close();
        await wsService.dispose();
      },
    );
  });
}
