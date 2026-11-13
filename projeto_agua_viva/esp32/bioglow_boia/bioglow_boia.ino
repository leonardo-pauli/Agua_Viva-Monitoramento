#include <DallasTemperature.h>
#include <OneWire.h>
#include <SD.h>
#include <SPI.h>
#include <WebSocketsServer.h>
#include <WiFi.h>
#include <esp_adc_cal.h>
#include <math.h>
#include <time.h>
#include <vector>

// ============================================================================
// 1. MAPEAMENTO DOS PINOS E CONFIGURAÇÕES DE REDE
// ============================================================================
// Sensores (ADC1 funciona normalmente com o Wi-Fi ativo)
#define PINO_DS18B20 4   // Sensor de Temperatura (GPIO 4 com pull-up do V1738)
const int pinoPH = 35;   // Sensor de pH (ADC1_CH7)
const int pinoTDS = 34;  // Sensor de TDS (ADC1_CH6)
const int pinoTurb = 32; // Sensor de Turbidez (ADC1_CH4)

// Módulo Cartão SD (barramento VSPI)
// CS -> D5 | SCK -> D18 | MISO -> D19 | MOSI -> D23
const int SD_CS = 5;
const int SD_SCK = 18;
const int SD_MISO = 19;
const int SD_MOSI = 23;
const uint32_t SD_FREQ_HZ = 4000000; // 4 MHz

// Rede Local (Access Point) - ws://192.168.4.1:81
const char *ssid = "Bioglow_Boia";
const char *password = "bioglowadmin"; // mínimo 8 caracteres

WebSocketsServer webSocket = WebSocketsServer(81);

// ============================================================================
// 2. PARÂMETROS E ESTADOS DE CALIBRAÇÃO
// ============================================================================
// Identificador e Metadados do Ponto de Coleta
const char *ESTACAO_ID = "ESTACAO_REPRESA_01";
bool STATUS_CALIBRACAO =
    true; // Define se os sensores passaram por calibração recente

// Parâmetros do pH
float voltagemNeutroPH = 2.500;
float phNeutro = 7.0;
float sensibilidadePH = 0.18;

// Parâmetros do TDS / EC
#define VREF_TEORICA 3.3
#define SCOUNT 30
int analogBufferTDS[SCOUNT];
int indexTDS = 0;
bool bufferTDSPreenchido = false;
const float fatorConversaoEC = 2.0; // 1 PPM = ~2.0 uS/cm (NaCl)

// Instâncias e Estado de Temperatura (DS18B20)
OneWire oneWire(PINO_DS18B20);
DallasTemperature sensors(&oneWire);

unsigned long tempoAnteriorTemp = 0;
const unsigned long intervaloTemp = 750;
float temperaturaAtual =
    NAN; // Inicia como inválido (NAN) até primeira leitura válida
bool tempSensorOK = false;

// Temporização não-bloqueante do sistema
const unsigned long INTERVALO_AMOSTRA_TDS_MS = 40;
const unsigned long INTERVALO_CICLO_LEITURA_MS = 500; // Leitura + JSON Serial
const unsigned long INTERVALO_ENVIO_SD_MS = 2000; // Broadcast WS + Gravação SD
const unsigned long INTERVALO_RETENTATIVA_SD_MS = 10000;

unsigned long tempoAmostraTDS = 0;
unsigned long ultimaLeituraMs = 0;
unsigned long ultimoEnvioMs = 0;
unsigned long ultimaTentativaSD = 0;

// Acumuladores independentes para média de gravação no SD / envio a cada 2 s
double somaPH = 0.0;
unsigned long contPH = 0;
double somaTemp = 0.0;
unsigned long contTemp = 0;
double somaEC = 0.0;
unsigned long contEC = 0;
double somaTurb = 0.0;
unsigned long contTurb = 0;

// Buffer do último JSON gerado (enviado imediatamente ao conectar no WebSocket)
char ultimoJson[640] = "";

// ============================================================================
// 3. ESTRUTURAS DO CARTÃO SD E COMANDOS DO APP
// ============================================================================
bool sdOk = false;
bool bootMarcado = false;
const char *ARQUIVO_LOG = "/bioglow_log.csv";

