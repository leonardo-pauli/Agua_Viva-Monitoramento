#include <WiFi.h>
#include <WebSocketsServer.h>
#include <math.h>
#include <SPI.h>
#include <SD.h>
#include <time.h>
#include <vector>

// ============================================================
// CONFIGURAÇÕES DA REDE LOCAL (Access Point)
// ============================================================
// O celular deve se conectar nesta rede. O app acessa:
//   ws://192.168.4.1:81

const char* ssid     = "Bioglow_Boia";
const char* password = "bioglowadmin";   // mínimo 8 caracteres

// ============================================================
// CONFIGURAÇÕES DE PINOS
// ============================================================
// GPIO 35 = ADC1_CH7 (somente entrada).
// IMPORTANTE: pinos do ADC2 (ex.: GPIO 27, que era usado antes)
// NÃO funcionam com o Wi-Fi ligado. Por isso o ADC1 é obrigatório.

const int PINO_PIEZO = 35;   // Sensor de vibração / piezo

// Módulo cartão SD (barramento VSPI)
//   CS   -> D5    SCK -> D18    MOSI -> D23    MISO -> D19
//   VCC  -> 3V3   GND -> GND
const int SD_CS   = 5;
const int SD_SCK  = 18;
const int SD_MISO = 19;
const int SD_MOSI = 23;
const uint32_t SD_FREQ_HZ = 4000000;   // 4 MHz: estável na maioria dos módulos

// ============================================================
// WEBSOCKET
// ============================================================

WebSocketsServer webSocket = WebSocketsServer(81);

// ============================================================
// CONFIGURAÇÕES DE AMOSTRAGEM
// ============================================================

// Amostragem em taxa fixa
const unsigned long PERIODO_AMOSTRA_US = 500;   // 500 us = 2000 Hz

// Janela para cálculo de RMS e Pico (Serial)
const unsigned long INTERVALO_JANELA_MS = 200;

// Envio para o app / gravação no SD a cada N janelas (10 x 200 ms = 2 s)
const int JANELAS_POR_ENVIO = 10;

// ADC 12 bits: 0 a 4095
const int ADC_MINIMO = 0;
const int ADC_MAXIMO = 4095;

// ------------------------------------------------------------
// Acumuladores da janela de 200 ms
// ------------------------------------------------------------
unsigned long ultimoMicrosAmostra = 0;
unsigned long inicioJanela        = 0;

double        somaQuadradosJanela = 0.0;
unsigned long amostrasJanela      = 0;
int           picoJanela          = 0;

// ------------------------------------------------------------
// Acumuladores do bloco de envio (2 s)
// RMS e Pico enviados ao app representam os 2 s inteiros,
// e não apenas os últimos 200 ms.
// ------------------------------------------------------------
double        somaQuadradosEnvio = 0.0;
unsigned long amostrasEnvio      = 0;
int           picoEnvio          = 0;
int           janelasNoEnvio     = 0;

// Últimos resultados
double ultimoRMS  = 0.0;
int    ultimoPico = 0;

// Último JSON enviado (para mandar imediatamente a quem conectar)
char ultimoJson[192] = "";

// ============================================================
// CARTÃO SD
// ============================================================
// Formato do arquivo (CSV separado por ';'):
//   epoch;data;hora;rms;pico
//   1788256802;01/09/2026;10:00:02.000;123.45;678
//
// Linhas especiais (marcadores):
//   #B          -> o ESP32 foi ligado (início de um novo "boot")
//   #S;<seg>    -> 1ª sincronização de relógio com o app neste boot.
//                  <seg> é a correção (em segundos) que deve ser somada
//                  às linhas gravadas ANTES dessa sincronização, no mesmo
//                  boot. Assim os dados gravados com o relógio simulado
//                  ganham a data/hora real quando o app conecta.

bool sdOk        = false;
bool bootMarcado = false;            // já escreveu "#B" neste boot?
unsigned long ultimaTentativaSD = 0;
const unsigned long INTERVALO_RETENTATIVA_SD_MS = 10000;
const char* ARQUIVO_LOG = "/bioglow_log.csv";

// Structs de leitura do histórico do SD.
// IMPORTANTE: precisam ficar ANTES de qualquer função, pois o Arduino IDE
// gera protótipos automáticos no topo do sketch que usam esses tipos.
struct Registro {
  long long ts;
  double    rms;
  int       pico;
};

