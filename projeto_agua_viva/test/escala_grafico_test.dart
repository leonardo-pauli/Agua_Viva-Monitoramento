import 'package:bioglow_receptor/domain/entities/historico_sd.dart';
import 'package:bioglow_receptor/domain/entities/leitura_entity.dart';
import 'package:bioglow_receptor/domain/entities/sensor_info.dart';
import 'package:bioglow_receptor/presentation/widgets/escala_grafico.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EscalaY.calcular', () {
    test('auto desligado usa escala padrao do sensor', () {
      final e = EscalaY.calcular(
        [10, 20],
        auto: false,
        sensor: TipoSensor.condutividade,
      );
      expect(e.max, 2000);
      expect(e.intervalo, 500);
    });

    test('sem dados usa escala completa do sensor', () {
      final e = EscalaY.calcular(
        const [],
        auto: true,
        sensor: TipoSensor.turbidez,
      );
      expect(e.max, 1000);
    });

    test('ajusta a valores pequenos com passo redondo', () {
      // 123 * 1.1 = 135.3 -> /4 = 33.8 -> passo 50 -> max 200
      final e = EscalaY.calcular(
        [50, 123],
        auto: true,
        sensor: TipoSensor.condutividade,
      );
      expect(e.intervalo, 50);
      expect(e.max, 200);
    });

    test('escala padrao por tipo de sensor', () {
      expect(EscalaY.padraoDoSensor(TipoSensor.ph).max, 14);
      expect(EscalaY.padraoDoSensor(TipoSensor.temperatura).max, 50);
      expect(EscalaY.padraoDoSensor(TipoSensor.condutividade).max, 2000);
      expect(EscalaY.padraoDoSensor(TipoSensor.turbidez).max, 1000);
    });
  });

  group('LeituraEntity & PontoHistorico dos 4 sensores', () {
    test('parseia os 4 sensores no payload ao vivo e no historico SD', () {
      final l = LeituraEntity.fromJson({
        'data': '06/11/2026',
        'hora': '08:00:02.000',
        'ph': 7.25,
        'temp': 24.8,
        'cond': 380.0,
        'turb': 12.4,
      });
      expect(l.ph, 7.25);
      expect(l.temperatura, 24.8);
      expect(l.condutividade, 380.0);
      expect(l.turbidez, 12.4);
      expect(l.sensoresAtivosCount, 4);

      final p = PontoHistorico.fromLista(
        [1788256802, 7.1, 25.2, 410.0, 15.0],
      );
      expect(p, isNotNull);
      expect(p!.ph, 7.1);
      expect(p.temperatura, 25.2);
      expect(p.condutividade, 410.0);
      expect(p.turbidez, 15.0);
    });
  });
}
