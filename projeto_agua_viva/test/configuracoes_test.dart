import 'package:bioglow_receptor/data/configuracoes_repository.dart';
import 'package:bioglow_receptor/domain/entities/configuracoes.dart';
import 'package:bioglow_receptor/presentation/cubit/configuracoes_cubit.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Configuracoes entity & validacoes', () {
    test('valores padrao', () {
      const c = Configuracoes();
      expect(c.host, '192.168.4.1');
      expect(c.porta, 81);
      expect(c.url, 'ws://192.168.4.1:81');
      expect(c.manterConexaoEmSegundoPlano, false);
      expect(c.janelaAoVivoMin, 2);
      expect(c.maxPontosRelatorio, 600);
      expect(c.avisoAusencia, true);
      expect(c.limiteAusenciaMin, 5);
      expect(c.tema, TemaApp.escuro);
      expect(c.escalaAutomatica, true);
      expect(c.janelaAoVivo, const Duration(minutes: 2));
      expect(c.maxHistoricoAoVivo, 60);
      expect(c.limiteAusencia, const Duration(minutes: 5));
    });

    test('validarHost', () {
      expect(Configuracoes.validarHost('192.168.4.1'), isNull);
      expect(Configuracoes.validarHost('10.0.0.2'), isNull);
      expect(Configuracoes.validarHost('boia.local'), isNull);
      expect(Configuracoes.validarHost('esp32-boia'), isNull);

      expect(Configuracoes.validarHost(''), isNotNull);
      expect(Configuracoes.validarHost('   '), isNotNull);
      expect(Configuracoes.validarHost('999.1.1.1'), isNotNull);
      expect(Configuracoes.validarHost('192.168.1'), isNotNull);
      expect(Configuracoes.validarHost('ip com espaco'), isNotNull);
    });

    test('validarPorta', () {
      expect(Configuracoes.validarPorta('81'), isNull);
      expect(Configuracoes.validarPorta('8080'), isNull);
      expect(Configuracoes.validarPorta('1'), isNull);
      expect(Configuracoes.validarPorta('65535'), isNull);

      expect(Configuracoes.validarPorta(''), isNotNull);
      expect(Configuracoes.validarPorta('0'), isNotNull);
      expect(Configuracoes.validarPorta('65536'), isNotNull);
      expect(Configuracoes.validarPorta('-5'), isNotNull);
      expect(Configuracoes.validarPorta('abc'), isNotNull);
    });

    test('copyWith altera apenas os campos especificados', () {
      const c = Configuracoes();
      final alterada = c.copyWith(
        host: '10.0.0.50',
        porta: 9000,
        tema: TemaApp.claro,
        escalaAutomatica: false,
      );

      expect(alterada.host, '10.0.0.50');
      expect(alterada.porta, 9000);
      expect(alterada.url, 'ws://10.0.0.50:9000');
      expect(alterada.tema, TemaApp.claro);
      expect(alterada.escalaAutomatica, false);
      expect(alterada.janelaAoVivoMin, c.janelaAoVivoMin);
    });
  });

  group('ConfiguracoesRepository', () {
    test('carrega valores padrao com SharedPreferences vazio', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ConfiguracoesRepository(prefs);

      final c = repo.carregar();
      expect(c.host, Configuracoes.hostPadrao);
      expect(c.porta, Configuracoes.portaPadrao);
      expect(c.janelaAoVivoMin, 2);
      expect(c.tema, TemaApp.escuro);
    });

    test('salva e recupera configuracoes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ConfiguracoesRepository(prefs);

      const nova = Configuracoes(
        host: '192.168.1.100',
        porta: 8080,
        manterConexaoEmSegundoPlano: true,
        janelaAoVivoMin: 5,
        maxPontosRelatorio: 1200,
        avisoAusencia: false,
        limiteAusenciaMin: 15,
        tema: TemaApp.claro,
        escalaAutomatica: false,
      );

      await repo.salvar(nova);

      final carregada = repo.carregar();
      expect(carregada.host, '192.168.1.100');
      expect(carregada.porta, 8080);
      expect(carregada.manterConexaoEmSegundoPlano, true);
      expect(carregada.janelaAoVivoMin, 5);
      expect(carregada.maxPontosRelatorio, 1200);
      expect(carregada.avisoAusencia, false);
      expect(carregada.limiteAusenciaMin, 15);
      expect(carregada.tema, TemaApp.claro);
      expect(carregada.escalaAutomatica, false);
    });

    test('limpar restaura preferencias no disco', () async {
      SharedPreferences.setMockInitialValues({'cfg_host': '10.0.0.9'});
      final prefs = await SharedPreferences.getInstance();
      final repo = ConfiguracoesRepository(prefs);

      expect(repo.carregar().host, '10.0.0.9');
      await repo.limpar();
      expect(repo.carregar().host, Configuracoes.hostPadrao);
    });
  });

  group('ConfiguracoesCubit', () {
    test('emite e salva alteracoes', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final repo = ConfiguracoesRepository(prefs);
      final cubit = ConfiguracoesCubit(repo);

      expect(cubit.state.host, Configuracoes.hostPadrao);

      cubit.definirEndereco('192.168.4.5', 90);
      expect(cubit.state.host, '192.168.4.5');
      expect(cubit.state.porta, 90);

      cubit.definirJanelaAoVivo(10);
      expect(cubit.state.janelaAoVivoMin, 10);

      cubit.definirTema(TemaApp.sistema);
      expect(cubit.state.tema, TemaApp.sistema);

      cubit.definirEscalaAutomatica(false);
      expect(cubit.state.escalaAutomatica, false);

      await cubit.restaurarPadroes();
      expect(cubit.state.host, Configuracoes.hostPadrao);
      expect(cubit.state.porta, Configuracoes.portaPadrao);
      expect(cubit.state.escalaAutomatica, true);

      await cubit.close();
    });
  });
}