struct LeitorLog {
  File f;
  int  segmento    = -1;     // índice do boot atual dentro do arquivo
  bool passouSync  = false;  // já passou do "#S" neste segmento?
  std::vector<long> correcoes;  // correção (s) por segmento
  unsigned long linhas = 0;
};

// ============================================================
// RELÓGIO
// ============================================================
// O ESP32 não tem RTC. Ao ligar, o relógio começa em 01/09/2026 10:00:00
// (como antes) e avança com millis(). Quando o app conecta, ele envia a
// hora do celular e o relógio passa a ser o real.
// "epoch" aqui = segundos desde 1970 da HORA LOCAL (tratada como UTC).

const int64_t EPOCH_PADRAO_MS = 1788256800000LL;  // 01/09/2026 10:00:00

int64_t       epochBaseMs = EPOCH_PADRAO_MS;
unsigned long millisBase  = 0;
bool          relogioSincronizado = false;

int64_t agoraEpochMs() {
  // Rebase a cada chamada: evita problema do overflow do millis() (~49 dias)
  unsigned long m = millis();
  epochBaseMs += (int64_t)(m - millisBase);
  millisBase = m;
  return epochBaseMs;
}

void formatarDataHora(int64_t epochMs,
                      char* data, size_t tamData,
                      char* hora, size_t tamHora) {
  time_t t = (time_t)(epochMs / 1000);
  int ms   = (int)(epochMs % 1000);
  struct tm tmv;
  gmtime_r(&t, &tmv);
  snprintf(data, tamData, "%02d/%02d/%04d",
           tmv.tm_mday, tmv.tm_mon + 1, tmv.tm_year + 1900);
  snprintf(hora, tamHora, "%02d:%02d:%02d.%03d",
           tmv.tm_hour, tmv.tm_min, tmv.tm_sec, ms);
}

// ============================================================
// FUNÇÕES DO CARTÃO SD
// ============================================================

bool iniciarSD() {
  SD.end();
  delay(50);
  // Reinicia o SPI caso o SD.end() tenha liberado o barramento
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  // Teste com 1 MHz (1000000) se os fios forem longos
  if (!SD.begin(SD_CS, SPI, 1000000)) {
    return false;
  }
  if (SD.cardType() == CARD_NONE) {
    SD.end();
    return false;
  }
  if (!SD.begin(SD_CS, SPI, SD_FREQ_HZ)) {
    return false;
  }

  if (!SD.exists(ARQUIVO_LOG)) {
    File f = SD.open(ARQUIVO_LOG, FILE_WRITE);
    if (!f) return false;
    f.println("epoch;data;hora;rms;pico");
    f.close();
  }

  // Marca o início deste boot (somente uma vez por boot)
  if (!bootMarcado) {
    File f = SD.open(ARQUIVO_LOG, FILE_APPEND);
    if (!f) return false;
    f.println("#B");
    f.close();
    bootMarcado = true;
  }
  return true;
}

void tentarIniciarSD() {
  sdOk = iniciarSD();
  ultimaTentativaSD = millis();
  if (sdOk) {
    uint64_t mb = SD.cardSize() / (1024ULL * 1024ULL);
    Serial.printf("Cartao SD OK (%llu MB). Gravando em %s\n", mb, ARQUIVO_LOG);
  } else {
    Serial.println("AVISO: Falha ao iniciar SD ou cartao ausente! "
                   "Nova tentativa em 10 s.");
  }
}

void gravarNoSD(int64_t epochMs, const char* data, const char* horaTxt,
                double rms, int pico) {
  if (!sdOk) return;

  File f = SD.open(ARQUIVO_LOG, FILE_APPEND);
  if (!f) {
    Serial.println("AVISO: falha ao abrir arquivo no SD (cartao removido?).");
    sdOk = false;   // força nova tentativa de inicialização
    return;
  }
  f.printf("%lld;%s;%s;%.2f;%d\n",
           (long long)(epochMs / 1000), data, horaTxt, rms, pico);
  f.close();
}

