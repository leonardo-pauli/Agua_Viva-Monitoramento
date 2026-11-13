import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/configuracoes.dart';
import '../../domain/entities/sensor_info.dart';

/// Utilitário de responsividade para adaptar fontes, ícones, espaçamentos,
/// grades de sensores e altura de gráficos entre celulares, tablets e Desktop.
class Responsivo {
  final Size tamanho;
  final TargetPlatform? plataforma;

  const Responsivo(this.tamanho, {this.plataforma});

  factory Responsivo.of(BuildContext context) =>
      Responsivo(MediaQuery.sizeOf(context));

  double get largura => tamanho.width;
  double get altura => tamanho.height;
  double get menorLado => tamanho.shortestSide;

  /// Verdadeiro quando o app roda em Windows, macOS ou Linux.
  bool get isDesktop => switch (plataforma ?? defaultTargetPlatform) {
        TargetPlatform.windows ||
        TargetPlatform.macOS ||
        TargetPlatform.linux =>
          true,
        _ => false,
      };

  /// Verdadeiro em tablets (ou janelas amplas de computador >= 600 dp).
  bool get isTablet => menorLado >= 600;

  /// Verdadeiro em tablets de 10"+ ou telas amplas (menor dimensão >= 720 dp ou largura >= 960 dp).
  bool get isTabletGrande => menorLado >= 720 || largura >= 960;

  /// Verdadeiro quando há largura suficiente para 4 cards de sensores lado a lado.
  bool get usarQuatroColunasSensores =>
      isDesktop ? largura >= 820 : largura >= 900;

  /// Fator automático de escala de fonte aplicado via [MediaQuery] no [MaterialApp].
  /// Prioriza acessibilidade e boa visualização em todas as telas, diferenciando
  /// celulares compactos/padrão/grandes, tablets (segurados mais longe) e Desktop.
  double get fatorTexto {
    if (isDesktop) {
      if (largura >= 1440) return 1.26;
      if (largura >= 1024) return 1.22;
      return 1.18;
    }
    if (menorLado >= 760) return 1.45;
    if (menorLado >= 600) return 1.38;
    if (menorLado >= 430) return 1.20;
    if (menorLado < 350) return 1.04;
    return 1.14;
  }

  /// Escala final de texto combinando sistema, responsividade e o modo de
  /// acessibilidade, mantendo a diferenciação por tipo de tela.
  double escalaTexto(
    double escalaSistema, {
    bool modoAcessibilidade = false,
  }) {
    final fator = modoAcessibilidade ? fatorTexto * 1.25 : fatorTexto;
    final teto = modoAcessibilidade ? 2.50 : 2.15;
    return (escalaSistema * fator).clamp(1.0, teto).toDouble();
  }

  /// Fator de escala para ícones e elementos gráficos.
  double get fatorIcone {
    if (isDesktop) return largura >= 1200 ? 1.16 : 1.10;
    if (isTabletGrande) return 1.32;
    if (isTablet) return 1.22;
    return 1.0;
  }

  /// Fator de escala para espaçamentos e paddings internos.
  double get fatorEspaco {
    if (isDesktop) return largura >= 1200 ? 1.20 : 1.12;
    if (isTabletGrande) return 1.35;
    if (isTablet) return 1.22;
    return 1.0;
  }

  double icone(double base) => base * fatorIcone;
  double espaco(double base) => base * fatorEspaco;

  /// Altura recomendada para o gráfico de série temporal ao vivo.
  double get alturaGraficoAoVivo {
    if (isTabletGrande) return 340;
    if (isTablet) return 300;
    return 220;
  }

  /// Altura recomendada para o gráfico do relatório do cartão SD.
  double get alturaGraficoRelatorio {
    if (isTabletGrande) return 400;
    if (isTablet) return 350;
    return 280;
  }

  /// Espaço lateral reservado para os números do eixo Y nos gráficos.
  double get larguraEixoY => isTablet ? 66 : 50;

  /// Espaço inferior reservado para os rótulos de tempo do eixo X nos gráficos.
  double alturaEixoX({bool varioDias = false}) {
    if (isTablet) return varioDias ? 54 : 40;
    return varioDias ? 42 : 28;
  }

  /// Margem das listas principais: em telas muito largas centraliza o conteúdo
  /// para manter leitura confortável sem linhas excessivamente compridas.
  EdgeInsets paddingLista({double topo = 10, double base = 28}) {
    const double larguraMaximaConteudo = 1120;
    if (largura > larguraMaximaConteudo + 64) {
      final horizontal = (largura - larguraMaximaConteudo) / 2;
      return EdgeInsets.fromLTRB(
        horizontal,
        espaco(topo),
        horizontal,
        espaco(base),
      );
    }
    final h = isTablet ? 28.0 : 16.0;
    return EdgeInsets.fromLTRB(h, espaco(topo), h, espaco(base));
  }

  /// Largura do menu lateral (Drawer) ajustada para acomodar fontes maiores.
  double get larguraDrawer =>
      isTablet ? math.min(largura * 0.50, 420.0) : 320.0;

  /// Altura (espessura) da AppBar adaptada por tipo de tela, com destaque
  /// maior em tablets e desktop.
  double get alturaAppBar {
    if (isDesktop) return largura >= 1200 ? 82 : 76;
    if (isTabletGrande) return 82;
    if (isTablet) return 76;
    return 64;
  }
}

/// Cores científicas próprias do app que se adaptam entre tema claro (uso sob sol
/// intenso em campo) e escuro (uso noturno / laboratório / menor consumo OLED).
@immutable
class CoresBioglow extends ThemeExtension<CoresBioglow> {
  final Color ph;
  final Color temperatura;
  final Color condutividade;
  final Color turbidez;
  final Color ok;
  final Color alerta;
  final Color erro;

