import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)
    if let registrar = registrar(forPlugin: "DeviceCalendarBridge") {
      DeviceCalendarBridge.register(with: registrar)
    }
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "DailyReflectionWidget")
    }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
