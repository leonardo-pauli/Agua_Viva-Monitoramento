#include <Arduino.h>
#include <SPI.h>
#include <SD.h>

// ============================================================================
// MINI CÓDIGO DE DIAGNÓSTICO DO CARTÃO SD - PROJETO BIOGLOW (ESP32)
// ============================================================================
// Pinos do barramento VSPI usados no bioglow_boia.ino:
const int SD_CS   = 5;
const int SD_SCK  = 18;
const int SD_MISO = 19;
const int SD_MOSI = 23;

const char* ARQUIVO_TESTE = "/teste_sd_bioglow.txt";
const char* ARQUIVO_LOG   = "/bioglow_log.csv";

void testarPinosEletricos() {
  Serial.println("\n--- [ETAPA 1] DIAGNOSTICO ELETRICO DOS PINOS SPI ---");

  // Testa se MISO (GPIO 19) esta preso em GND ou respondendo ao pull-up
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH); // Desativa o chip select do SD

  pinMode(SD_MISO, INPUT_PULLDOWN);
  delay(10);
  int misoDown = digitalRead(SD_MISO);

  pinMode(SD_MISO, INPUT_PULLUP);
  delay(10);
  int misoUp = digitalRead(SD_MISO);

  Serial.printf("GPIO 19 (MISO) com PULLDOWN: %s | com PULLUP: %s\n",
                misoDown ? "HIGH (3.3V)" : "LOW (0V)",
                misoUp   ? "HIGH (3.3V)" : "LOW (0V)");

  if (misoUp == LOW) {
    Serial.println("[ALERTA CRITICO] O pino MISO (GPIO 19) esta preso em LOW (0V) mesmo com PULLUP!");
    Serial.println(" -> Possivel curto com GND, fio ligado errado, ou modulo SD sem alimentacao (VCC desligado) segurando a linha.");
  } else {
    Serial.println("[OK] Linha MISO responde ao nivel ALTO (nao esta em curto com GND).");
  }

  // Verifica se CS (GPIO 5) consegue subir para HIGH
  pinMode(SD_CS, INPUT_PULLUP);
  delay(5);
  int csVal = digitalRead(SD_CS);
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  Serial.printf("GPIO 5  (CS)   em repouso: %s\n", csVal ? "HIGH (OK)" : "LOW (ALERTA: preso em 0V!)");
}

bool testarFrequenciaSPI(uint32_t freqHz, const char* rotulo) {
  SD.end();
  SPI.end();
  delay(50);

  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  pinMode(SD_MISO, INPUT_PULLUP); // Ajuda modulos SD sem pull-up forte no DO/MISO

  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  delay(20);

  Serial.printf(" -> Testando SD.begin() em %s (%lu Hz)... ", rotulo, (unsigned long)freqHz);
  bool ok = SD.begin(SD_CS, SPI, freqHz);
  if (!ok) {
    Serial.println("FALHOU!");
    return false;
  }

  uint8_t cardType = SD.cardType();
  if (cardType == CARD_NONE) {
    Serial.println("FALHOU (CARD_NONE - nenhum cartao detectado)!");
    SD.end();
    return false;
  }

  Serial.println("SUCESSO!");
  return true;
}

void inspecionarArquivoLog() {
  Serial.println("\n--- [ETAPA 5] INSPECAO DO ARQUIVO /bioglow_log.csv ---");
  if (!SD.exists(ARQUIVO_LOG)) {
    Serial.println("O arquivo /bioglow_log.csv ainda NAO existe no cartao.");
    return;
  }

  File f = SD.open(ARQUIVO_LOG, FILE_READ);
  if (!f) {
    Serial.println("[ERRO] Nao foi possivel abrir /bioglow_log.csv para leitura!");
    return;
  }

  size_t tamanho = f.size();
  Serial.printf("Arquivo encontrado! Tamanho: %u bytes\n", (unsigned int)tamanho);
  Serial.println("Primeiras 5 linhas do arquivo:");
  Serial.println("--------------------------------------------------");

  int linhaNum = 0;
  String primeiraLinha = "";
  while (f.available() && linhaNum < 5) {
    String linha = f.readStringUntil('\n');
    linha.trim();
    if (linhaNum == 0) primeiraLinha = linha;
    Serial.printf("  [%d] %s\n", linhaNum + 1, linha.c_str());
    linhaNum++;
  }
  Serial.println("--------------------------------------------------");

  if (primeiraLinha.indexOf("rms;pico") >= 0) {
    Serial.println("[ATENCAO - CAUSA DE SOFTWARE DETECTADA!]");
    Serial.println(" -> O arquivo /bioglow_log.csv tem o cabecalho ANTIGO (epoch;data;hora;rms;pico - 5 colunas)!");
    Serial.println(" -> O codigo novo (bioglow_boia.ino) exige 7 colunas (epoch;data;hora;ph;temp;cond;turb)");
    Serial.println("    e ignora todas as linhas antigas de 5 colunas!");
    Serial.println(" -> Digite 'c' no Monitor Serial para renomear/limpar o log antigo.");
  }
  f.close();
}

