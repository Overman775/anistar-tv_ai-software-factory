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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "PlaybackScreenAwake") {
      PlaybackScreenAwake.register(with: registrar)
    }
  }
}

// A single owner of the idle timer. video_player's automatic sleep prevention
// is disabled in Dart, so paused/buffering/background playback cannot retain it.
final class PlaybackScreenAwake: NSObject, FlutterPlugin {
  private var previousIdleTimer: Bool?
  private var isForeground = true

  static func register(with registrar: FlutterPluginRegistrar) {
    let instance = PlaybackScreenAwake()
    let channel = FlutterMethodChannel(
      name: "anistar_tv/playback_screen_awake", binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(instance, channel: channel)
    NotificationCenter.default.addObserver(
      instance, selector: #selector(instance.deactivate),
      name: UIScene.willDeactivateNotification, object: nil)
    NotificationCenter.default.addObserver(
      instance, selector: #selector(instance.activate),
      name: UIScene.didActivateNotification, object: nil)
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "setEnabled":
      guard let enabled = call.arguments as? Bool else {
        result(FlutterError(code: "invalid_arguments", message: "Expected a boolean", details: nil))
        return
      }
      if enabled && isForeground {
        if previousIdleTimer == nil {
          previousIdleTimer = UIApplication.shared.isIdleTimerDisabled
        }
        UIApplication.shared.isIdleTimerDisabled = true
      } else {
        releaseTimer()
      }
      result(nil)
    case "isEnabled":
      result(previousIdleTimer != nil && UIApplication.shared.isIdleTimerDisabled)
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  @objc private func deactivate() {
    isForeground = false
    releaseTimer()
  }

  @objc private func activate() {
    isForeground = true
    // Only a fresh Dart lifecycle predicate may acquire the timer again.
  }

  private func releaseTimer() {
    if let previous = previousIdleTimer {
      UIApplication.shared.isIdleTimerDisabled = previous
      previousIdleTimer = nil
    }
  }

  func detachFromEngine(for registrar: FlutterPluginRegistrar) {
    releaseTimer()
    NotificationCenter.default.removeObserver(self)
  }
}