void sincronizarRelogio(int64_t novoEpochMs) {
  int64_t atual = agoraEpochMs();
  int64_t delta = novoEpochMs - atual;

  if (!relogioSincronizado) {
    // Grava a correção para as linhas deste boot feitas antes da sincronização
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
  millisBase  = millis();

  char d[16], h[16];
  formatarDataHora(novoEpochMs, d, sizeof(d), h, sizeof(h));
  Serial.printf("Relogio sincronizado com o app: %s %s (ajuste de %lld s)\n",
                d, h, (long long)(delta / 1000));
}

// ------------------------------------------------------------
// Leitura do histórico do SD
// ------------------------------------------------------------
// (structs Registro e LeitorLog definidas no topo do arquivo)

// Lê a próxima linha do arquivo (sem o '\n'). Retorna false no fim.
bool lerLinha(File& f, char* buf, size_t tam) {
  if (!f.available()) return false;
  size_t n = f.readBytesUntil('\n', buf, tam - 1);
  buf[n] = '\0';
  if (n > 0 && buf[n - 1] == '\r') buf[n - 1] = '\0';
  return true;
}

// Passo 1: descobre a correção de relógio de cada boot ("#B" ... "#S;x").
void carregarCorrecoes(LeitorLog& lg) {
  lg.correcoes.clear();
  File f = SD.open(ARQUIVO_LOG, FILE_READ);
  if (!f) return;
  char linha[96];
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
    if ((++n % 256) == 0) yield();
  }
  f.close();
}

bool abrirLeitor(LeitorLog& lg) {
  lg.f = SD.open(ARQUIVO_LOG, FILE_READ);
  lg.segmento   = -1;
  lg.passouSync = false;
  lg.linhas     = 0;
  return (bool)lg.f;
}

// Passos 2 e 3: devolve o próximo registro válido, já com a hora corrigida.
bool proximoRegistro(LeitorLog& lg, Registro& r) {
  char linha[96];
  while (lerLinha(lg.f, linha, sizeof(linha))) {
    if ((++lg.linhas % 256) == 0) yield();

    if (linha[0] == '#') {
      if (linha[1] == 'B') { lg.segmento++; lg.passouSync = false; }
      else if (linha[1] == 'S') { lg.passouSync = true; }
      continue;
    }
    if (linha[0] < '0' || linha[0] > '9') continue;   // cabeçalho/lixo

    char* p = linha;
    char* fim;
    long long ts = strtoll(p, &fim, 10);
    if (fim == p || *fim != ';') continue;

    // pula data e hora -> 3º ';' a partir do início
    int pontoVirgula = 0;
    while (*p && pontoVirgula < 3) { if (*p == ';') pontoVirgula++; p++; }
    if (pontoVirgula < 3) continue;

    double rms = strtod(p, &fim);
    if (fim == p || *fim != ';') continue;
    int pico = atoi(fim + 1);

    if (!lg.passouSync && lg.segmento >= 0 &&
        lg.segmento < (int)lg.correcoes.size()) {
      ts += lg.correcoes[lg.segmento];
    }

    r.ts = ts; r.rms = rms; r.pico = pico;
    return true;
  }
  return false;
}

// ============================================================
// PEDIDOS DO APP (processados no loop, fora do callback)
// ============================================================

enum TipoPedido { PEDIDO_NENHUM, PEDIDO_RESUMO, PEDIDO_HISTORICO };

struct Pedido {
  TipoPedido tipo = PEDIDO_NENHUM;
  uint8_t    cliente = 0;
  long long  desde = 0;
  int        maxPontos = 600;
} pedido;

// Extrai um texto: "chave":"valor"
bool jsonTexto(const char* json, const char* chave, char* out, size_t tam) {
  char padrao[32];
  snprintf(padrao, sizeof(padrao), "\"%s\"", chave);
  const char* p = strstr(json, padrao);
  if (!p) return false;
  p = strchr(p + strlen(padrao), ':');
  if (!p) return false;
  p++;
  while (*p == ' ') p++;
  if (*p != '"') return false;
  p++;
  size_t i = 0;
  while (*p && *p != '"' && i < tam - 1) out[i++] = *p++;
  out[i] = '\0';
  return true;
}

// Extrai um número inteiro: "chave":123
bool jsonNumero(const char* json, const char* chave, long long& out) {
  char padrao[32];
  snprintf(padrao, sizeof(padrao), "\"%s\"", chave);
  const char* p = strstr(json, padrao);
  if (!p) return false;
  p = strchr(p + strlen(padrao), ':');
  if (!p) return false;
  p++;
  while (*p == ' ') p++;
  char* fim;
  long long v = strtoll(p, &fim, 10);
  if (fim == p) return false;
  out = v;
  return true;
}

