#include <Arduino.h>
#include <OneWire.h>
#include <DallasTemperature.h>

// ============================================================================
// MINI CÓDIGO DE DIAGNÓSTICO DO SENSOR DS18B20 - PROJETO BIOGLOW (ESP32)
// ============================================================================
#define PINO_DS18B20 4  // Mesmo pino usado no bioglow_boia.ino (GPIO 4)

OneWire oneWire(PINO_DS18B20);
DallasTemperature sensors(&oneWire);

int totalSensores = 0;

void imprimirEnderecoHex(DeviceAddress addr) {
  for (uint8_t i = 0; i < 8; i++) {
    if (addr[i] < 16) Serial.print("0");
    Serial.print(addr[i], HEX);
    if (i < 7) Serial.print(":");
  }
}

void testarEletricaOneWire() {
  Serial.println("\n--- [ETAPA 1] DIAGNOSTICO ELETRICO DO PINO GPIO 4 (1-WIRE) ---");

  // 1. Mede a linha SEM pull-up interno do ESP32 para checar se o pull-up EXTERNO existe
  pinMode(PINO_DS18B20, INPUT);
  delay(20);
  int nivelExterno = digitalRead(PINO_DS18B20);
  uint32_t mvExterno = analogReadMilliVolts(PINO_DS18B20); // GPIO 4 = ADC2_CH0 (funciona sem Wi-Fi)

  // 2. Mede a linha COM pull-up interno do ESP32 para checar se ha curto com GND
  pinMode(PINO_DS18B20, INPUT_PULLUP);
  delay(20);
  int nivelInterno = digitalRead(PINO_DS18B20);
  uint32_t mvInterno = analogReadMilliVolts(PINO_DS18B20);

  Serial.printf(" -> Sem pull-up interno (apenas circuito externo): %s (~%u mV)\n",
                nivelExterno ? "HIGH" : "LOW", (unsigned int)mvExterno);
  Serial.printf(" -> Com pull-up interno do ESP32 ativado:          %s (~%u mV)\n",
                nivelInterno ? "HIGH" : "LOW", (unsigned int)mvInterno);

  if (nivelInterno == LOW || mvInterno < 500) {
    Serial.println("[ERRO CRITICO] O GPIO 4 esta preso em LOW (0V)!");
    Serial.println(" -> Possiveis causas:");
    Serial.println("    1. Curto-circuito entre o fio de dados (amarelo/branco) e o GND.");
    Serial.println("    2. Sensor DS18B20 ligado invertido (GND e VCC trocados esquentam o sensor e prendem a linha).");
  } else if (nivelExterno == LOW || mvExterno < 2000) {
    Serial.println("[ALERTA DE HARDWARE] A linha cai quando o pull-up interno e desligado!");
    Serial.println(" -> O resistor de pull-up externo (4.7 kOhm entre GPIO 4 e 3.3V) parece AUSENTE ou com MAU CONTATO!");
    Serial.println(" -> O DS18B20 exige um resistor de 4.7 kOhm entre Dados (GPIO 4) e 3.3V.");
  } else {
    Serial.println("[OK] Tensao de repouso em nivel ALTO (~3.3V). Resistor de pull-up externo detectado!");
  }
}

void escanearBarramentoOneWire() {
  Serial.println("\n--- [ETAPA 2] VARREDURA DO BARRAMENTO 1-WIRE ---");

  uint8_t presente = oneWire.reset();
  if (!presente) {
    Serial.println("[FALHA] Nenhum pulso de presenca (Presence Pulse) detectado no GPIO 4!");
    Serial.println(" -> O ESP32 chamou o sensor no GPIO 4, mas ninguem respondeu.");
    Serial.println(" -> Verifique se o fio de Dados do DS18B20 esta realmente no pino D4 (GPIO 4) e o GND conectado.");
    return;
  }
  Serial.println("[OK] Pulso de presenca 1-Wire detectado na linha!");

  oneWire.reset_search();
  DeviceAddress addr;
  int encontrados = 0;

  while (oneWire.search(addr)) {
    encontrados++;
    Serial.printf(" -> Dispositivo #%d encontrado! Endereco ROM: ", encontrados);
    imprimirEnderecoHex(addr);

    if (OneWire::crc8(addr, 7) != addr[7]) {
      Serial.println(" [ERRO DE CRC! Ruido eletrico ou mau contato no cabo]");
    } else {
      Serial.print(" [CRC OK] - Tipo: ");
      switch (addr[0]) {
        case 0x28: Serial.println("DS18B20"); break;
        case 0x10: Serial.println("DS18S20 / DS1820"); break;
        case 0x22: Serial.println("DS1822"); break;
        default:   Serial.println("Familia desconhecida"); break;
      }
    }
  }

  if (encontrados == 0) {
    Serial.println("[ALERTA] Houve pulso na linha, mas nenhum endereco ROM valido foi lido (possivel falta de pull-up ou ruido).");
  }
}

void executarDiagnosticoInicial() {
  Serial.println("\n============================================================");
  Serial.println("   DIAGNOSTICO DO SENSOR DE TEMPERATURA DS18B20 (BIOGLOW)");
  Serial.println("============================================================");
  Serial.printf("Pino configurado: GPIO %d\n", PINO_DS18B20);

  testarEletricaOneWire();
  escanearBarramentoOneWire();

  Serial.println("\n--- [ETAPA 3] INICIALIZACAO DALLASTEMPERATURE ---");
  sensors.begin();
  totalSensores = sensors.getDeviceCount();
  Serial.printf("Sensores reconhecidos pela biblioteca: %d\n", totalSensores);
  Serial.printf("Modo de alimentacao parasita: %s\n",
                sensors.isParasitePowerMode()
                    ? "ATIVO (ALERTA: O pino VCC vermelho do sensor pode estar desconectado!)"
                    : "NAO (Alimentacao VCC normal OK)");

  if (totalSensores > 0) {
    sensors.setResolution(12);
    Serial.printf("Resolucao configurada: %d bits\n", sensors.getResolution());
  }

  Serial.println("\n--- [ETAPA 4] LEITURA CONTINUA (a cada 1.5 s) ---");
  Serial.println("Comandos no Monitor Serial: digite [r] para rodar o diagnostico completo novamente.\n");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  executarDiagnosticoInicial();
}

unsigned long ultimaLeitura = 0;

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r' || c == 'R') {
      executarDiagnosticoInicial();
    }
  }

  if (millis() - ultimaLeitura >= 1500) {
    ultimaLeitura = millis();

    unsigned long t0 = millis();
    sensors.requestTemperatures();
    unsigned long dt = millis() - t0;

    float tempC = sensors.getTempCByIndex(0);

    Serial.printf("[%6lu ms] Temp: %7.2f C (conversao: %lu ms) -> ",
                  millis(), tempC, dt);

    if (tempC == DEVICE_DISCONNECTED_C || tempC <= -127.0f) {
      Serial.println("ERRO (-127 C): Sensor desconectado, fio de dados solto ou falta de pull-up (4.7k)!");
    } else if (tempC == 85.0f) {
      Serial.println("ALERTA (85.0 C): Valor de reset do DS18B20! O fio VCC (3.3V) esta com mau contato ou pull-up fraco.");
    } else if (tempC < -55.0f || tempC > 125.0f) {
      Serial.println("ERRO: Leitura fora da faixa fisica do sensor!");
    } else {
      Serial.println("STATUS: OK (Leitura valida!)");
    }
  }
}