struct Registro {
  long long ts;
  double ph;
  double temp;
  double cond;
  double turb;
};

struct LeitorLog {
  File f;
  int segmento = -1;
  bool passouSync = false;
  std::vector<long> correcoes;
  unsigned long linhas = 0;
};

enum TipoPedido { PEDIDO_NENHUM, PEDIDO_RESUMO, PEDIDO_HISTORICO };

struct Pedido {
  TipoPedido tipo = PEDIDO_NENHUM;
  uint8_t cliente = 0;
  long long desde = 0;
  int maxPontos = 600;
} pedido;

// ============================================================================
// 4. FUNÇÕES AUXILIARES, FILTROS E RELÓGIO
// ============================================================================
int getMedianNum(int bArray[], int iFilterLen) {
  int bTab[iFilterLen];
  for (byte i = 0; i < iFilterLen; i++)
    bTab[i] = bArray[i];
  for (int j = 0; j < iFilterLen - 1; j++) {
    for (int i = 0; i < iFilterLen - j - 1; i++) {
      if (bTab[i] > bTab[i + 1]) {
        int bTemp = bTab[i];
        bTab[i] = bTab[i + 1];
        bTab[i + 1] = bTemp;
      }
    }
  }
  if ((iFilterLen & 1) > 0)
    return bTab[(iFilterLen - 1) / 2];
  else
    return (bTab[iFilterLen / 2] + bTab[iFilterLen / 2 - 1]) / 2;
}

// Leitura de Voltagem Real Compensada pelo eFuse do ESP32 (em Volts)
// Usa mediana de 15 amostras para eliminar picos de ruído do ADC/Wi-Fi
float lerVoltagemCalibrada(int pino) {
  const int N_AMOSTRAS = 15;
  int amostras[N_AMOSTRAS];
  for (int i = 0; i < N_AMOSTRAS; i++) {
    amostras[i] = analogReadMilliVolts(pino);
  }
  int medianaMv = getMedianNum(amostras, N_AMOSTRAS);
  return (float)medianaMv / 1000.0f;
}

// Formata float ou retorna "null" caso seja NAN
void formatarFloatOuNull(float valor, int casas, char *out, size_t tam) {
  if (isnan(valor) || isinf(valor)) {
    snprintf(out, tam, "null");
  } else {
    snprintf(out, tam, "%.*f", casas, valor);
  }
}

// Relógio virtual (sincronizado via WebSocket pelo app)
const int64_t EPOCH_PADRAO_MS = 1788256800000LL; // 01/09/2026 10:00:00
int64_t epochBaseMs = EPOCH_PADRAO_MS;
unsigned long millisBase = 0;
bool relogioSincronizado = false;

int64_t agoraEpochMs() {
  unsigned long m = millis();
  epochBaseMs += (int64_t)(m - millisBase);
  millisBase = m;
  return epochBaseMs;
}

void formatarDataHora(int64_t epochMs, char *data, size_t tamData, char *hora,
                      size_t tamHora) {
  time_t t = (time_t)(epochMs / 1000);
  int ms = (int)(epochMs % 1000);
  struct tm tmv;
  gmtime_r(&t, &tmv);
  snprintf(data, tamData, "%02d/%02d/%04d", tmv.tm_mday, tmv.tm_mon + 1,
           tmv.tm_year + 1900);
  snprintf(hora, tamHora, "%02d:%02d:%02d.%03d", tmv.tm_hour, tmv.tm_min,
           tmv.tm_sec, ms);
}