void tratarComando(uint8_t num, uint8_t* payload, size_t length) {
  char json[256];
  size_t n = length < sizeof(json) - 1 ? length : sizeof(json) - 1;
  memcpy(json, payload, n);
  json[n] = '\0';

  char cmd[24];
  if (!jsonTexto(json, "cmd", cmd, sizeof(cmd))) return;

  long long v;
  if (strcmp(cmd, "sync") == 0) {
    if (jsonNumero(json, "epoch_ms", v) && v > 1600000000000LL) {
      sincronizarRelogio((int64_t)v);
    }
  } else if (strcmp(cmd, "resumo") == 0 || strcmp(cmd, "historico") == 0) {
    pedido.tipo    = (cmd[0] == 'r') ? PEDIDO_RESUMO : PEDIDO_HISTORICO;
    pedido.cliente = num;
    pedido.desde   = jsonNumero(json, "desde", v) ? v : 0;
    pedido.maxPontos = jsonNumero(json, "max", v) ? (int)v : 600;
    if (pedido.maxPontos < 10)   pedido.maxPontos = 10;
    if (pedido.maxPontos > 2000) pedido.maxPontos = 2000;
    Serial.printf("[%u] Pedido de %s desde %lld\n", num, cmd, pedido.desde);
  }
}

// Conta os registros a partir de "desde" (passo 2).
unsigned long contarRegistros(LeitorLog& lg, long long desde,
                              long long& inicio, long long& fim) {
  unsigned long total = 0;
  inicio = 0; fim = 0;
  if (!abrirLeitor(lg)) return 0;
  Registro r;
  while (proximoRegistro(lg, r)) {
    if (r.ts < desde) continue;
    if (total == 0) inicio = r.ts;
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
             "{\"tipo\":\"resumo\",\"sd\":false,\"total\":0,\"inicio\":0,\"fim\":0}");
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
  Serial.printf("Resumo enviado: %s\n", msg);
}

