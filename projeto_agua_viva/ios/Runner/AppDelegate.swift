import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate, UIDocumentPickerDelegate {
  private var canalArquivos: FlutterMethodChannel?
  private var resultadoSalvarPendente: FlutterResult?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let ok = super.application(application, didFinishLaunchingWithOptions: launchOptions)
    if canalArquivos == nil, let controller = window?.rootViewController as? FlutterViewController {
      configurarCanalArquivos(messenger: controller.binaryMessenger)
    }
    return ok
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    configurarCanalArquivos(messenger: engineBridge.applicationRegistrar.messenger())
  }

  private func configurarCanalArquivos(messenger: FlutterBinaryMessenger) {
    let canal = FlutterMethodChannel(name: "bioglow/arquivos", binaryMessenger: messenger)
    canal.setMethodCallHandler { [weak self] call, result in
      guard let self = self else { return }
      let args = call.arguments as? [String: Any]
      let nome = (args?["nome"] as? String) ?? "hidrobo_dados.csv"
      let conteudo = (args?["conteudo"] as? String) ?? ""

      switch call.method {
      case "compartilharCsv":
        self.compartilharArquivoCsv(nome: nome, conteudo: conteudo, result: result)
      case "salvarCsv":
        self.salvarArquivoCsv(nome: nome, conteudo: conteudo, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
    self.canalArquivos = canal
  }

  private func gravarCsvTemporario(nome: String, conteudo: String) throws -> URL {
    let caracteresInvalidos = CharacterSet(charactersIn: "/\\?%*|\"<>:")
    let nomeSeguro = nome.components(separatedBy: caracteresInvalidos).joined(separator: "_")
    let pasta = FileManager.default.temporaryDirectory.appendingPathComponent("exportacoes", isDirectory: true)
    try FileManager.default.createDirectory(at: pasta, withIntermediateDirectories: true)
    let arquivoUrl = pasta.appendingPathComponent(nomeSeguro)
    let textoComBom = conteudo.hasPrefix("\u{FEFF}") ? conteudo : "\u{FEFF}" + conteudo
    try textoComBom.write(to: arquivoUrl, atomically: true, encoding: .utf8)
    return arquivoUrl
  }

  private func topViewController() -> UIViewController? {
    let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
    for scene in scenes {
      if let root = scene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        ?? scene.windows.first?.rootViewController {
        var top = root
        while let presented = top.presentedViewController {
          top = presented
        }
        return top
      }
    }
    return window?.rootViewController
  }

  private func configurarPopoverParaIPad(_ viewController: UIViewController, origem: UIViewController) {
    if let popover = viewController.popoverPresentationController {
      popover.sourceView = origem.view
      popover.sourceRect = CGRect(
        x: origem.view.bounds.midX,
        y: origem.view.bounds.midY,
        width: 1,
        height: 1
      )
      popover.permittedArrowDirections = []
    }
  }

  private func compartilharArquivoCsv(nome: String, conteudo: String, result: @escaping FlutterResult) {
    do {
      let arquivoUrl = try gravarCsvTemporario(nome: nome, conteudo: conteudo)
      DispatchQueue.main.async {
        guard let topVC = self.topViewController() else {
          result(FlutterError(code: "SEM_TELA", message: "ViewController indisponível no iOS", details: nil))
          return
        }
        let activityVC = UIActivityViewController(activityItems: [arquivoUrl], applicationActivities: nil)
        self.configurarPopoverParaIPad(activityVC, origem: topVC)
        topVC.present(activityVC, animated: true) {
          result(true)
        }
      }
    } catch {
      result(FlutterError(code: "ERRO_COMPARTILHAR", message: error.localizedDescription, details: nil))
    }
  }

  private func salvarArquivoCsv(nome: String, conteudo: String, result: @escaping FlutterResult) {
    do {
      let arquivoUrl = try gravarCsvTemporario(nome: nome, conteudo: conteudo)
      DispatchQueue.main.async {
        guard let topVC = self.topViewController() else {
          result(FlutterError(code: "SEM_TELA", message: "ViewController indisponível no iOS", details: nil))
          return
        }
        self.resultadoSalvarPendente?(false)
        self.resultadoSalvarPendente = result

        let picker: UIDocumentPickerViewController
        if #available(iOS 14.0, *) {
          picker = UIDocumentPickerViewController(forExporting: [arquivoUrl], asCopy: true)
        } else {
          picker = UIDocumentPickerViewController(url: arquivoUrl, in: .exportToService)
        }
        picker.delegate = self
        self.configurarPopoverParaIPad(picker, origem: topVC)
        topVC.present(picker, animated: true)
      }
    } catch {
      result(FlutterError(code: "ERRO_SALVAR", message: error.localizedDescription, details: nil))
    }
  }

  func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
    let res = resultadoSalvarPendente
    resultadoSalvarPendente = nil
    res?(!urls.isEmpty)
  }

  func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
    let res = resultadoSalvarPendente
    resultadoSalvarPendente = nil
    res?(false)
  }
}