// ============================================================================
// 5. GERENCIAMENTO DO CARTÃO SD E HISTÓRICO
// ============================================================================
bool iniciarSD() {
  SD.end();
  delay(50);
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  pinMode(SD_MISO, INPUT_PULLUP); // Estabiliza linha DO/MISO na protoboard
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);

  // Tenta iniciar em 4 MHz; se houver ruído nos fios, faz fallback para 1 MHz e 400 kHz
  if (!SD.begin(SD_CS, SPI, SD_FREQ_HZ)) {
    SD.end();
    delay(50);
    if (!SD.begin(SD_CS, SPI, 1000000)) {
      SD.end();
      delay(50);
      if (!SD.begin(SD_CS, SPI, 400000)) {
        return false;
      }
    }
  }

  if (SD.cardType() == CARD_NONE) {
    SD.end();
    return false;
  }

  // Verifica se existe um /bioglow_log.csv antigo do circuito Piezo (5 colunas: rms;pico)
  if (SD.exists(ARQUIVO_LOG)) {
    File fCheck = SD.open(ARQUIVO_LOG, FILE_READ);
    if (fCheck) {
      char cabecalho[96] = {0};
      size_t n = fCheck.readBytesUntil('\n', cabecalho, sizeof(cabecalho) - 1);
      cabecalho[n] = '\0';
      fCheck.close();
      if (strstr(cabecalho, "rms;pico") != NULL) {
        SD.remove("/bioglow_log_piezo_bkp.csv");
        if (!SD.rename(ARQUIVO_LOG, "/bioglow_log_piezo_bkp.csv")) {
          SD.remove(ARQUIVO_LOG);
        }
      }
    }
  }

  if (!SD.exists(ARQUIVO_LOG)) {
    File f = SD.open(ARQUIVO_LOG, FILE_WRITE);
    if (!f)
      return false;
    f.println("epoch;data;hora;ph;temp;cond;turb");
    f.close();
  }

  if (!bootMarcado) {
    File f = SD.open(ARQUIVO_LOG, FILE_APPEND);
    if (!f)
      return false;
    f.println("#B");
    f.close();
    bootMarcado = true;
  }
  return true;
}

void tentarIniciarSD() {
  sdOk = iniciarSD();
  ultimaTentativaSD = millis();
}

void gravarNoSD(int64_t epochMs, const char *data, const char *horaTxt,
                double ph, double temp, double cond, double turb) {
  if (!sdOk)
    return;
  // Evita gravar linha se todos os sensores estiverem desconectados
  if (isnan(ph) && isnan(temp) && isnan(cond) && isnan(turb))
    return;

  File f = SD.open(ARQUIVO_LOG, FILE_APPEND);
  if (!f) {
    sdOk = false;
    return;
  }
  f.printf("%lld;%s;%s;%.2f;%.1f;%.1f;%.1f\n", (long long)(epochMs / 1000),
           data, horaTxt, isnan(ph) ? -999.0 : ph, isnan(temp) ? -999.0 : temp,
           isnan(cond) ? -999.0 : cond, isnan(turb) ? -999.0 : turb);
  f.close();
}

void sincronizarRelogio(int64_t novoEpochMs) {
  int64_t atual = agoraEpochMs();
  int64_t delta = novoEpochMs - atual;

  if (!relogioSincronizado) {
    if (sdOk && bootMarcado) {
      File f = SD.open(ARQUIVO_LOG, FILE_APPEND);
      if (f) {
        f.printf("#S;%lld\n", (long long)(delta / 1000));
        f.close();
      }
    }
    relogioSincronizado = true;
  }

  epochBaseMs = novoEpochMs;
  millisBase = millis();
}

bool lerLinha(File &f, char *buf, size_t tam) {
  if (!f.available())
    return false;
  size_t n = f.readBytesUntil('\n', buf, tam - 1);
  buf[n] = '\0';
  if (n > 0 && buf[n - 1] == '\r')
    buf[n - 1] = '\0';
  return true;
}

void carregarCorrecoes(LeitorLog &lg) {
  lg.correcoes.clear();
  File f = SD.open(ARQUIVO_LOG, FILE_READ);
  if (!f)
    return;
  char linha[128];
  int seg = -1;
  unsigned long n = 0;
  while (lerLinha(f, linha, sizeof(linha))) {
    if (linha[0] == '#') {
      if (linha[1] == 'B') {
        lg.correcoes.push_back(0);
        seg++;
      } else if (linha[1] == 'S' && seg >= 0 && linha[2] == ';') {
        lg.correcoes[seg] = atol(linha + 3);
      }
    }
    if ((++n % 256) == 0)
      yield();
  }
  f.close();
}

