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
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "AppIconChannel") {
      registerAppIconChannel(messenger: registrar.messenger())
    }
    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "HijriCalendarChannel") {
      let channel = FlutterMethodChannel(
        name: "com.ebaidllc.tajweed_practice/hijri_calendar",
        binaryMessenger: registrar.messenger()
      )
      channel.setMethodCallHandler { call, result in
        guard call.method == "getDate" else {
          result(FlutterMethodNotImplemented)
          return
        }
        guard let arguments = call.arguments as? [String: Any],
              let milliseconds = arguments["millisecondsSinceEpoch"] as? NSNumber else {
          result(FlutterError(code: "invalid_argument", message: "A timestamp is required.", details: nil))
          return
        }
        var calendar = Calendar(identifier: .islamicUmmAlQura)
        calendar.timeZone = .current
        let date = Date(timeIntervalSince1970: milliseconds.doubleValue / 1000)
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        guard let year = parts.year, let month = parts.month, let day = parts.day else {
          result(FlutterError(code: "calendar_failed", message: "Could not read the Hijri date.", details: nil))
          return
        }
        result(["year": year, "month": month, "day": day])
      }
    }
  }

  private func registerAppIconChannel(messenger: FlutterBinaryMessenger) {
    let channel = FlutterMethodChannel(
      name: "com.ebaidllc.tajweed_practice/app_icon",
      binaryMessenger: messenger
    )
    channel.setMethodCallHandler { call, result in
      let app = UIApplication.shared
      switch call.method {
      case "supportsAlternateIcons":
        result(app.supportsAlternateIcons)
      case "getIconName":
        result(app.alternateIconName)
      case "setIconName":
        let arguments = call.arguments as? [String: Any]
        let name = arguments?["name"] as? String
        guard app.supportsAlternateIcons, app.applicationState == .active else {
          result(
            FlutterError(
              code: "unavailable",
              message: "Alternate icons can only change while the app is active.",
              details: nil
            )
          )
          return
        }
        app.setAlternateIconName(name) { error in
          DispatchQueue.main.async {
            if let error = error {
              result(
                FlutterError(
                  code: "set_icon_failed",
                  message: error.localizedDescription,
                  details: nil
                )
              )
            } else {
              result(nil)
            }
          }
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }
}
