import EventKit
import Flutter
import UIKit

/// A read-only projection boundary. No EventKit mutation API is exposed.
final class DeviceCalendarBridge: NSObject, FlutterPlugin, FlutterStreamHandler {
  private let queue = DispatchQueue(label: "haw.device-calendar.read", qos: .userInitiated)
  private var store: EKEventStore?
  private var observer: NSObjectProtocol?
  private var sink: FlutterEventSink?
  private var requestingPermission = false

  static func register(with registrar: FlutterPluginRegistrar) {
    let bridge = DeviceCalendarBridge()
    registrar.addMethodCallDelegate(bridge, channel: FlutterMethodChannel(
      name: "com.kemetic.calendar/device_import_v1", binaryMessenger: registrar.messenger()))
    FlutterEventChannel(name: "com.kemetic.calendar/device_import_changes_v1",
      binaryMessenger: registrar.messenger()).setStreamHandler(bridge)
  }

  private func permission() -> String {
    let status = EKEventStore.authorizationStatus(for: .event)
    if #available(iOS 17.0, *), status == .fullAccess { return "granted" }
    switch status {
    case .authorized: return "granted"
    case .notDetermined: return "notDetermined"
    case .restricted: return "restricted"
    default: return "denied"
    }
  }

  private func eventStore() -> EKEventStore {
    if let store = store { return store }
    let value = EKEventStore()
    store = value
    return value
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "permissionStatus": result(permission())
    case "deviceId":
      guard let identifier = UIDevice.current.identifierForVendor?.uuidString else {
        result(failure("device_unavailable")); return
      }
      result("ios:\(identifier)")
    case "requestPermission": requestPermission(result)
    case "listCalendars":
      read(result) { store in
        store.calendars(for: .event).map { calendar in
          ["native_id": calendar.calendarIdentifier,
           "label": calendar.title,
           "account_label": calendar.source.title,
           "source_id": calendar.source.sourceIdentifier,
           "kind": "eventkit:\(calendar.source.sourceType.rawValue)",
           "color": Self.color(calendar.cgColor)]
        }
      }
    case "readSnapshot":
      guard let args = call.arguments as? [String: Any],
        let ids = args["calendarIds"] as? [String], !ids.isEmpty, ids.count <= 50,
        Set(ids).count == ids.count,
        let from = args["fromMs"] as? NSNumber, let until = args["untilMs"] as? NSNumber,
        until.doubleValue > from.doubleValue,
        until.doubleValue - from.doubleValue <= 730 * 86400000 else {
        result(failure("invalid_range")); return
      }
      read(result) { store in
        let inventory = Dictionary(uniqueKeysWithValues: store.calendars(for: .event)
          .map { ($0.calendarIdentifier, $0) })
        let calendars = ids.compactMap { inventory[$0] }
        guard calendars.count == ids.count else { throw ReadFailure("source_unavailable") }
        let start = Date(timeIntervalSince1970: from.doubleValue / 1000)
        let end = Date(timeIntervalSince1970: until.doubleValue / 1000)
        let events = store.events(matching: store.predicateForEvents(
          withStart: start, end: end, calendars: calendars))
        guard events.count <= 50000 else { throw ReadFailure("too_many_events") }
        var originalAllDay: [String: Bool] = [:]
        var rows: [[String: Any]] = []
        var identities = Set<String>()
        for event in events {
          guard let eventStart = event.startDate, let eventEnd = event.endDate,
            eventEnd > eventStart else { throw ReadFailure("invalid_event") }
          let external = event.calendarItemExternalIdentifier?.trimmingCharacters(in: .whitespacesAndNewlines)
          let series = (external?.isEmpty == false ? external! : event.calendarItemIdentifier)
          guard !series.isEmpty else { throw ReadFailure("invalid_identity") }
          var anchor = "single"
          if event.hasRecurrenceRules || event.isDetached {
            guard let original = event.occurrenceDate else { throw ReadFailure("invalid_identity") }
            let masterKey = event.calendar.calendarIdentifier + "\u{0}" + series
            var wasAllDay = event.isAllDay
            if event.isDetached, let external = external, !external.isEmpty {
              if let cached = originalAllDay[masterKey] { wasAllDay = cached }
              else {
                let masters = store.calendarItems(withExternalIdentifier: external).compactMap { $0 as? EKEvent }
                  .filter { $0.calendar.calendarIdentifier == event.calendar.calendarIdentifier &&
                    $0.hasRecurrenceRules && !$0.isDetached }
                guard let master = masters.first else { throw ReadFailure("series_unavailable") }
                wasAllDay = master.isAllDay
                originalAllDay[masterKey] = wasAllDay
              }
            }
            anchor = wasAllDay ? "date:\(Self.civilDate(original))" : "time:\(Self.instant(original))"
          }
          let identity = event.calendar.calendarIdentifier + "\u{0}" + series + "\u{0}" + anchor
          guard identities.insert(identity).inserted else { throw ReadFailure("ambiguous_identity") }
          var row: [String: Any] = [
            "native_calendar_id": event.calendar.calendarIdentifier,
            "provider_event_id": series, "recurrence_id": anchor,
            "title": event.title ?? "", "detail": event.notes ?? "",
            "location": event.location ?? "", "all_day": event.isAllDay,
            "starts_at": Self.instant(eventStart), "ends_at": Self.instant(eventEnd)
          ]
          if event.isAllDay {
            row["start_date"] = Self.civilDate(eventStart)
            row["end_date"] = Self.civilDate(eventEnd)
          }
          rows.append(row)
        }
        return ["complete": true, "calendarIds": ids,
          "fromMs": from, "untilMs": until, "events": rows]
      }
    default: result(FlutterMethodNotImplemented)
    }
  }

  private func requestPermission(_ result: @escaping FlutterResult) {
    if permission() != "notDetermined" { result(permission()); return }
    guard !requestingPermission else { result(failure("permission_in_progress")); return }
    requestingPermission = true
    let reply = OnceReply(result)
    DispatchQueue.main.asyncAfter(deadline: .now() + 90) { [weak self] in
      self?.requestingPermission = false
      reply.finish(self?.failure("timeout") ?? FlutterError(code: "timeout", message: nil, details: nil))
    }
    queue.async { [weak self] in
      guard let self = self else { return }
      let completion: (Bool, Error?) -> Void = { [weak self] _, error in
        DispatchQueue.main.async {
          guard let self = self else { return }
          self.requestingPermission = false
          reply.finish(error == nil ? self.permission() : self.failure("permission_unavailable"))
        }
      }
      if #available(iOS 17.0, *) { self.eventStore().requestFullAccessToEvents(completion: completion) }
      else { self.eventStore().requestAccess(to: .event, completion: completion) }
    }
  }

  private func read(_ result: @escaping FlutterResult,
                    operation: @escaping (EKEventStore) throws -> Any) {
    let reply = OnceReply(result)
    DispatchQueue.main.asyncAfter(deadline: .now() + 20) { [weak self] in
      reply.finish(self?.failure("timeout") ?? FlutterError(code: "timeout", message: nil, details: nil))
    }
    queue.async { [weak self] in
      guard let self = self else { return }
      let value: Any
      do {
        guard self.permission() == "granted" else { throw ReadFailure("permission_denied") }
        value = try operation(self.eventStore())
        guard self.permission() == "granted" else { throw ReadFailure("permission_denied") }
      } catch let error as ReadFailure {
        DispatchQueue.main.async { reply.finish(self.failure(error.code)) }; return
      } catch {
        DispatchQueue.main.async { reply.finish(self.failure("read_failed")) }; return
      }
      DispatchQueue.main.async { reply.finish(value) }
    }
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    sink = events
    if observer == nil {
      observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged,
        object: nil, queue: .main) { [weak self] _ in self?.sink?("changed") }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    if let observer = observer { NotificationCenter.default.removeObserver(observer) }
    observer = nil; sink = nil
    return nil
  }

  deinit { if let observer = observer { NotificationCenter.default.removeObserver(observer) } }
  private func failure(_ code: String) -> FlutterError { FlutterError(code: code, message: nil, details: nil) }
  private struct ReadFailure: Error { let code: String; init(_ code: String) { self.code = code } }
  private final class OnceReply {
    private var result: FlutterResult?
    init(_ result: @escaping FlutterResult) { self.result = result }
    // Every completion is serialized onto the main queue.
    func finish(_ value: Any?) { let callback = result; result = nil; callback?(value) }
  }
  private static func instant(_ date: Date) -> String {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter.string(from: date)
  }
  private static func civilDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone.current
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }
  private static func color(_ color: CGColor?) -> String {
    guard let color = color else { return "#a8b7a9" }
    var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
    UIColor(cgColor: color).getRed(&r, green: &g, blue: &b, alpha: &a)
    return String(format: "#%02x%02x%02x", Int(r * 255), Int(g * 255), Int(b * 255))
  }
}