bool abrirLeitor(LeitorLog &lg) {
  lg.f = SD.open(ARQUIVO_LOG, FILE_READ);
  lg.segmento = -1;
  lg.passouSync = false;
  lg.linhas = 0;
  return (bool)lg.f;
}

bool proximoRegistro(LeitorLog &lg, Registro &r) {
  char linha[128];
  while (lerLinha(lg.f, linha, sizeof(linha))) {
    if ((++lg.linhas % 256) == 0)
      yield();

    if (linha[0] == '#') {
      if (linha[1] == 'B') {
        lg.segmento++;
        lg.passouSync = false;
      } else if (linha[1] == 'S') {
        lg.passouSync = true;
      }
      continue;
    }
    if (linha[0] < '0' || linha[0] > '9')
      continue;

    char *p = linha;
    char *fim;
    long long ts = strtoll(p, &fim, 10);
    if (fim == p || *fim != ';')
      continue;

    int pontoVirgula = 0;
    while (*p && pontoVirgula < 3) {
      if (*p == ';')
        pontoVirgula++;
      p++;
    }
    if (pontoVirgula < 3)
      continue;

    double ph = strtod(p, &fim);
    if (fim == p || *fim != ';')
      continue;

    p = fim + 1;
    double temp = strtod(p, &fim);
    if (fim == p || *fim != ';')
      continue;

    p = fim + 1;
    double cond = strtod(p, &fim);
    if (fim == p || *fim != ';')
      continue;

    p = fim + 1;
    double turb = strtod(p, &fim);
    if (fim == p)
      continue;

    if (!lg.passouSync && lg.segmento >= 0 &&
        lg.segmento < (int)lg.correcoes.size()) {
      ts += lg.correcoes[lg.segmento];
    }

    r.ts = ts;
    r.ph = (isnan(ph) || ph <= -99.0) ? 0.0 : ph;
    r.temp = (isnan(temp) || temp <= -99.0) ? 0.0 : temp;
    r.cond = (isnan(cond) || cond <= -99.0) ? 0.0 : cond;
    r.turb = (isnan(turb) || turb <= -99.0) ? 0.0 : turb;
    return true;
  }
  return false;
}

unsigned long contarRegistros(LeitorLog &lg, long long desde, long long &inicio,
                              long long &fim) {
  unsigned long total = 0;
  inicio = 0;
  fim = 0;
  if (!abrirLeitor(lg))
    return 0;
  Registro r;
  while (proximoRegistro(lg, r)) {
    if (r.ts < desde)
      continue;
    if (total == 0)
      inicio = r.ts;
    fim = r.ts;
    total++;
  }
  lg.f.close();
  return total;
}

void responderResumo() {
  char msg[160];
  if (!sdOk) {
    snprintf(msg, sizeof(msg),
             "{\"tipo\":\"resumo\",\"sd\":false,\"total\":0,\"inicio\":0,"
             "\"fim\":0}");
  } else {
    LeitorLog lg;
    carregarCorrecoes(lg);
    long long ini, fim;
    unsigned long total = contarRegistros(lg, pedido.desde, ini, fim);
    snprintf(msg, sizeof(msg),
             "{\"tipo\":\"resumo\",\"sd\":true,\"total\":%lu,"
             "\"inicio\":%lld,\"fim\":%lld}",
             total, ini, fim);
  }
  webSocket.sendTXT(pedido.cliente, msg);
}

