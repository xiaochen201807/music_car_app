import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    if let messenger = (engineBridge as AnyObject).value(forKey: "binaryMessenger") as? FlutterBinaryMessenger {
      CarPlayBridge.configure(with: messenger)
      return
    }
    if let engine = (engineBridge as AnyObject).value(forKey: "engine") as? FlutterEngine {
      CarPlayBridge.configure(with: engine.binaryMessenger)
      return
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "music_car_app.CarPlayBridge") {
      CarPlayBridge.configure(with: registrar.messenger())
    }
  }
}
