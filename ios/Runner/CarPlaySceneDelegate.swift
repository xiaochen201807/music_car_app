import CarPlay
import Flutter
import UIKit

/// Shared coordinator between the Flutter binary messenger and any
/// system-created CPTemplateApplicationScene delegate instance.
enum CarPlayBridge {
  static var interfaceController: CPInterfaceController?
  static var listTemplate: CPListTemplate?
  static var channel: FlutterMethodChannel?
  static var connected = false
  static var lastPayload: [String: Any] = [:]

  static func configure(with messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "music_car_app/carplay",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      handleFlutterCall(call, result: result)
    }
    self.channel = channel
    emitConnectionStatus()
    if !lastPayload.isEmpty {
      applyPayload(lastPayload)
    }
  }

  static func handleFlutterCall(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "getStatus":
      result(statusMap())
    case "syncNowPlaying":
      guard let args = call.arguments as? [String: Any] else {
        result(FlutterError(code: "bad_args", message: "expected map", details: nil))
        return
      }
      lastPayload = args
      applyPayload(args)
      result(true)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  static func statusMap() -> [String: Any] {
    [
      "available": true,
      "connected": connected,
      "reason": connected ? "connected" : "scene_ready",
    ]
  }

  static func emitConnectionStatus() {
    channel?.invokeMethod("onConnectionChanged", arguments: statusMap())
  }

  static func didConnect(interfaceController: CPInterfaceController) {
    self.interfaceController = interfaceController
    connected = true
    let template = CPListTemplate(title: "车载音乐", sections: [])
    listTemplate = template
    interfaceController.setRootTemplate(template, animated: true)
    emitConnectionStatus()
    if !lastPayload.isEmpty {
      applyPayload(lastPayload)
    }
  }

  static func didDisconnect(interfaceController: CPInterfaceController) {
    if self.interfaceController === interfaceController {
      self.interfaceController = nil
      listTemplate = nil
      connected = false
      emitConnectionStatus()
    }
  }

  static func applyPayload(_ payload: [String: Any]) {
    guard let listTemplate else { return }

    let queue = payload["queue"] as? [[String: Any]] ?? []
    let queueIndex = intValue(payload["queueIndex"], defaultValue: -1)
    let playing = payload["playing"] as? Bool ?? false
    let title = stringValue(payload["title"]).ifBlank("未在播放")
    let artist = stringValue(payload["artist"])

    var items: [CPListItem] = []
    if queue.isEmpty {
      // No handler: non-interactive placeholder. Avoid isEnabled (iOS 15+ only);
      // project deployment target remains iOS 14 for broader device support.
      let empty = CPListItem(text: "队列为空", detailText: "在手机端播放后这里会显示歌曲")
      items.append(empty)
    } else {
      for (index, song) in queue.enumerated() {
        let name = stringValue(song["name"]).ifBlank("未知歌曲")
        let songArtist = stringValue(song["artist"])
        let item = CPListItem(text: name, detailText: songArtist)
        item.isPlaying = index == queueIndex && playing
        item.handler = { _, completion in
          sendControl(action: "selectQueueItem", extras: ["queueIndex": index]) { _ in
            completion()
          }
        }
        items.append(item)
      }
    }

    let nowPlayingDetail: String
    if artist.isEmpty {
      nowPlayingDetail = playing ? "播放中" : "已暂停"
    } else {
      nowPlayingDetail = "\(artist) · \(playing ? "播放中" : "已暂停")"
    }
    let nowPlayingItem = CPListItem(text: title, detailText: nowPlayingDetail)
    nowPlayingItem.handler = { _, completion in
      sendControl(action: playing ? "pause" : "play", extras: [:]) { _ in
        completion()
      }
    }

    let nowPlayingSection = CPListSection(
      items: [nowPlayingItem],
      header: "正在播放",
      sectionIndexTitle: nil
    )
    let queueSection = CPListSection(
      items: items,
      header: "当前队列",
      sectionIndexTitle: nil
    )
    listTemplate.updateSections([nowPlayingSection, queueSection])
  }

  static func sendControl(
    action: String,
    extras: [String: Any],
    completion: @escaping (Bool) -> Void
  ) {
    var payload = extras
    payload["action"] = action
    guard let channel else {
      completion(false)
      return
    }
    channel.invokeMethod("onControl", arguments: payload) { result in
      if let map = result as? [String: Any], let handled = map["handled"] as? Bool {
        completion(handled)
      } else {
        completion(false)
      }
    }
  }

  static func stringValue(_ value: Any?) -> String {
    if let value = value as? String {
      return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    if let value = value {
      return "\(value)".trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return ""
  }

  static func intValue(_ value: Any?, defaultValue: Int) -> Int {
    if let value = value as? Int {
      return value
    }
    if let value = value as? NSNumber {
      return value.intValue
    }
    if let value = value as? String, let parsed = Int(value) {
      return parsed
    }
    return defaultValue
  }
}

/// System-created scene delegate. Forwards lifecycle events to [CarPlayBridge].
final class CarPlaySceneDelegate: UIResponder, CPTemplateApplicationSceneDelegate {
  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didConnect interfaceController: CPInterfaceController
  ) {
    CarPlayBridge.didConnect(interfaceController: interfaceController)
  }

  func templateApplicationScene(
    _ templateApplicationScene: CPTemplateApplicationScene,
    didDisconnect interfaceController: CPInterfaceController
  ) {
    CarPlayBridge.didDisconnect(interfaceController: interfaceController)
  }
}

private extension String {
  func ifBlank(_ fallback: String) -> String {
    isEmpty ? fallback : self
  }
}
