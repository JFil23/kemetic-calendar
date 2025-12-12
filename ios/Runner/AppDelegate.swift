import Flutter
import UIKit
import EventKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let calendarChannel = "com.kemetic.calendar/sync"
  private let eventStore = EKEventStore()
  
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
    let channel = FlutterMethodChannel(name: calendarChannel, binaryMessenger: controller.binaryMessenger)

    channel.setMethodCallHandler { [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
      guard let self = self else { return }
      switch call.method {
      case "requestPermissions":
        self.handleRequestPermissions(result: result)
      case "fetchEvents":
        if let args = call.arguments as? [String: Any] {
          self.handleFetchEvents(args: args, result: result)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing arguments", details: nil))
        }
      case "upsertEvent":
        if let args = call.arguments as? [String: Any] {
          self.handleUpsertEvent(args: args, result: result)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing arguments", details: nil))
        }
      case "deleteEvent":
        if let args = call.arguments as? [String: Any], let eventId = args["eventId"] as? String {
          self.handleDelete(eventId: eventId, result: result)
        } else {
          result(FlutterError(code: "bad_args", message: "Missing eventId", details: nil))
        }
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  private func handleRequestPermissions(result: @escaping FlutterResult) {
    eventStore.requestAccess(to: .event) { granted, error in
      DispatchQueue.main.async {
        if let error = error {
          result(FlutterError(code: "permission_error", message: error.localizedDescription, details: nil))
        } else {
          result(granted)
        }
      }
    }
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

  private func handleUpsertEvent(args: [String: Any], result: @escaping FlutterResult) {
    guard let startMs = args["start"] as? Int64 else {
      result(FlutterError(code: "bad_args", message: "Missing start", details: nil))
      return
    }

    let endMs = args["end"] as? Int64
    let allDay = args["allDay"] as? Bool ?? false
    let title = (args["title"] as? String) ?? "Untitled event"
    let description = args["description"] as? String
    let location = args["location"] as? String
    let calendarId = args["calendarId"] as? String
    let clientEventId = args["clientEventId"] as? String
    let eventId = args["eventId"] as? String
    let tzId = args["timeZone"] as? String

    let start = Date(timeIntervalSince1970: TimeInterval(Double(startMs) / 1000.0))
    let end = endMs != nil
      ? Date(timeIntervalSince1970: TimeInterval(Double(endMs!) / 1000.0))
      : start.addingTimeInterval(3600)

    var event: EKEvent
    if let eventId = eventId, let existing = eventStore.event(withIdentifier: eventId) {
      event = existing
    } else {
      event = EKEvent(eventStore: eventStore)
      if let calId = calendarId, let cal = eventStore.calendar(withIdentifier: calId) {
        event.calendar = cal
      } else if let defaultCal = eventStore.defaultCalendarForNewEvents {
        event.calendar = defaultCal
      } else if let firstCal = eventStore.calendars(for: .event).first {
        event.calendar = firstCal
      }
    }

    event.title = title
    event.location = location
    event.isAllDay = allDay
    event.startDate = start
    event.endDate = end
    if let tzId = tzId, let tz = TimeZone(identifier: tzId) {
      event.timeZone = tz
    }
    event.notes = mergeNotes(description, cid: clientEventId)

    do {
      try eventStore.save(event, span: .thisEvent)
      result(event.eventIdentifier)
    } catch {
      result(FlutterError(code: "save_failed", message: error.localizedDescription, details: nil))
    }
  }

  private func handleDelete(eventId: String, result: FlutterResult) {
    if let event = eventStore.event(withIdentifier: eventId) {
      do {
        try eventStore.remove(event, span: .thisEvent)
        result(true)
      } catch {
        result(FlutterError(code: "delete_failed", message: error.localizedDescription, details: nil))
      }
    } else {
      result(false)
    }
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

  private func mergeNotes(_ notes: String?, cid: String?) -> String? {
    guard let cid = cid, !cid.isEmpty else { return notes }
    let base = notes ?? ""
    let cleaned = base.replacingOccurrences(of: "kemet_cid:[^\\s]+", with: "", options: .regularExpression, range: nil).trimmingCharacters(in: .whitespacesAndNewlines)
    if cleaned.contains("kemet_cid:\(cid)") {
      return cleaned
    }
    if cleaned.isEmpty {
      return "kemet_cid:\(cid)"
    }
    return "\(cleaned)\n\nkemet_cid:\(cid)"
  }
}