void executarDiagnosticoCompleto() {
  Serial.println("\n============================================================");
  Serial.println("     INICIANDO DIAGNOSTICO COMPLETO DO SD (BIOGLOW)");
  Serial.println("============================================================");
  Serial.printf("Pinos configurados: CS=%d | SCK=%d | MISO=%d | MOSI=%d\n",
                SD_CS, SD_SCK, SD_MISO, SD_MOSI);

  // 1. Teste eletrico dos pinos
  testarPinosEletricos();

  // 2. Teste de inicializacao em diferentes frequencias SPI
  Serial.println("\n--- [ETAPA 2] TESTE DE BARRAMENTO SPI E VELOCIDADES ---");
  bool ok400k = testarFrequenciaSPI(400000,  "400 kHz (Velocidade Segura)");
  bool ok1M   = testarFrequenciaSPI(1000000, "1 MHz   (Velocidade Baixa)");
  bool ok4M   = testarFrequenciaSPI(4000000, "4 MHz   (Velocidade do Projeto)");

  if (!ok400k && !ok1M && !ok4M) {
    Serial.println("\n[RESULTADO: FALHA TOTAL DE COMUNICACAO SPI COM O SD]");
    Serial.println("Verifique os seguintes itens no seu novo circuito:");
    Serial.println("  1. ALIMENTACAO (VCC do modulo SD):");
    Serial.println("     - Se for o modulo SD tradicional (azul com regulador AMS1117), o VCC DEVE ir no 5V (VIN), NAO no 3V3!");
    Serial.println("     - Se estiver no 3V3, o regulador derruba a tensao para ~2.2V e o cartao para de funcionar.");
    Serial.println("  2. INVERSAO MISO / MOSI:");
    Serial.println("     - Confira se MISO esta no GPIO 19 e MOSI no GPIO 23 (no SPI nao se cruza fios, e MISO->19 e MOSI->23).");
    Serial.println("  3. CONFLITO COM O NOVO SENSOR DS18B20 (GPIO 4):");
    Serial.println("     - O GPIO 4 fica colado no GPIO 5 (SD_CS). Verifique se o resistor de pull-up do DS18B20");
    Serial.println("       nao esta encostando no GPIO 5 ou ligado no pino errado da protoboard.");
    Serial.println("  4. QUEDA DE TENSAO / GND:");
    Serial.println("     - Desconecte temporariamente o VCC dos sensores de pH, Turbidez e TDS e digite 'r' para re-testar.");
    return;
  }

  if ((ok400k || ok1M) && !ok4M) {
    Serial.println("\n[ALERTA DE HARDWARE] O cartao funciona em baixa velocidade, mas FALHA em 4 MHz!");
    Serial.println(" -> Causa: Ruido nos jumpers da protoboard, cabos longos ou queda de tensao (3.3V/5V).");
    Serial.println(" -> Mantendo conexao em 1 MHz para continuar os testes...");
    testarFrequenciaSPI(1000000, "1 MHz");
  }

  // 3. Informacoes do Cartao
  Serial.println("\n--- [ETAPA 3] INFORMACOES DO CARTAO SD ---");
  uint8_t cardType = SD.cardType();
  Serial.print("Tipo do Cartao: ");
  if (cardType == CARD_MMC)       Serial.println("MMC");
  else if (cardType == CARD_SD)   Serial.println("SDSC (Ate 2 GB)");
  else if (cardType == CARD_SDHC) Serial.println("SDHC / SDXC (> 2 GB)");
  else                            Serial.println("DESCONHECIDO");

  uint64_t cardSizeMB = SD.cardSize() / (1024ULL * 1024ULL);
  uint64_t totalMB    = SD.totalBytes() / (1024ULL * 1024ULL);
  uint64_t usedMB     = SD.usedBytes() / (1024ULL * 1024ULL);
  Serial.printf("Tamanho Fisico: %llu MB | Volume FAT: %llu MB | Usado: %llu MB\n",
                cardSizeMB, totalMB, usedMB);

  // 4. Teste de Escrita e Leitura
  Serial.println("\n--- [ETAPA 4] TESTE DE ESCRITA E LEITURA DE ARQUIVO ---");
  File fw = SD.open(ARQUIVO_TESTE, FILE_WRITE);
  if (!fw) {
    Serial.println("[ERRO] O cartao iniciou, mas FALHOU ao criar arquivo para escrita!");
    Serial.println(" -> Possivel cartao corrompido (formate em FAT32) ou queda de tensao no pico de escrita.");
  } else {
    String msgTeste = "Teste Bioglow SD OK - millis=" + String(millis());
    fw.println(msgTeste);
    fw.close();
    Serial.println("[OK] Escrita concluida com sucesso.");

    File fr = SD.open(ARQUIVO_TESTE, FILE_READ);
    if (!fr) {
      Serial.println("[ERRO] Falhou ao reabrir o arquivo de teste para leitura!");
    } else {
      String lido = fr.readStringUntil('\n');
      lido.trim();
      fr.close();
      Serial.printf("[OK] Conteudo lido do SD: \"%s\"\n", lido.c_str());
    }
  }

  // 5. Inspeciona o arquivo do projeto (/bioglow_log.csv)
  inspecionarArquivoLog();

  Serial.println("\n============================================================");
  Serial.println("Comandos no Monitor Serial: [r] Re-testar | [c] Fazer backup/limpar log antigo");
  Serial.println("============================================================\n");
}

void setup() {
  Serial.begin(115200);
  delay(1000);
  executarDiagnosticoCompleto();
}

void loop() {
  if (Serial.available()) {
    char c = Serial.read();
    if (c == 'r' || c == 'R') {
      executarDiagnosticoCompleto();
    } else if (c == 'c' || c == 'C') {
      if (SD.exists(ARQUIVO_LOG)) {
        SD.remove("/bioglow_log_antigo.csv");
        if (SD.rename(ARQUIVO_LOG, "/bioglow_log_antigo.csv")) {
          Serial.println("[OK] /bioglow_log.csv renomeado para /bioglow_log_antigo.csv!");
        } else {
          SD.remove(ARQUIVO_LOG);
          Serial.println("[OK] /bioglow_log.csv removido!");
        }
      } else {
        Serial.println("Arquivo /bioglow_log.csv nao existe.");
      }
    }
  }
}
