# CONTEXTO DA TAREFA – Registro em cartão SD + Relatório no app

> Arquivo criado para passar contexto a outro agente caso a sessão seja interrompida.
> Projeto: BioGlow (app Flutter "bioglow_receptor" + firmware ESP32 "boia").
> Firmware atual: `esp32/bioglow_boia/bioglow_boia.ino` (é o "último código enviado" – usar como base).

## Pedido do usuário (original, resumido)

1. **ESP32 – gravar dados no cartão SD desde que liga.**
   Pinagem do módulo SD (barramento SPI VSPI padrão do ESP32):
   | Módulo SD | ESP32 |
   |-----------|-------|
   | CS        | D5 (GPIO5)  |
   | SCK       | D18 (GPIO18)|
   | MOSI      | D23 (GPIO23)|
   | MISO      | D19 (GPIO19)|
   | VCC       | 3V3   |
   | GND       | GND   |
   - Ao ligar, o ESP32 começa a registrar continuamente as leituras dos sensores no SD
     (ex.: CSV com timestamp/uptime + valores).

2. **App – aviso ao voltar após ≥ 5 minutos fora.**
   - Se o usuário ficar 5 min ou mais fora do app (app em background/fechado),
     ao voltar o app mostra uma mensagem informando que dados foram armazenados
     no SD e pergunta se deseja ver o relatório.
   - O relatório = gráfico(s) dos valores ao longo do tempo armazenado.
   - **Os dados devem ser puxados do SD do ESP32** (via a mesma comunicação já
     usada entre app e ESP32 – verificar no código se é BLE/Wi-Fi/etc.).

3. **Entregáveis:**
   - Alterar o app Flutter.
   - Enviar/atualizar o código do ESP32 (`bioglow_boia.ino`) baseado no último código.

## Plano de implementação (preencher progresso abaixo)

- [x] Ler firmware atual e o app (comunicação, sensores, telas, dependências).
- [x] ESP32: inicializar SD (SPI CS=5,SCK=18,MISO=19,MOSI=23), gravar CSV periódico.
- [x] ESP32: comando para o app pedir o histórico (ex.: listar/ler arquivo em blocos).
  (firmware `bioglow_boia.ino` JÁ REESCRITO – concluído)
- [x] App: detectar tempo em background (`lib/presentation/widgets/ausencia_monitor.dart`).
- [x] App: diálogo "Dados armazenados – ver relatório?".
- [x] App: serviço (`esp32_websocket_service.dart`: pedirResumo/baixarHistorico) e tela
      `lib/presentation/screens/relatorio_screen.dart`; entidades em
      `lib/domain/entities/historico_sd.dart`; `main.dart` usa RepositoryProvider.
- [x] Rodar `flutter analyze` → No issues found.

**STATUS: TAREFA CONCLUÍDA** (falta apenas o usuário testar no hardware).

## Progresso / notas
(atualizar conforme avança)

### Situação encontrada
- Comunicação: ESP32 em Access Point "Bioglow_Boia" + WebSocket `ws://192.168.4.1:81`.
- Firmware já gravava em `/bioglow.csv` (data;hora;rms;pico) a cada 2 s, relógio SIMULADO
  (começa 01/09/2026 10:00 a cada boot). Não havia comando para o app ler o SD.
- App: Flutter + flutter_bloc + fl_chart + web_socket_channel. Arquivos principais:
  `lib/data/esp32_websocket_service.dart`, `lib/presentation/cubit/*`,
  `lib/presentation/screens/dashboard_screen.dart`, `lib/main.dart`.

### Design decidido
- Novo arquivo no SD: `/bioglow_log.csv` → `epoch;data;hora;rms;pico` (epoch = segundos,
  "hora local tratada como UTC"). Marcadores: `#B` (boot) e `#S;<offsetSeg>` (1ª sincronização
  de relógio após o boot – usado para corrigir as linhas gravadas antes da sincronização).
- SPI explícito: `SPI.begin(18,19,23,5); SD.begin(5, SPI, 4000000)`; re-tenta SD a cada 10 s.
- Protocolo WebSocket (JSON):
  - App → ESP: `{"cmd":"sync","epoch_ms":N}` (ao conectar; hora local do celular)
  - App → ESP: `{"cmd":"resumo","desde":S}` → ESP: `{"tipo":"resumo","sd":true,"total":N,"inicio":S,"fim":S}`
  - App → ESP: `{"cmd":"historico","desde":S,"max":600}` → ESP: vários
    `{"tipo":"hist","p":[[ts,rms,pico],...]}` e no fim `{"tipo":"hist_fim","total":N,"enviados":K}`
    (ESP reduz para no máx. `max` pontos: RMS combinado e pico máximo por bloco).
  - Leitura ao vivo ganhou `"tipo":"leitura"` e `"ts":S` (app aceita sem "tipo" por compatibilidade).
  - Requisições são processadas no loop() (não dentro do callback do WebSocket).
- App: `shared_preferences` guarda o momento em que o app foi para segundo plano;
  widget `AusenciaMonitor` (WidgetsBindingObserver) verifica ao voltar/abrir; se ≥ 5 min,
  aguarda conexão, pede resumo e mostra diálogo → `RelatorioScreen` (gráfico fl_chart por tempo).