void responderHistorico() {
  if (!sdOk) {
    webSocket.sendTXT(
        pedido.cliente,
        "{\"tipo\":\"hist_fim\",\"sd\":false,\"total\":0,\"enviados\":0}");
    return;
  }

  LeitorLog lg;
  carregarCorrecoes(lg);
  long long ini, fim;
  unsigned long total = contarRegistros(lg, pedido.desde, ini, fim);

  unsigned long passo = (total + pedido.maxPontos - 1) / pedido.maxPontos;
  if (passo < 1)
    passo = 1;

  const int PONTOS_POR_MSG = 80;
  static char msg[3600];
  size_t len = 0;
  int noMsg = 0;
  unsigned long enviados = 0;

  auto iniciarMsg = [&]() {
    len = snprintf(msg, sizeof(msg), "{\"tipo\":\"hist\",\"p\":[");
    noMsg = 0;
  };
  auto enviarMsg = [&]() {
    if (noMsg == 0)
      return;
    len += snprintf(msg + len, sizeof(msg) - len, "]}");
    webSocket.sendTXT(pedido.cliente, msg, len);
    iniciarMsg();
  };

  iniciarMsg();

  if (total > 0 && abrirLeitor(lg)) {
    Registro r;
    unsigned long noGrupo = 0;
    double grupoPH = 0.0;
    double grupoTemp = 0.0;
    double grupoCond = 0.0;
    double grupoTurb = 0.0;
    long long tsGrupo = 0;

    auto fecharGrupo = [&]() {
      if (noGrupo == 0)
        return;
      double mPH = grupoPH / (double)noGrupo;
      double mTemp = grupoTemp / (double)noGrupo;
      double mCond = grupoCond / (double)noGrupo;
      double mTurb = grupoTurb / (double)noGrupo;
      len +=
          snprintf(msg + len, sizeof(msg) - len, "%s[%lld,%.2f,%.1f,%.1f,%.1f]",
                   noMsg ? "," : "", tsGrupo, mPH, mTemp, mCond, mTurb);
      noMsg++;
      enviados++;
      noGrupo = 0;
      grupoPH = 0.0;
      grupoTemp = 0.0;
      grupoCond = 0.0;
      grupoTurb = 0.0;
      if (noMsg >= PONTOS_POR_MSG)
        enviarMsg();
    };

    while (proximoRegistro(lg, r)) {
      if (r.ts < pedido.desde)
        continue;
      if (noGrupo == 0)
        tsGrupo = r.ts;
      grupoPH += r.ph;
      grupoTemp += r.temp;
      grupoCond += r.cond;
      grupoTurb += r.turb;
      noGrupo++;
      if (noGrupo >= passo)
        fecharGrupo();
    }
    fecharGrupo();
    lg.f.close();
  }
  enviarMsg();

  char fimMsg[128];
  snprintf(fimMsg, sizeof(fimMsg),
           "{\"tipo\":\"hist_fim\",\"sd\":true,\"total\":%lu,\"enviados\":%lu}",
           total, enviados);
  webSocket.sendTXT(pedido.cliente, fimMsg);
}

// ============================================================================
// 6. PROTOCOLO WEBSOCKET E TRATAMENTO DE COMANDOS
// ============================================================================
bool jsonTexto(const char *json, const char *chave, char *out, size_t tam) {
  char padrao[32];
  snprintf(padrao, sizeof(padrao), "\"%s\"", chave);
  const char *p = strstr(json, padrao);
  if (!p)
    return false;
  p = strchr(p + strlen(padrao), ':');
  if (!p)
    return false;
  p++;
  while (*p == ' ')
    p++;
  if (*p != '"')
    return false;
  p++;
  size_t i = 0;
  while (*p && *p != '"' && i < tam - 1)
    out[i++] = *p++;
  out[i] = '\0';
  return true;
}

bool jsonNumero(const char *json, const char *chave, long long &out) {
  char padrao[32];
  snprintf(padrao, sizeof(padrao), "\"%s\"", chave);
  const char *p = strstr(json, padrao);
  if (!p)
    return false;
  p = strchr(p + strlen(padrao), ':');
  if (!p)
    return false;
  p++;
  while (*p == ' ')
    p++;
  char *fim;
  long long v = strtoll(p, &fim, 10);
  if (fim == p)
    return false;
  out = v;
  return true;
}

void tratarComando(uint8_t num, uint8_t *payload, size_t length) {
  char json[256];
  size_t n = length < sizeof(json) - 1 ? length : sizeof(json) - 1;
  memcpy(json, payload, n);
  json[n] = '\0';

  char cmd[24];
  if (!jsonTexto(json, "cmd", cmd, sizeof(cmd)))
    return;

  long long v;
  if (strcmp(cmd, "sync") == 0) {
    if (jsonNumero(json, "epoch_ms", v) && v > 1600000000000LL) {
      sincronizarRelogio((int64_t)v);
    }
  } else if (strcmp(cmd, "resumo") == 0 || strcmp(cmd, "historico") == 0) {
    pedido.tipo = (cmd[0] == 'r') ? PEDIDO_RESUMO : PEDIDO_HISTORICO;
    pedido.cliente = num;
    pedido.desde = jsonNumero(json, "desde", v) ? v : 0;
    pedido.maxPontos = jsonNumero(json, "max", v) ? (int)v : 600;
    if (pedido.maxPontos < 10)
      pedido.maxPontos = 10;
    if (pedido.maxPontos > 2000)
      pedido.maxPontos = 2000;
  }
}