void responderHistorico() {
  if (!sdOk) {
    webSocket.sendTXT(pedido.cliente,
      "{\"tipo\":\"hist_fim\",\"sd\":false,\"total\":0,\"enviados\":0}");
    return;
  }

  LeitorLog lg;
  carregarCorrecoes(lg);
  long long ini, fim;
  unsigned long total = contarRegistros(lg, pedido.desde, ini, fim);

  // Reduz para no máximo "maxPontos": cada ponto enviado agrupa "passo"
  // registros (RMS combinado + maior pico do grupo).
  unsigned long passo = (total + pedido.maxPontos - 1) / pedido.maxPontos;
  if (passo < 1) passo = 1;

  const int PONTOS_POR_MSG = 100;
  static char msg[3200];
  size_t len = 0;
  int noMsg = 0;
  unsigned long enviados = 0;

  auto iniciarMsg = [&]() {
    len = snprintf(msg, sizeof(msg), "{\"tipo\":\"hist\",\"p\":[");
    noMsg = 0;
  };
  auto enviarMsg = [&]() {
    if (noMsg == 0) return;
    len += snprintf(msg + len, sizeof(msg) - len, "]}");
    webSocket.sendTXT(pedido.cliente, msg, len);
    iniciarMsg();
  };

  iniciarMsg();

  if (total > 0 && abrirLeitor(lg)) {
    Registro r;
    unsigned long noGrupo = 0;
    double somaQuad = 0.0;
    int picoMax = 0;
    long long tsGrupo = 0;

    auto fecharGrupo = [&]() {
      if (noGrupo == 0) return;
      double rms = sqrt(somaQuad / (double)noGrupo);
      len += snprintf(msg + len, sizeof(msg) - len, "%s[%lld,%.2f,%d]",
                      noMsg ? "," : "", tsGrupo, rms, picoMax);
      noMsg++;
      enviados++;
      noGrupo = 0; somaQuad = 0.0; picoMax = 0;
      if (noMsg >= PONTOS_POR_MSG) enviarMsg();
    };

    while (proximoRegistro(lg, r)) {
      if (r.ts < pedido.desde) continue;
      if (noGrupo == 0) tsGrupo = r.ts;
      somaQuad += r.rms * r.rms;
      if (r.pico > picoMax) picoMax = r.pico;
      noGrupo++;
      if (noGrupo >= passo) fecharGrupo();
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
  Serial.printf("Historico enviado: %lu registros -> %lu pontos\n",
                total, enviados);
}

void processarPedido() {
  if (pedido.tipo == PEDIDO_NENHUM) return;
  TipoPedido tipo = pedido.tipo;

  if (tipo == PEDIDO_RESUMO) responderResumo();
  else                       responderHistorico();

  // Só limpa se não chegou outro pedido durante o processamento
  if (pedido.tipo == tipo) pedido.tipo = PEDIDO_NENHUM;

  // A leitura do SD trava a amostragem por alguns instantes:
  // reinicia os temporizadores para não gerar janelas "vazias".
  inicioJanela        = millis();
  ultimoMicrosAmostra = micros();
}

// ============================================================
// EVENTO DO WEBSOCKET
// ============================================================

void webSocketEvent(uint8_t num, WStype_t type,
                    uint8_t* payload, size_t length) {
  switch (type) {

    case WStype_DISCONNECTED:
      Serial.printf("[%u] App desconectado!\n", num);
      break;

    case WStype_CONNECTED: {
      IPAddress ip = webSocket.remoteIP(num);
      Serial.printf("[%u] App conectado! IP: %d.%d.%d.%d\n",
                    num, ip[0], ip[1], ip[2], ip[3]);

      // Envia a última leitura na hora, sem esperar 2 s
      if (ultimoJson[0] != '\0') {
        webSocket.sendTXT(num, ultimoJson);
      }
      break;
    }

    case WStype_TEXT:
      tratarComando(num, payload, length);
      break;

    default:
      break;
  }
}

// ============================================================
// FECHAMENTO DA JANELA DE 200 ms
// ============================================================

void fecharJanela() {
  // ---------- RMS / Pico da janela ----------
  double rmsJanela = 0.0;
  if (amostrasJanela > 0) {
    rmsJanela = sqrt(somaQuadradosJanela / (double)amostrasJanela);
  }

  int64_t agora = agoraEpochMs();
  char dataTexto[16];
  char horaTexto[16];
  formatarDataHora(agora, dataTexto, sizeof(dataTexto),
                   horaTexto, sizeof(horaTexto));

  Serial.printf("%s   %s   RMS: %8.2f   Pico: %4d   (n=%lu)\n",
                dataTexto, horaTexto, rmsJanela, picoJanela,
                amostrasJanela);

  // ---------- Acumula no bloco de envio ----------
  somaQuadradosEnvio += somaQuadradosJanela;
  amostrasEnvio      += amostrasJanela;
  if (picoJanela > picoEnvio) picoEnvio = picoJanela;
  janelasNoEnvio++;

  // ---------- Zera a janela ----------
  somaQuadradosJanela = 0.0;
  amostrasJanela      = 0;
  picoJanela          = 0;

  // ---------- Envio + gravação no SD a cada 2 s ----------
  if (janelasNoEnvio >= JANELAS_POR_ENVIO) {

    ultimoRMS  = (amostrasEnvio > 0)
                   ? sqrt(somaQuadradosEnvio / (double)amostrasEnvio)
                   : 0.0;
    ultimoPico = picoEnvio;

    snprintf(ultimoJson, sizeof(ultimoJson),
             "{\"tipo\":\"leitura\",\"ts\":%lld,\"data\":\"%s\","
             "\"hora\":\"%s\",\"rms\":%.2f,\"pico\":%d}",
             (long long)(agora / 1000), dataTexto, horaTexto,
             ultimoRMS, ultimoPico);

    Serial.print("Enviando para o aplicativo: ");
    Serial.println(ultimoJson);

    webSocket.broadcastTXT(ultimoJson);
    gravarNoSD(agora, dataTexto, horaTexto, ultimoRMS, ultimoPico);

    somaQuadradosEnvio = 0.0;
    amostrasEnvio      = 0;
    picoEnvio          = 0;
    janelasNoEnvio     = 0;
  }
}

// ============================================================
// SETUP
// ============================================================

void setup() {
  Serial.begin(115200);
  delay(500);

  millisBase = millis();

  Serial.println();
  Serial.println("==================================================");
  Serial.println("          BIOGLOW - BOIA DE MONITORAMENTO");
  Serial.println("==================================================");

  // ---------- Sensor ----------
  pinMode(PINO_PIEZO, INPUT);
  analogReadResolution(12);                       // 0 a 4095
  analogSetPinAttenuation(PINO_PIEZO, ADC_11db);  // faixa ~0 a 3,3 V

  Serial.println();
  Serial.printf("Sensor de vibracao no GPIO %d (ADC1)\n", PINO_PIEZO);
  Serial.println("Resolucao ADC: 12 bits (0 a 4095), atenuacao 11 dB");
  Serial.printf("Amostragem: %lu Hz | Janela: %lu ms | Envio/SD: %lu ms\n",
                1000000UL / PERIODO_AMOSTRA_US,
                INTERVALO_JANELA_MS,
                INTERVALO_JANELA_MS * JANELAS_POR_ENVIO);

  // ---------- Cartão SD (gravação começa assim que liga) ----------
  Serial.println();
  Serial.println("Inicializando cartao SD (CS=5, SCK=18, MISO=19, MOSI=23)...");
   pinMode(SD_CS, OUTPUT);
  digitalWrite(SD_CS, HIGH);
  SPI.begin(SD_SCK, SD_MISO, SD_MOSI, SD_CS);
  tentarIniciarSD();

  // ---------- Access Point ----------
  Serial.println();
  Serial.println("Configurando rede Wi-Fi Bioglow...");

  WiFi.mode(WIFI_AP);
  WiFi.setSleep(false);   // menor latência no WebSocket

  if (!WiFi.softAP(ssid, password)) {
    Serial.println("ERRO: falha ao criar o Access Point! Reiniciando...");
    delay(2000);
    ESP.restart();
  }

  Serial.print("Rede criada: ");
  Serial.println(ssid);
  Serial.print("IP da Boia: ");
  Serial.println(WiFi.softAPIP());

  // ---------- WebSocket ----------
  webSocket.begin();
  webSocket.onEvent(webSocketEvent);
  // Detecta celular que saiu da rede sem fechar a conexão
  webSocket.enableHeartbeat(15000, 3000, 2);

  Serial.println("Servidor WebSocket rodando na porta 81.");

  Serial.println();
  Serial.println("Data         Hora           RMS         Pico");
  Serial.println("--------------------------------------------------");

  inicioJanela        = millis();
  ultimoMicrosAmostra = micros();
}

// ============================================================
// LOOP PRINCIPAL
// ============================================================

void loop() {
  webSocket.loop();

  // ---------- 0. Pedidos do app (resumo / histórico do SD) ----------
  processarPedido();

  // ---------- 1. Amostragem em taxa fixa ----------
  unsigned long agoraUs = micros();
  if (agoraUs - ultimoMicrosAmostra >= PERIODO_AMOSTRA_US) {
    ultimoMicrosAmostra += PERIODO_AMOSTRA_US;

    // Se o loop atrasou muito (ex.: escrita no SD), ressincroniza
    // em vez de tentar "recuperar" amostras perdidas.
    if (agoraUs - ultimoMicrosAmostra >= PERIODO_AMOSTRA_US) {
      ultimoMicrosAmostra = agoraUs;
    }

    // Sensor: 0 = repouso, 4095 = máximo.
    // Por isso NÃO subtraímos offset (2048); usamos o valor direto.
    int valor = analogRead(PINO_PIEZO);
    valor = constrain(valor, ADC_MINIMO, ADC_MAXIMO);

    somaQuadradosJanela += (double)valor * (double)valor;
    amostrasJanela++;
    if (valor > picoJanela) picoJanela = valor;
  }

  // ---------- 2. Fechamento da janela de 200 ms ----------
  unsigned long agoraMs = millis();
  if (agoraMs - inicioJanela >= INTERVALO_JANELA_MS) {
    inicioJanela += INTERVALO_JANELA_MS;

    // Se ficou mais de uma janela atrasado, ressincroniza para
    // não gerar várias janelas vazias (RMS = 0) em sequência.
    if (agoraMs - inicioJanela >= INTERVALO_JANELA_MS) {
      inicioJanela = agoraMs;
    }

    fecharJanela();
  }

  // ---------- 3. Re-tenta o cartão SD se falhou ----------
  if (!sdOk && millis() - ultimaTentativaSD >= INTERVALO_RETENTATIVA_SD_MS) {
    tentarIniciarSD();
  }
}
