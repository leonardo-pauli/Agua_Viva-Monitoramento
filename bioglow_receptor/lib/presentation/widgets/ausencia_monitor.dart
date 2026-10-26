import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/esp32_websocket_service.dart';
import '../../domain/entities/historico_sd.dart';
import '../screens/relatorio_screen.dart';

/// Observa o ciclo de vida do app. Quando o usuário fica [limiteAusencia]
/// ou mais fora do app (em segundo plano ou com o app fechado), ao voltar
/// pergunta à boia quantos dados foram gravados no cartão SD nesse período
/// e oferece abrir o relatório.
class AusenciaMonitor extends StatefulWidget {
  final Widget child;

  const AusenciaMonitor({super.key, required this.child});

  static const Duration limiteAusencia = Duration(minutes: 5);

  @override
  State<AusenciaMonitor> createState() => _AusenciaMonitorState();
}

class _AusenciaMonitorState extends State<AusenciaMonitor>
    with WidgetsBindingObserver {
  /// Momento (ms desde epoch) em que o app foi para segundo plano.
  /// Fica salvo em disco para funcionar mesmo se o app for fechado.
  static const String _chaveSaida = 'bioglow_saiu_em_ms';

  bool _verificando = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // App aberto do zero: verifica se ficou fechado por muito tempo
    WidgetsBinding.instance.addPostFrameCallback((_) => _verificarRetorno());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
        _registrarSaida();
      case AppLifecycleState.resumed:
        _verificarRetorno();
      case AppLifecycleState.inactive:
        break; // ex.: puxou a barra de notificações – não conta como saída
    }
  }

  Future<void> _registrarSaida() async {
    final prefs = await SharedPreferences.getInstance();
    // hidden e paused chegam em sequência: mantém o primeiro horário
    if (!prefs.containsKey(_chaveSaida)) {
      await prefs.setInt(_chaveSaida, DateTime.now().millisecondsSinceEpoch);
    }
  }

  Future<void> _verificarRetorno() async {
    if (_verificando) return;
    _verificando = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final saiuMs = prefs.getInt(_chaveSaida);
      await prefs.remove(_chaveSaida);
      if (saiuMs == null) return;

      final saiu = DateTime.fromMillisecondsSinceEpoch(saiuMs);
      final ausencia = DateTime.now().difference(saiu);
      if (ausencia < AusenciaMonitor.limiteAusencia) return;
      if (!mounted) return;

      final service = context.read<Esp32WebSocketService>();
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(const SnackBar(
        content: Text('Verificando dados gravados no cartão SD da boia...'),
        duration: Duration(seconds: 3),
      ));

      final conectou =
          await service.aguardarConexao(const Duration(seconds: 20));
      final resumo = conectou ? await service.pedirResumo(saiu) : null;
      if (!mounted) return;

      if (resumo != null && resumo.sdOk && resumo.total == 0) {
        messenger?.showSnackBar(const SnackBar(
          content: Text('Nenhum dado novo foi gravado no cartão SD.'),
        ));
        return;
      }

      final abrir = await _mostrarDialogo(
        ausencia: ausencia,
        resumo: resumo,
        conectou: conectou,
      );
      if (abrir == true && mounted) {
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => RelatorioScreen(desdeSaida: saiu),
        ));
      }
    } finally {
      _verificando = false;
    }
  }

  Future<bool?> _mostrarDialogo({
    required Duration ausencia,
    required ResumoSd? resumo,
    required bool conectou,
  }) {
    final tempoFora = formatarDuracao(ausencia);

    late final IconData icone;
    late final String titulo;
    late final String mensagem;
    var permiteRelatorio = true;

    if (resumo == null) {
      icone = Icons.wifi_off;
      titulo = 'Bem-vindo de volta';
      mensagem = conectou
          ? 'Você ficou $tempoFora fora do app. A boia não respondeu ao '
              'pedido de dados do cartão SD.\n\nDeseja abrir o relatório e '
              'tentar novamente?'
          : 'Você ficou $tempoFora fora do app. Durante esse período a boia '
              'continuou gravando no cartão SD, mas não foi possível conectar '
              'a ela agora.\n\nConecte-se à rede "Bioglow_Boia" e abra o '
              'relatório.';
    } else if (!resumo.sdOk) {
      icone = Icons.sd_card_alert_outlined;
      titulo = 'Cartão SD não detectado';
      mensagem = 'Você ficou $tempoFora fora do app, mas a boia não está '
          'conseguindo gravar no cartão SD. Verifique o cartão e as ligações.';
      permiteRelatorio = false;
    } else {
      icone = Icons.sd_card_outlined;
      titulo = 'Dados armazenados';
      final ini = resumo.inicio;
      final fim = resumo.fim;
      final periodo = (ini != null && fim != null)
          ? ' (de ${formatarDataHora(ini)} até ${formatarDataHora(fim)})'
          : '';
      mensagem = 'Você ficou $tempoFora fora do app. Nesse período a boia '
          'armazenou ${resumo.total} leituras no cartão SD$periodo.'
          '\n\nDeseja ver o relatório?';
    }

    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: Icon(icone),
        title: Text(titulo),
        content: Text(mensagem),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(permiteRelatorio ? 'Agora não' : 'OK'),
          ),
          if (permiteRelatorio)
            FilledButton.icon(
              onPressed: () => Navigator.of(ctx).pop(true),
              icon: const Icon(Icons.insights),
              label: const Text('Ver relatório'),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
