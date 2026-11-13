import 'package:bioglow_receptor/data/configuracoes_repository.dart';
import 'package:bioglow_receptor/data/esp32_websocket_service.dart';
import 'package:bioglow_receptor/domain/entities/configuracoes.dart';
import 'package:bioglow_receptor/domain/entities/leitura_entity.dart';
import 'package:bioglow_receptor/domain/entities/sensor_info.dart';
import 'package:bioglow_receptor/presentation/cubit/configuracoes_cubit.dart';
import 'package:bioglow_receptor/presentation/cubit/dashboard_cubit.dart';
import 'package:bioglow_receptor/presentation/theme/app_theme.dart';
import 'package:bioglow_receptor/presentation/widgets/faixa_sensor_dialog.dart';
import 'package:bioglow_receptor/presentation/widgets/sensor_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('FaixaIdealSensor e avaliação de sensores', () {
    test('retorna as faixas padrão de cada sensor', () {
      const cfg = Configuracoes();
      expect(cfg.faixaDoSensor(TipoSensor.ph),
          const FaixaIdealSensor(min: 6.5, max: 8.5));
      expect(cfg.faixaDoSensor(TipoSensor.temperatura),
          const FaixaIdealSensor(min: 15.0, max: 30.0));
      expect(cfg.faixaDoSensor(TipoSensor.condutividade),
          const FaixaIdealSensor(min: 50.0, max: 1500.0));
      expect(cfg.faixaDoSensor(TipoSensor.turbidez),
          const FaixaIdealSensor(min: 0.0, max: 40.0));
    });

    test('avalia 3 níveis (ideal, atenção com 15% de margem e alerta)', () {
      // Faixa customizada: 10.0 a 20.0 (amplitude = 10.0 -> margem 15% = 1.5)
      // Atenção inferior: [8.5, 10.0), Ideal: [10.0, 20.0], Atenção superior: (20.0, 21.5]
      const faixa = FaixaIdealSensor(min: 10.0, max: 20.0);

      expect(
        TipoSensor.temperatura.avaliar(null, faixa: faixa),
        StatusQualidadeSensor.aguardandoHardware,
      );
      expect(
        TipoSensor.temperatura.avaliar(15.0, faixa: faixa),
        StatusQualidadeSensor.ideal,
      );
      expect(
        TipoSensor.temperatura.avaliar(9.0, faixa: faixa),
        StatusQualidadeSensor.atencao,
      );
      expect(
        TipoSensor.temperatura.avaliar(21.0, faixa: faixa),
        StatusQualidadeSensor.atencao,
      );
      expect(
        TipoSensor.temperatura.avaliar(7.0, faixa: faixa),
        StatusQualidadeSensor.alerta,
      );
      expect(
        TipoSensor.temperatura.avaliar(23.0, faixa: faixa),
        StatusQualidadeSensor.alerta,
      );
    });

    test('valida limites mínimo e máximo por sensor', () {
      expect(TipoSensor.ph.validarFaixa(6.5, 8.5), isNull);
      expect(TipoSensor.ph.validarFaixa(8.5, 6.5), isNotNull);
      expect(TipoSensor.ph.validarFaixa(7.0, 7.0), isNotNull);
      expect(TipoSensor.ph.validarFaixa(-1.0, 8.0), isNotNull);
      expect(TipoSensor.ph.validarFaixa(6.0, 15.0), isNotNull);
    });

    test('persiste e restaura faixas personalizadas no ConfiguracoesCubit', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ConfiguracoesRepository(prefs);
      final cubit = ConfiguracoesCubit(repo);

      await cubit.definirFaixaSensor(
        TipoSensor.ph,
        const FaixaIdealSensor(min: 6.8, max: 7.6),
      );

      expect(
        cubit.state.faixaDoSensor(TipoSensor.ph),
        const FaixaIdealSensor(min: 6.8, max: 7.6),
      );
      expect(cubit.state.temFaixaPersonalizada(TipoSensor.ph), isTrue);

      // Recarrega do repositório para garantir persistência
      final recarregado = repo.carregar();
      expect(
        recarregado.faixaDoSensor(TipoSensor.ph),
        const FaixaIdealSensor(min: 6.8, max: 7.6),
      );

      // Restaura apenas o pH para o padrão
      await cubit.restaurarFaixaSensor(TipoSensor.ph);
      expect(
        cubit.state.faixaDoSensor(TipoSensor.ph),
        const FaixaIdealSensor(min: 6.5, max: 8.5),
      );
      expect(cubit.state.temFaixaPersonalizada(TipoSensor.ph), isFalse);

      await cubit.close();
    });

    testWidgets('CardSensorFisicoQuimico reflete faixa personalizada do Cubit',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      await cubit.definirFaixaSensor(
        TipoSensor.ph,
        const FaixaIdealSensor(min: 7.0, max: 7.5),
      );

      await tester.pumpWidget(
        BlocProvider.value(
          value: cubit,
          child: MaterialApp(
            theme: temaBioglow(Brightness.dark),
            home: const Scaffold(
              body: CardSensorFisicoQuimico(
                sensor: TipoSensor.ph,
                valor: 6.5, // Fora da faixa personalizada [7.0, 7.5]
              ),
            ),
          ),
        ),
      );

      expect(find.text('Ideal: 7,00 – 7,50 pH'), findsOneWidget);
      expect(find.text('Fora da faixa'), findsOneWidget);

      // Segurar o card abre o diálogo de edição da faixa ideal do sensor
      await tester.longPress(find.byType(CardSensorFisicoQuimico));
      await tester.pumpAndSettle();

      expect(find.text('Faixa Ideal • pH da Água'), findsOneWidget);

      await tester.tap(find.text('Padrão'));
      await tester.pump();
      await tester.tap(find.text('Salvar'));
      await tester.pumpAndSettle();

      expect(cubit.state.temFaixaPersonalizada(TipoSensor.ph), isFalse);
      expect(find.text('Faixa ideal'), findsOneWidget);

      mostrarEscolhaInicialFaixas(
        tester.element(find.byType(CardSensorFisicoQuimico)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Seguir com comuns'));
      await tester.pumpAndSettle();

      await cubit.close();
    });

    test('exportacao CSV inclui min, max e lido por sensor e reflete alteracoes nas configuracoes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));

      final leitura = LeituraEntity(
        data: '12/11/2026',
        hora: '09:45:00',
        recebidoEm: DateTime(2026, 11, 12, 9, 45),
        ph: 7.18,
        temperatura: 24.5,
        condutividade: 412.0,
        turbidez: 14.2,
      );

      expect(
        LeituraEntity.cabecalhoCsv,
        'data;hora;'
        'ph_min;ph_max;ph_lido;'
        'temperatura_min;temperatura_max;temperatura_lido;'
        'condutividade_min;condutividade_max;condutividade_lido;'
        'turbidez_min;turbidez_max;turbidez_lido',
      );

      // Com faixas padrão
      expect(
        leitura.toCsvLine(cubit.state),
        '12/11/2026;09:45:00;'
        '6.50;8.50;7.18;'
        '15.0;30.0;24.5;'
        '50.0;1500.0;412.0;'
        '0.0;40.0;14.2',
      );

      // Usuário altera as faixas ideais nas configurações
      await cubit.definirFaixaSensor(
        TipoSensor.ph,
        const FaixaIdealSensor(min: 6.8, max: 7.4),
      );
      await cubit.definirFaixaSensor(
        TipoSensor.temperatura,
        const FaixaIdealSensor(min: 18.5, max: 28.0),
      );
      await cubit.definirFaixaSensor(
        TipoSensor.condutividade,
        const FaixaIdealSensor(min: 100.0, max: 800.0),
      );
      await cubit.definirFaixaSensor(
        TipoSensor.turbidez,
        const FaixaIdealSensor(min: 2.0, max: 25.0),
      );

      // O CSV gerado deve refletir os novos valores de min e max configurados pelo usuário
      expect(
        leitura.toCsvLine(cubit.state),
        '12/11/2026;09:45:00;'
        '6.80;7.40;7.18;'
        '18.5;28.0;24.5;'
        '100.0;800.0;412.0;'
        '2.0;25.0;14.2',
      );

      await cubit.close();
    });
  });

  group('Simulador adaptativo por faixa ideal', () {
    test('mantém leituras normais na faixa e gera anomalias fora das faixas personalizadas', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final ws = Esp32WebSocketService(url: 'ws://127.0.0.1:81/ws');
      final dashCubit = DashboardCubit(ws, cfgCubit);

      // 1. Com faixas padrão
      dashCubit.definirModoSimulacao(true);
      expect(dashCubit.state.modoSimulacao, isTrue);
      expect(dashCubit.state.historico, isNotEmpty);
      for (final leitura in dashCubit.state.historico) {
        for (final s in TipoSensor.values) {
          expect(
            s.avaliar(leitura.valorDoSensor(s), faixa: cfgCubit.state.faixaDoSensor(s)),
            StatusQualidadeSensor.ideal,
            reason: 'Leitura normal padrão de ${s.id} deve estar ideal',
          );
        }
      }

      dashCubit.alternarAnomaliaSimulada();
      expect(dashCubit.state.simulandoAnomalia, isTrue);
      final anomPadrao = dashCubit.state.ultima!;
      for (final s in TipoSensor.values) {
        expect(
          s.avaliar(anomPadrao.valorDoSensor(s), faixa: cfgCubit.state.faixaDoSensor(s)),
          StatusQualidadeSensor.alerta,
          reason: 'Anomalia padrão de ${s.id} (${anomPadrao.valorDoSensor(s)}) deve ficar em alerta',
        );
      }

      // 2. Usuário define faixas personalizadas que englobam os antigos valores fixos
      await cfgCubit.definirFaixaSensor(
        TipoSensor.ph,
        const FaixaIdealSensor(min: 2.0, max: 6.0),
      );
      await cfgCubit.definirFaixaSensor(
        TipoSensor.temperatura,
        const FaixaIdealSensor(min: 28.0, max: 40.0),
      );
      await cfgCubit.definirFaixaSensor(
        TipoSensor.condutividade,
        const FaixaIdealSensor(min: 100.0, max: 1100.0),
      );
      await cfgCubit.definirFaixaSensor(
        TipoSensor.turbidez,
        const FaixaIdealSensor(min: 0.0, max: 200.0),
      );

      // Volta para água normal -> deve ficar dentro das novas faixas ideais
      dashCubit.alternarAnomaliaSimulada();
      expect(dashCubit.state.simulandoAnomalia, isFalse);
      final normalCustom = dashCubit.state.ultima!;
      for (final s in TipoSensor.values) {
        expect(
          s.avaliar(normalCustom.valorDoSensor(s), faixa: cfgCubit.state.faixaDoSensor(s)),
          StatusQualidadeSensor.ideal,
          reason: 'Normal personalizado de ${s.id} (${normalCustom.valorDoSensor(s)}) deve ser ideal',
        );
      }

      // Ativa anomalia repetidas vezes -> sempre fora das faixas personalizadas
      for (var i = 0; i < 6; i++) {
        dashCubit.alternarAnomaliaSimulada(); // liga anomalia
        final anomCustom = dashCubit.state.ultima!;
        for (final s in TipoSensor.values) {
          final st = s.avaliar(
            anomCustom.valorDoSensor(s),
            faixa: cfgCubit.state.faixaDoSensor(s),
          );
          expect(
            st,
            StatusQualidadeSensor.alerta,
            reason: 'Anomalia personalizada #${i + 1} de ${s.id} (${anomCustom.valorDoSensor(s)}) deve estar em alerta',
          );
        }
        dashCubit.alternarAnomaliaSimulada(); // volta para normal
      }

      // Desativa simulador
      dashCubit.definirModoSimulacao(false);
      expect(dashCubit.state.modoSimulacao, isFalse);
      expect(dashCubit.state.simulandoAnomalia, isFalse);

      await dashCubit.close();
      await cfgCubit.close();
      ws.dispose();
    });

    test('faixa próxima ao limite físico sem espaço de alerta ainda sai da faixa ideal', () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final cfgCubit = ConfiguracoesCubit(ConfiguracoesRepository(prefs));
      final ws = Esp32WebSocketService(url: 'ws://127.0.0.1:81/ws');
      final dashCubit = DashboardCubit(ws, cfgCubit);

      // pH quase na escala inteira: margem 15% encosta em 0 e 14, mas há folga fora da faixa ideal
      await cfgCubit.definirFaixaSensor(
        TipoSensor.ph,
        const FaixaIdealSensor(min: 1.0, max: 13.5),
      );
      dashCubit.definirModoSimulacao(true);
      dashCubit.alternarAnomaliaSimulada();
      final leitura = dashCubit.state.ultima!;
      final st = TipoSensor.ph.avaliar(
        leitura.ph,
        faixa: cfgCubit.state.faixaDoSensor(TipoSensor.ph),
      );
      expect(st, isNot(StatusQualidadeSensor.ideal));

      dashCubit.definirModoSimulacao(false);
      await dashCubit.close();
      await cfgCubit.close();
      ws.dispose();
    });
  });
}
