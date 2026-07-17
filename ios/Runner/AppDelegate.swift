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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "music_car_app.DeviceAuth") {
      let channel = FlutterMethodChannel(
        name: "music_car_app/device_auth",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        if call.method == "getDeviceId" {
          result(DeviceIdStore.shared.deviceId())
        } else {
          result(FlutterMethodNotImplemented)
        }
      }
    }
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

/// Persists a stable install-scoped device id for activation (Keychain-like via UserDefaults).
enum DeviceIdStore {
  static let shared = DeviceIdStoreBox()
}

final class DeviceIdStoreBox {
  private let key = "music_car_app.device_auth.device_id"

  func deviceId() -> String {
    if let existing = UserDefaults.standard.string(forKey: key), !existing.isEmpty {
      return existing
    }
    let id = UUID().uuidString
    UserDefaults.standard.set(id, forKey: key)
    return id
  }
}