void processarPedido() {
  if (pedido.tipo == PEDIDO_NENHUM)
    return;
  TipoPedido tipo = pedido.tipo;

  if (tipo == PEDIDO_RESUMO)
    responderResumo();
  else
    responderHistorico();

  if (pedido.tipo == tipo)
    pedido.tipo = PEDIDO_NENHUM;

  unsigned long agora = millis();
  ultimaLeituraMs = agora;
  ultimoEnvioMs = agora;
}

void webSocketEvent(uint8_t num, WStype_t type, uint8_t *payload,
                    size_t length) {
  switch (type) {
  case WStype_CONNECTED:
    if (ultimoJson[0] != '\0') {
      webSocket.sendTXT(num, ultimoJson);
    }
    break;

  case WStype_TEXT:
    tratarComando(num, payload, length);
    break;

  default:
    break;
  }
}

// ============================================================================
// 7. SETUP
// ============================================================================
void setup() {
  Serial.begin(115200);
  millisBase = millis();

  // Inicializa sensor de temperatura (DS18B20 no GPIO 4)
  sensors.begin();
  sensors.setWaitForConversion(false);
  sensors.requestTemperatures();

  // Configuração do ADC do ESP32
  analogReadResolution(12);
  analogSetPinAttenuation(pinoPH, ADC_11db);
  analogSetPinAttenuation(pinoTDS, ADC_11db);
  analogSetPinAttenuation(pinoTurb, ADC_11db);

  pinMode(pinoPH, INPUT);
  pinMode(pinoTDS, INPUT);
  pinMode(pinoTurb, INPUT);

  // RESOLUÇÃO DO BUFFER TDS: Pré-carrega o buffer com 30 leituras reais (em mV
  // calibrados)
  for (int i = 0; i < SCOUNT; i++) {
    analogBufferTDS[i] = analogReadMilliVolts(pinoTDS);
    delay(10);
  }
  bufferTDSPreenchido = true;

  // Inicializa Cartão SD
  pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  tentarIniciarSD();

  // Inicializa Access Point e Servidor WebSocket
  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);
  if (!WiFi.softAP(ssid, password)) {
    delay(2000);
    ESP.restart();
  }

  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  webSocket.enableHeartbeat(15000, 3000, 2);

  unsigned long agora = millis();
  tempoAnteriorTemp = agora;
  tempoAmostraTDS = agora;
  ultimaLeituraMs = agora;
  ultimoEnvioMs = agora;

  Serial.println("{\"status\":\"SISTEMA_INICIALIZADO\",\"estacao\":\"" +
                 String(ESTACAO_ID) + "\"}");
}

