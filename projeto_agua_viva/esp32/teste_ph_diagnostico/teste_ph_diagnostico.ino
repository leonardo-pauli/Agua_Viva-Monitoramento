#include <Arduino.h>

// ============================================================================
// MINI CÓDIGO DE DIAGNÓSTICO DO SENSOR DE pH - PROJETO BIOGLOW (ESP32)
// ============================================================================
const int PINO_PH = 35; // Mesmo pino usado no bioglow_boia.ino (ADC1_CH7)

// Mesmos parametros de calibracao do bioglow_boia.ino:
float voltagemNeutroPH = 2.500f; // Tensao esperada em pH 7.0 (ou BNC em curto)
float phNeutro         = 7.0f;
float sensibilidadePH  = 0.18f;  // ~0.18 V por unidade de pH

void diagnosticarSinalEletricoPH() {
  Serial.println("\n--- [ETAPA 1] DIAGNOSTICO DE ESTABILIDADE E FAIXA DO SINAL (GPIO 35) ---");
  Serial.println("Coletando 50 amostras rapidas para medir ruido e nivel DC...");

  uint32_t somaMv = 0;
  uint32_t minMv  = 9999;
  uint32_t maxMv  = 0;

  for (int i = 0; i < 50; i++) {
    uint32_t mv = analogReadMilliVolts(PINO_PH);
    somaMv += mv;
    if (mv < minMv) minMv = mv;
    if (mv > maxMv) maxMv = mv;
    delay(5);
  }

  float mediaMv   = somaMv / 50.0f;
  uint32_t picoPicoMv = maxMv - minMv;

  Serial.printf(" -> Media: %.1f mV (%.3f V) | Min: %u mV | Max: %u mV | Oscilacao (Ruido): %u mV\n",
                mediaMv, mediaMv / 1000.0f, (unsigned int)minMv, (unsigned int)maxMv, (unsigned int)picoPicoMv);

  if (mediaMv < 50.0f) {
    Serial.println("[ERRO CRITICO] Tensao proxima de 0V (< 0.05V) -> ERRO_VOLTAGEM_OUT_OF_RANGE!");
    Serial.println(" -> Possiveis causas:");
    Serial.println("    1. O modulo de pH esta sem alimentacao (VCC 5V ou GND desconectado).");
    Serial.println("    2. O fio do GPIO 35 foi ligado no pino errado do modulo (deve ir no pino Po / PH_OUT).");
    Serial.println("    3. Curto com GND na protoboard.");
  } else if (mediaMv > 3150.0f) {
    Serial.println("[ALERTA CRITICO] Tensao saturando o limite de 3.3V do ESP32 (> 3.15V)!");
    Serial.println(" -> No bioglow_boia.ino, tensoes > 3.25V geram ERRO_VOLTAGEM_OUT_OF_RANGE.");
    Serial.println(" -> Possiveis causas:");
    Serial.println("    1. Sonda BNC desconectada do modulo ou trimpot de offset (azul) girado ate o topo.");
    Serial.println("    2. Modulo PH-4502C alimentado em 5V enviando > 3.3V direto para o GPIO 35.");
    Serial.println("       (Ajuste o trimpot perto do BNC para ~2.500V com o BNC em curto ou em solucao pH 7).");
  } else {
    Serial.println("[OK] Tensao dentro da faixa operacional do ADC do ESP32 (0.05V a 3.25V).");
  }

  if (picoPicoMv > 100) {
    Serial.println("[ALERTA DE RUIDO] Oscilacao muito alta (> 100 mV entre leituras)!");
    Serial.println(" -> O GPIO 35 nao tem pull-up interno. Se a oscilacao for alta, o fio do GPIO 35 pode");
    Serial.println("    estar solto (pino flutuando) ou falta ligar o GND do modulo de pH no GND do ESP32.");
  } else {
    Serial.println("[OK] Sinal eletrico estavel (baixo ruido).");
  }
}

void imprimirCabecalho() {
  Serial.println("\n================================================================================");
  Serial.println("          DIAGNOSTICO DO SENSOR DE pH (GPIO 35) - PROJETO BIOGLOW");
  Serial.println("================================================================================");
  Serial.printf("Parametros atuais: V_neutro(pH 7) = %.3f V | Sensibilidade = %.2f V/pH\n",
                voltagemNeutroPH, sensibilidadePH);

  diagnosticarSinalEletricoPH();

  Serial.println("\n--- [ETAPA 2] LEITURA CONTINUA (a cada 1 s) ---");
  Serial.println("DICA DE CALIBRACAO: Em pH 7.0 (ou curto entre pino central e malha do BNC),");
  Serial.println("gire o trimpot de offset do modulo ate a coluna 'Tensao' marcar 2.500 V.");
  Serial.println("Comandos no Serial: [r] Re-diagnosticar | [n] Usar tensao atual como Neutro (pH 7.0)\n");
  Serial.println("ADC Bruto | Tensao (V) | Desvio pH7 | pH Calculado | Status (bioglow_boia.ino)");
  Serial.println("--------------------------------------------------------------------------------");
}

void setup() {
  Serial.begin(115200);
  delay(1000);

  analogReadResolution(12);
  analogSetPinAttenuation(PINO_PH, ADC_11db);
  pinMode(PINO_PH, INPUT);

  imprimirCabecalho();
}

unsigned long ultimaLeitura = 0;

void loop() {
  // Comandos via Monitor Serial
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r' || c == 'R') {
      imprimirCabecalho();
    } else if (c == 'n' || c == 'N') {
      float vAtual = analogReadMilliVolts(PINO_PH) / 1000.0f;
      voltagemNeutroPH = vAtual;
      Serial.printf("\n>>> [CALIBRACAO TEMPORARIA] Novo voltagemNeutroPH definido para: %.3f V <<<\n\n",
                    voltagemNeutroPH);
    }
  }

  if (millis() - ultimaLeitura >= 1000) {
    ultimaLeitura = millis();

    // Tira media de 20 amostras para leitura limpa + guarda bruto
    long somaBruto = 0;
    long somaMv    = 0;
    for (int i = 0; i < 20; i++) {
      somaBruto += analogRead(PINO_PH);
      somaMv    += analogReadMilliVolts(PINO_PH);
      delay(2);
    }

    int adcBruto     = somaBruto / 20;
    float voltagemPH = (somaMv / 20.0f) / 1000.0f;
    float desvioNeutro = voltagemPH - voltagemNeutroPH;

    // Mesma logica exata do bioglow_boia.ino (linhas 714-726)
    float valorPH = NAN;
    const char* statusPH = "OK";

    if (voltagemPH < 0.05f || voltagemPH > 3.25f) {
      statusPH = "ERRO_VOLTAGEM_OUT_OF_RANGE";
    } else {
      valorPH = phNeutro - ((voltagemPH - voltagemNeutroPH) / sensibilidadePH);
      if (valorPH < 0.0f)  valorPH = 0.0f;
      if (valorPH > 14.0f) valorPH = 14.0f;
    }

    if (isnan(valorPH)) {
      Serial.printf("   %4d   |  %6.3f V  |  %+6.3f V  |     NULL     | %s\n",
                    adcBruto, voltagemPH, desvioNeutro, statusPH);
    } else {
      Serial.printf("   %4d   |  %6.3f V  |  %+6.3f V  |    %6.2f    | %s\n",
                    adcBruto, voltagemPH, desvioNeutro, valorPH, statusPH);
    }
  }
}
