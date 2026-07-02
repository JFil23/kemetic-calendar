import Flutter
import UIKit
import EventKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let calendarChannel = "com.kemetic.calendar/sync"
  private let eventStore = EKEventStore()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    guard
      let window = window,
      let controller = window.rootViewController as? FlutterViewController
    else {
      assertionFailure("FlutterViewController not ready for calendar channel")
      return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }

    let channel = FlutterMethodChannel(
      name: calendarChannel,
      binaryMessenger: controller.binaryMessenger
    )

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermissions":
        self.handleRequestPermissions(result: result)
      case "getStableDeviceId":
        result(self.stableDeviceId())
      case "fetchEvents":
        if let args = call.arguments as? [String: Any] {
          self.handleFetchEvents(args: args, result: result)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing arguments", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    reloadDailyReflectionWidgetTimeline()
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func reloadDailyReflectionWidgetTimeline() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadTimelines(ofKind: "DailyReflectionWidget")
    }
  }

  private func handleRequestPermissions(result: @escaping FlutterResult) {
    let complete: (Bool, Error?) -> Void = { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
        } else {
          result(granted)
        }
      }
    }

    if #available(iOS 17.0, *) {
      eventStore.requestFullAccessToEvents(completion: complete)
    } else {
      eventStore.requestAccess(to: .event, completion: complete)
    }
  }

  private func stableDeviceId() -> String? {
    guard let raw = UIDevice.current.identifierForVendor?.uuidString.trimmingCharacters(in: .whitespacesAndNewlines),
          !raw.isEmpty else {
      return nil
    }
    return "ios:\(raw)"
  }

  private func handleFetchEvents(args: [String: Any], result: FlutterResult) {
    guard let startMs = args["start"] as? Int64,
          let endMs = args["end"] as? Int64 else {
      result(FlutterError(code: "bad_args", message: "Missing start/end", details: nil))
      return
    }

    let startDate = Date(timeIntervalSince1970: TimeInterval(Double(startMs) / 1000.0))
    let endDate = Date(timeIntervalSince1970: TimeInterval(Double(endMs) / 1000.0))

    let predicate = eventStore.predicateForEvents(withStart: startDate, end: endDate, calendars: nil)
    let events = eventStore.events(matching: predicate).map { e -> [String: Any?] in
      let cid = extractCid(from: e.notes)
      let modified = (e.lastModifiedDate ?? e.creationDate ?? Date())
      return [
        "eventId": e.eventIdentifier,
        "title": e.title ?? "",
        "description": e.notes ?? "",
        "location": e.location ?? "",
        "start": Int64(e.startDate.timeIntervalSince1970 * 1000),
        "end": Int64((e.endDate ?? e.startDate).timeIntervalSince1970 * 1000),
        "allDay": e.isAllDay,
        "calendarId": e.calendar.calendarIdentifier,
        "timeZone": (e.timeZone?.identifier ?? TimeZone.current.identifier),
        "lastModified": Int64(modified.timeIntervalSince1970 * 1000),
        "clientEventId": cid
      ]
    }

    result(events)
  }

  private func extractCid(from notes: String?) -> String? {
    guard let notes = notes else { return nil }
    let regex = try? NSRegularExpression(pattern: "kemet_cid:([^\\s]+)", options: .caseInsensitive)
    let range = NSRange(location: 0, length: notes.utf16.count)
    if let match = regex?.firstMatch(in: notes, options: [], range: range),
       let cidRange = Range(match.range(at: 1), in: notes) {
      return String(notes[cidRange])
    }
    return nil
  }
}