// ============================================================================
// 8. LOOP PRINCIPAL
// ============================================================================
void loop() {
  webSocket.loop();
  processarPedido();

  unsigned long tempoAtual = millis();

  // --------------------------------------------------------------------------
  // 1. TEMPERATURA (DS18B20) COM GESTÃO DE ERRO (a cada 750 ms)
  // --------------------------------------------------------------------------
  if (tempoAtual - tempoAnteriorTemp >= intervaloTemp) {
    float leituraTemp = sensors.getTempCByIndex(0);

    // Tratamento de Erro Explícito: Desconexão ou falha de leitura (DS18B20
    // gera -127°C ou 85°C se falhar)
    if (leituraTemp <= -55.0f || leituraTemp == 85.0f || leituraTemp > 125.0f) {
      temperaturaAtual = NAN;
      tempSensorOK = false;
    } else {
      temperaturaAtual = leituraTemp;
      tempSensorOK = true;
    }

    sensors.requestTemperatures();
    tempoAnteriorTemp = tempoAtual;
  }

  // --------------------------------------------------------------------------
  // 2. AMOSTRAGEM CONTÍNUA DO BUFFER DE TDS (a cada 40 ms)
  // --------------------------------------------------------------------------
  if (tempoAtual - tempoAmostraTDS >= INTERVALO_AMOSTRA_TDS_MS) {
    tempoAmostraTDS = tempoAtual;
    analogBufferTDS[indexTDS] = analogReadMilliVolts(pinoTDS);
    indexTDS = (indexTDS + 1) % SCOUNT;
  }

  // --------------------------------------------------------------------------
  // 3. LEITURA DOS SENSORES E EMBALAGEM EM JSON (a cada 500 ms)
  // --------------------------------------------------------------------------
  if (tempoAtual - ultimaLeituraMs >= INTERVALO_CICLO_LEITURA_MS) {
    ultimaLeituraMs = tempoAtual;

    // --- Leitura de pH com validação de faixa de voltagem ---
    float voltagemPH = lerVoltagemCalibrada(pinoPH);
    float valorPH = NAN;
    const char *statusPH = "OK";

    if (voltagemPH < 0.02f) {
      statusPH = "ERRO_VOLTAGEM_OUT_OF_RANGE";
    } else {
      if (voltagemPH > 3.25f) {
        statusPH = "ALERTA_TENSAO_ALTA_CALIBRAR";
      }
      valorPH = phNeutro - ((voltagemPH - voltagemNeutroPH) / sensibilidadePH);
      if (valorPH < 0.0f)
        valorPH = 0.0f;
      if (valorPH > 14.0f)
        valorPH = 14.0f;
    }

    // --- Leitura de TDS / EC com mediana e compensação térmica ---
    float valorTDS = NAN;
    float valorEC_estimado = NAN;
    const char *statusTDS = "OK";

    if (bufferTDSPreenchido) {
      int medianaMvTDS = getMedianNum(analogBufferTDS, SCOUNT);
      float voltagemTDS = (float)medianaMvTDS / 1000.0f;

      // Se o sensor de temperatura falhar, usa base de 25°C mas alerta a App
      float tempCompensacao = tempSensorOK ? temperaturaAtual : 25.0f;
      if (!tempSensorOK)
        statusTDS = "ALERTA_TEMP_DEFAULT_25C";

      float coeficienteTemp = 1.0f + 0.02f * (tempCompensacao - 25.0f);
      float voltagemCompensada = voltagemTDS / coeficienteTemp;

      valorTDS = (133.42f * powf(voltagemCompensada, 3) -
                  255.86f * powf(voltagemCompensada, 2) +
                  857.39f * voltagemCompensada) *
                 0.5f;
      if (valorTDS < 0.0f)
        valorTDS = 0.0f;
      valorEC_estimado = valorTDS * fatorConversaoEC;
    } else {
      statusTDS = "AGUARDANDO_BUFFER";
    }

    // --- Leitura de Turbidez com notificação de curva ---
    float voltagemTurb = lerVoltagemCalibrada(pinoTurb);
    float ntu = NAN;
    const char *statusTurb = "OK";

    if (voltagemTurb < 0.05f) {
      statusTurb = "ERRO_DESCONECTADO_OU_CURTO";
    } else if (voltagemTurb >= 2.50f) {
      ntu = 0.0f;
      statusTurb = "AGUA_LIMPIDA_LIMITE_INFERIOR";
    } else {
      ntu = -1120.4f * sq(voltagemTurb) + 5742.3f * voltagemTurb - 4353.8f;
      if (ntu < 0.0f)
        ntu = 0.0f;
    }

    // Acumula leituras válidas para a gravação no SD
    if (!isnan(valorPH)) {
      somaPH += valorPH;
      contPH++;
    }
    if (tempSensorOK) {
      somaTemp += temperaturaAtual;
      contTemp++;
    }
    if (!isnan(valorEC_estimado)) {
      somaEC += valorEC_estimado;
      contEC++;
    }
    if (!isnan(ntu)) {
      somaTurb += ntu;
      contTurb++;
    }

    // --- Embalagem dos dados em JSON (Monitor Serial / Flutter WebSocket / SD)
    // ---
    int64_t agora = agoraEpochMs();
    char dataTexto[16], horaTexto[16];
    formatarDataHora(agora, dataTexto, sizeof(dataTexto), horaTexto,
                     sizeof(horaTexto));

    char strTemp[16], strPH[16], strTDS[16], strEC[16], strNTU[16];
    formatarFloatOuNull(tempSensorOK ? temperaturaAtual : NAN, 2, strTemp,
                        sizeof(strTemp));
    formatarFloatOuNull(valorPH, 2, strPH, sizeof(strPH));
    formatarFloatOuNull(valorTDS, 0, strTDS, sizeof(strTDS));
    formatarFloatOuNull(valorEC_estimado, 0, strEC, sizeof(strEC));
    formatarFloatOuNull(ntu, 0, strNTU, sizeof(strNTU));

    snprintf(ultimoJson, sizeof(ultimoJson),
             "{"
             "\"tipo\":\"leitura\","
             "\"estacao\":\"%s\","
             "\"calibrado\":%s,"
             "\"sd\":%s,"
             "\"ts\":%lld,"
             "\"data\":\"%s\","
             "\"hora\":\"%s\","
             "\"temp_C\":%s,"
             "\"temp_status\":\"%s\","
             "\"ph_val\":%s,"
             "\"ph_volts\":%.3f,"
             "\"ph_status\":\"%s\","
             "\"tds_ppm\":%s,"
             "\"ec_us_cm\":%s,"
             "\"tds_status\":\"%s\","
             "\"turb_ntu\":%s,"
             "\"turb_volts\":%.3f,"
             "\"turb_status\":\"%s\","
             "\"ph\":%s,"
             "\"temp\":%s,"
             "\"cond\":%s,"
             "\"turb\":%s"
             "}",
             ESTACAO_ID, STATUS_CALIBRACAO ? "true" : "false",
             sdOk ? "true" : "false",
             (long long)(agora / 1000), dataTexto, horaTexto, strTemp,
             tempSensorOK ? "OK" : "ERRO_DESCONECTADO", strPH, voltagemPH,
             statusPH, strTDS, strEC, statusTDS, strNTU, voltagemTurb,
             statusTurb, strPH, strTemp, strEC, strNTU);

    // Imprime o JSON no Monitor Serial
    Serial.println(ultimoJson);
  }

  // --------------------------------------------------------------------------
  // 4. ENVIO WEBSOCKET + GRAVAÇÃO SD (a cada 2000 ms)
  // --------------------------------------------------------------------------
  if (tempoAtual - ultimoEnvioMs >= INTERVALO_ENVIO_SD_MS) {
    ultimoEnvioMs = tempoAtual;

    if (ultimoJson[0] != '\0') {
      webSocket.broadcastTXT(ultimoJson);
    }

    double mPH = (contPH > 0) ? (somaPH / (double)contPH) : NAN;
    double mTemp = (contTemp > 0) ? (somaTemp / (double)contTemp) : NAN;
    double mEC = (contEC > 0) ? (somaEC / (double)contEC) : NAN;
    double mTurb = (contTurb > 0) ? (somaTurb / (double)contTurb) : NAN;

    int64_t agora = agoraEpochMs();
    char dataTexto[16], horaTexto[16];
    formatarDataHora(agora, dataTexto, sizeof(dataTexto), horaTexto,
                     sizeof(horaTexto));
    gravarNoSD(agora, dataTexto, horaTexto, mPH, mTemp, mEC, mTurb);

    somaPH = 0.0;
    contPH = 0;
    somaTemp = 0.0;
    contTemp = 0;
    somaEC = 0.0;
    contEC = 0;
    somaTurb = 0.0;
    contTurb = 0;
  }

  // --------------------------------------------------------------------------
  // 5. RETENTATIVA AUTOMÁTICA DO CARTÃO SD (a cada 10 s se ausente)
  // --------------------------------------------------------------------------
  if (!sdOk && millis() - ultimaTentativaSD >= INTERVALO_RETENTATIVA_SD_MS) {
    tentarIniciarSD();
  }
}