  const CoresBioglow({
    required this.ph,
    required this.temperatura,
    required this.condutividade,
    required this.turbidez,
    required this.ok,
    required this.alerta,
    required this.erro,
  });

  static const escuro = CoresBioglow(
    ph: Color(0xFFB388FF), // Deep Purple Accent
    temperatura: Color(0xFFFF6E40), // Deep Orange Accent
    condutividade: Color(0xFF82B1FF), // Blue Accent
    turbidez: Color(0xFF69F0AE), // Green/Teal Accent
    ok: Color(0xFF69F0AE),
    alerta: Color(0xFFFFD740),
    erro: Color(0xFFFF5252),
  );

  static const claro = CoresBioglow(
    ph: Color(0xFF6A1B9A), // Purple 800
    temperatura: Color(0xFFD84315), // Deep Orange 800
    condutividade: Color(0xFF1565C0), // Blue 800
    turbidez: Color(0xFF00695C), // Teal 800
    ok: Color(0xFF2E7D32), // Green 800
    alerta: Color(0xFF9A6700),
    erro: Color(0xFFC62828), // Red 800
  );

  static CoresBioglow of(BuildContext context) =>
      Theme.of(context).extension<CoresBioglow>() ?? escuro;

  /// Retorna a cor semântica associada a cada [TipoSensor].
  Color corDoSensor(TipoSensor sensor) => switch (sensor) {
        TipoSensor.ph => ph,
        TipoSensor.temperatura => temperatura,
        TipoSensor.condutividade => condutividade,
        TipoSensor.turbidez => turbidez,
      };

  /// Retorna a cor do badge de status da leitura do sensor.
  Color corDoStatus(StatusQualidadeSensor status, ColorScheme scheme) =>
      switch (status) {
        StatusQualidadeSensor.aguardandoHardware => scheme.outline,
        StatusQualidadeSensor.ideal => ok,
        StatusQualidadeSensor.atencao => alerta,
        StatusQualidadeSensor.alerta => erro,
      };

  @override
  CoresBioglow copyWith({
    Color? ph,
    Color? temperatura,
    Color? condutividade,
    Color? turbidez,
    Color? ok,
    Color? alerta,
    Color? erro,
  }) {
    return CoresBioglow(
      ph: ph ?? this.ph,
      temperatura: temperatura ?? this.temperatura,
      condutividade: condutividade ?? this.condutividade,
      turbidez: turbidez ?? this.turbidez,
      ok: ok ?? this.ok,
      alerta: alerta ?? this.alerta,
      erro: erro ?? this.erro,
    );
  }

  @override
  CoresBioglow lerp(CoresBioglow? other, double t) {
    if (other == null) return this;
    return CoresBioglow(
      ph: Color.lerp(ph, other.ph, t)!,
      temperatura: Color.lerp(temperatura, other.temperatura, t)!,
      condutividade: Color.lerp(condutividade, other.condutividade, t)!,
      turbidez: Color.lerp(turbidez, other.turbidez, t)!,
      ok: Color.lerp(ok, other.ok, t)!,
      alerta: Color.lerp(alerta, other.alerta, t)!,
      erro: Color.lerp(erro, other.erro, t)!,
    );
  }
}

/// Caminhos dos ícones PNG personalizados da interface.
abstract final class IconesApp {
  static const String home = 'assets/images/icon_home.png';
  static const String settings = 'assets/images/icon_settings.png';
  static const String menu = 'assets/images/icon_menu.png';
  static const String sliders = 'assets/images/icon_sliders.png';
  static const String screen = 'assets/images/icon_screen.png';
  static const String trash = 'assets/images/icon_trash.png';
  static const String share = 'assets/images/icon_share.png';
  static const String chart = 'assets/images/icon_chart.png';
  static const String help = 'assets/images/icon_help.png';
}

/// Renderiza um ícone PNG monocromático aplicando automaticamente a cor do
/// tema atual (claro/escuro) e escalando proporcionalmente em tablets.
class IconePng extends StatelessWidget {
  final String asset;
  final double size;
  final Color? color;

  const IconePng(
    this.asset, {
    super.key,
    this.size = 20,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final resp = Responsivo.of(context);
    final dimensao = resp.icone(size);
    final corEfetiva = color ??
        IconTheme.of(context).color ??
        Theme.of(context).colorScheme.onSurface;
    return Image.asset(
      asset,
      width: dimensao,
      height: dimensao,
      color: corEfetiva,
      colorBlendMode: BlendMode.srcIn,
      filterQuality: FilterQuality.medium,
    );
  }
}

/// Ícone representativo de cada módulo sensor.
IconData iconeDoSensor(TipoSensor sensor) => switch (sensor) {
      TipoSensor.ph => Icons.science_outlined,
      TipoSensor.temperatura => Icons.thermostat_rounded,
      TipoSensor.condutividade => Icons.bolt_rounded,
      TipoSensor.turbidez => Icons.blur_on_rounded,
    };

ThemeData temaBioglow(Brightness brilho) {
  final isDark = brilho == Brightness.dark;
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF00ACC1),
    brightness: brilho,
    surface: isDark ? const Color(0xFF0B1319) : const Color(0xFFF5F9FB),
  );

  return ThemeData(
    brightness: brilho,
    colorScheme: scheme,
    useMaterial3: true,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: isDark ? const Color(0xFF132029) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.35 : 0.6),
        ),
      ),
    ),
    extensions: [
      isDark ? CoresBioglow.escuro : CoresBioglow.claro,
    ],
  );
}

ThemeMode modoDoTema(TemaApp tema) => switch (tema) {
      TemaApp.sistema => ThemeMode.system,
      TemaApp.claro => ThemeMode.light,
      TemaApp.escuro => ThemeMode.dark,
    };
