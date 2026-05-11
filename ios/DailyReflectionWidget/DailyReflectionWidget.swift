import Foundation
import SwiftUI
import UIKit
import WidgetKit

private final class WidgetBundleMarker: NSObject {}

private let appGroupIdentifier = "group.com.jaralephillips.hawcalendar.shared"
private let storedSnapshotFileName = "daily-reflection-snapshot.v1.json"
private let widgetExtensionBundle = Bundle(for: WidgetBundleMarker.self)
private let widgetProfileGoldLight = Color(red: 247.0 / 255.0, green: 224.0 / 255.0, blue: 154.0 / 255.0)
private let widgetProfileGoldMid = Color(red: 232.0 / 255.0, green: 190.0 / 255.0, blue: 84.0 / 255.0)
private let widgetProfileGoldBase = Color(red: 202.0 / 255.0, green: 146.0 / 255.0, blue: 33.0 / 255.0)
private let widgetProfileGoldDeep = Color(red: 122.0 / 255.0, green: 83.0 / 255.0, blue: 16.0 / 255.0)
private let widgetProfileGoldText = Color(red: 241.0 / 255.0, green: 207.0 / 255.0, blue: 122.0 / 255.0)

private func widgetResourceURL(
    forResource name: String,
    withExtension fileExtension: String,
    subdirectory: String? = nil
) -> URL? {
    var bundles: [Bundle] = []
    var seenBundleURLs = Set<URL>()

    for bundle in [widgetExtensionBundle, Bundle.main] + Bundle.allBundles + Bundle.allFrameworks {
        if seenBundleURLs.insert(bundle.bundleURL).inserted {
            bundles.append(bundle)
        }
    }

    for bundle in bundles {
        if let url = bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        ) {
            return url
        }
    }

    let fileName = "\(name).\(fileExtension)"
    for bundle in bundles {
        let baseURLs = [bundle.resourceURL, Optional(bundle.bundleURL)].compactMap { $0 }
        for baseURL in baseURLs {
            let candidate = if let subdirectory {
                baseURL.appendingPathComponent(subdirectory).appendingPathComponent(fileName)
            } else {
                baseURL.appendingPathComponent(fileName)
            }

            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
        }
    }

    #if DEBUG
    NSLog(
        "DailyReflectionWidget resource lookup failed: %@.%@ in %@",
        name,
        fileExtension,
        subdirectory ?? "<root>"
    )
    #endif

    return nil
}

private struct WidgetBackdropFrame {
    let resourceName: String
    let minuteOfDay: Int
}

private struct WidgetBackdropBlend {
    let currentResourceName: String
    let nextResourceName: String
    let progress: Double
}

private let widgetBackdropFrames = [
    WidgetBackdropFrame(resourceName: "day_cycle_0030", minuteOfDay: 30),
    WidgetBackdropFrame(resourceName: "day_cycle_0330", minuteOfDay: 3 * 60 + 30),
    WidgetBackdropFrame(resourceName: "day_cycle_0515", minuteOfDay: 5 * 60 + 15),
    WidgetBackdropFrame(resourceName: "day_cycle_0600", minuteOfDay: 6 * 60),
    WidgetBackdropFrame(resourceName: "day_cycle_0645", minuteOfDay: 6 * 60 + 45),
    WidgetBackdropFrame(resourceName: "day_cycle_0800", minuteOfDay: 8 * 60),
    WidgetBackdropFrame(resourceName: "day_cycle_0930", minuteOfDay: 9 * 60 + 30),
    WidgetBackdropFrame(resourceName: "day_cycle_1100", minuteOfDay: 11 * 60),
    WidgetBackdropFrame(resourceName: "day_cycle_1215", minuteOfDay: 12 * 60 + 15),
    WidgetBackdropFrame(resourceName: "day_cycle_1330", minuteOfDay: 13 * 60 + 30),
    WidgetBackdropFrame(resourceName: "day_cycle_1445", minuteOfDay: 14 * 60 + 45),
    WidgetBackdropFrame(resourceName: "day_cycle_1600", minuteOfDay: 16 * 60),
    WidgetBackdropFrame(resourceName: "day_cycle_1715", minuteOfDay: 17 * 60 + 15),
    WidgetBackdropFrame(resourceName: "day_cycle_1830", minuteOfDay: 18 * 60 + 30),
    WidgetBackdropFrame(resourceName: "day_cycle_1915", minuteOfDay: 19 * 60 + 15),
    WidgetBackdropFrame(resourceName: "day_cycle_2015", minuteOfDay: 20 * 60 + 15)
]

private func widgetBackdropBlend(for date: Date, calendar: Calendar = .current) -> WidgetBackdropBlend {
    let parts = calendar.dateComponents([.hour, .minute, .second, .nanosecond], from: date)
    let minuteOfDay =
        Double((parts.hour ?? 0) * 60) +
        Double(parts.minute ?? 0) +
        (Double(parts.second ?? 0) / 60.0) +
        (Double(parts.nanosecond ?? 0) / 60_000_000_000.0)

    for index in widgetBackdropFrames.indices {
        let current = widgetBackdropFrames[index]
        let next = widgetBackdropFrames[(index + 1) % widgetBackdropFrames.count]
        let nextMinute = index == widgetBackdropFrames.count - 1
            ? Double(next.minuteOfDay + 1440)
            : Double(next.minuteOfDay)
        let wrappedMinute = index == widgetBackdropFrames.count - 1 &&
            minuteOfDay < Double(current.minuteOfDay)
            ? minuteOfDay + 1440
            : minuteOfDay

        if wrappedMinute >= Double(current.minuteOfDay), wrappedMinute < nextMinute {
            let span = nextMinute - Double(current.minuteOfDay)
            let progress = span <= 0 ? 0 : (wrappedMinute - Double(current.minuteOfDay)) / span
            return WidgetBackdropBlend(
                currentResourceName: current.resourceName,
                nextResourceName: next.resourceName,
                progress: min(max(progress, 0), 1)
            )
        }
    }

    return WidgetBackdropBlend(
        currentResourceName: widgetBackdropFrames.first?.resourceName ?? "day_cycle_0030",
        nextResourceName: widgetBackdropFrames.dropFirst().first?.resourceName ?? "day_cycle_0330",
        progress: 0
    )
}

private func displayWithoutKemeticYear(_ display: String) -> String {
    for marker in [", KYear ", " • KYear "] {
        if let markerRange = display.range(of: marker) {
            return String(display[..<markerRange.lowerBound])
        }
    }
    return display
}

struct ReflectionDaysFile: Decodable {
    let schema: Int
    let source: String
    let days: [String: ReflectionDay]
}

struct ReflectionDay: Decodable {
    let question: String
}

struct StoredDailyReflectionSnapshot: Decodable {
    struct KemeticDatePayload: Decodable {
        let display: String
        let dayKey: String
        let kYear: Int
    }

    struct IntentPayload: Decodable {
        let url: String
    }

    let schemaVersion: Int
    let kind: String
    let validForLocalDate: String
    let reflection: String
    let kemeticDate: KemeticDatePayload
    let intent: IntentPayload
}

struct DailyReflectionPayload {
    let validForLocalDate: String
    let reflection: String
    let kemeticDisplay: String
    let dayKey: String
    let kYear: Int
    let intentURL: URL
    let expiresAt: Date
    let isPlaceholder: Bool
    let backdropResourceName: String
    let nextBackdropResourceName: String
    let backdropBlendProgress: Double

    func withBackdrop(for date: Date) -> DailyReflectionPayload {
        let backdropBlend = widgetBackdropBlend(for: date)
        return DailyReflectionPayload(
            validForLocalDate: validForLocalDate,
            reflection: reflection,
            kemeticDisplay: kemeticDisplay,
            dayKey: dayKey,
            kYear: kYear,
            intentURL: intentURL,
            expiresAt: expiresAt,
            isPlaceholder: isPlaceholder,
            backdropResourceName: backdropBlend.currentResourceName,
            nextBackdropResourceName: backdropBlend.nextResourceName,
            backdropBlendProgress: backdropBlend.progress
        )
    }

    static func placeholder(now: Date = Date()) -> DailyReflectionPayload {
        let dateKey = ReflectionWidgetDataSource.localDateKey(for: now)
        let backdropBlend = widgetBackdropBlend(for: now)
        return DailyReflectionPayload(
            validForLocalDate: dateKey,
            reflection: "Open the planner to refresh today's reflection.",
            kemeticDisplay: "Daily reflection",
            dayKey: "",
            kYear: 0,
            intentURL: ReflectionWidgetDataSource.intentURL(for: dateKey),
            expiresAt: ReflectionWidgetDataSource.nextReloadDate(after: now),
            isPlaceholder: true,
            backdropResourceName: backdropBlend.currentResourceName,
            nextBackdropResourceName: backdropBlend.nextResourceName,
            backdropBlendProgress: backdropBlend.progress
        )
    }
}

struct DailyReflectionEntry: TimelineEntry {
    let date: Date
    let payload: DailyReflectionPayload
}

struct ReflectionWidgetDataSource {
    static func payload(now: Date = Date(), preview: Bool = false) -> DailyReflectionPayload {
        let backdropBlend = widgetBackdropBlend(for: now)
        if preview {
            return DailyReflectionPayload(
                validForLocalDate: "2026-05-09",
                reflection: "\"What survived this labor in good form?\"",
                kemeticDisplay: "Paopi 21",
                dayKey: "paophi_21_3",
                kYear: 2,
                intentURL: intentURL(for: "2026-05-09"),
                expiresAt: nextReloadDate(after: now),
                isPlaceholder: false,
                backdropResourceName: backdropBlend.currentResourceName,
                nextBackdropResourceName: backdropBlend.nextResourceName,
                backdropBlendProgress: backdropBlend.progress
            )
        }

        let dateKey = localDateKey(for: now)
        if let stored = loadStoredSnapshot(for: dateKey, now: now) {
            return stored
        }

        guard let kemetic = kemeticDate(for: now),
              let question = loadQuestion(dayKey: kemetic.dayKey) else {
            #if DEBUG
            NSLog(
                "DailyReflectionWidget payload fallback date=%@ dayKey=%@",
                dateKey,
                kemeticDate(for: now)?.dayKey ?? "<nil>"
            )
            #endif
            return .placeholder(now: now)
        }

        #if DEBUG
        NSLog(
            "DailyReflectionWidget payload resolved date=%@ dayKey=%@ backdrop=%@ next=%@ progress=%.3f",
            dateKey,
            kemetic.dayKey,
            backdropBlend.currentResourceName,
            backdropBlend.nextResourceName,
            backdropBlend.progress
        )
        #endif

        return DailyReflectionPayload(
            validForLocalDate: dateKey,
            reflection: question,
            kemeticDisplay: kemetic.display,
            dayKey: kemetic.dayKey,
            kYear: kemetic.kYear,
            intentURL: intentURL(for: dateKey),
            expiresAt: nextReloadDate(after: now),
            isPlaceholder: false,
            backdropResourceName: backdropBlend.currentResourceName,
            nextBackdropResourceName: backdropBlend.nextResourceName,
            backdropBlendProgress: backdropBlend.progress
        )
    }

    static func localDateKey(for date: Date, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            parts.year ?? 1970,
            parts.month ?? 1,
            parts.day ?? 1
        )
    }

    static func nextReloadDate(after date: Date, calendar: Calendar = .current) -> Date {
        let startOfToday = calendar.startOfDay(for: date)
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.date(byAdding: .minute, value: 5, to: tomorrow)
            ?? tomorrow.addingTimeInterval(5 * 60)
    }

    static func timelineEntryDates(startingAt date: Date, calendar: Calendar = .current) -> [Date] {
        let reloadDate = nextReloadDate(after: date, calendar: calendar)
        var dates = [date]
        let timelineMinutes = backdropTimelineMinutes()
        let startOfToday = calendar.startOfDay(for: date)

        for dayOffset in 0...1 {
            guard let dayStart = calendar.date(byAdding: .day, value: dayOffset, to: startOfToday) else {
                continue
            }
            for minute in timelineMinutes {
                guard let candidate = calendar.date(byAdding: .minute, value: minute, to: dayStart),
                      candidate > date,
                      candidate < reloadDate else {
                    continue
                }
                dates.append(candidate)
            }
        }

        dates.append(reloadDate)
        return dates
            .sorted()
            .reduce(into: [Date]()) { uniqueDates, candidate in
                guard let previous = uniqueDates.last else {
                    uniqueDates.append(candidate)
                    return
                }
                if abs(candidate.timeIntervalSince(previous)) >= 1 {
                    uniqueDates.append(candidate)
                }
            }
    }

    static func nextBackdropRefreshDate(after date: Date, calendar: Calendar = .current) -> Date {
        let currentMinute =
            calendar.component(.hour, from: date) * 60 +
            calendar.component(.minute, from: date)
        let currentSecond = calendar.component(.second, from: date)
        let timelineMinutes = backdropTimelineMinutes()
        let startOfToday = calendar.startOfDay(for: date)

        for minute in timelineMinutes where minute > currentMinute || (minute == currentMinute && currentSecond == 0) {
            if let candidate = calendar.date(byAdding: .minute, value: minute, to: startOfToday),
               candidate > date {
                return candidate
            }
        }

        let firstMinuteTomorrow = timelineMinutes.first ?? 30
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday)
            ?? date.addingTimeInterval(24 * 60 * 60)
        return calendar.date(byAdding: .minute, value: firstMinuteTomorrow, to: tomorrow)
            ?? tomorrow.addingTimeInterval(TimeInterval(firstMinuteTomorrow * 60))
    }

    private static func backdropTimelineMinutes() -> [Int] {
        var minutes = Set<Int>()

        for index in widgetBackdropFrames.indices {
            let current = widgetBackdropFrames[index]
            let next = widgetBackdropFrames[(index + 1) % widgetBackdropFrames.count]
            let nextMinute = index == widgetBackdropFrames.count - 1
                ? next.minuteOfDay + 1440
                : next.minuteOfDay
            let midpoint = Int(round((Double(current.minuteOfDay) + Double(nextMinute)) / 2.0)) % 1440

            minutes.insert(current.minuteOfDay)
            minutes.insert(midpoint)
        }

        return minutes.sorted()
    }

    static func intentURL(for dateKey: String) -> URL {
        var components = URLComponents()
        #if targetEnvironment(simulator)
        components.scheme = "maat"
        components.host = "rhythm"
        components.path = "/today"
        #else
        components.scheme = "https"
        components.host = "maat.app"
        components.path = "/rhythm/today"
        #endif
        components.queryItems = [
            URLQueryItem(name: "openDayCard", value: "1"),
            URLQueryItem(name: "source", value: "ios_widget"),
            URLQueryItem(name: "date", value: dateKey),
            URLQueryItem(name: "tz", value: TimeZone.current.identifier)
        ]
        return components.url ?? URL(string: "https://maat.app/rhythm/today?openDayCard=1&source=ios_widget")!
    }

    private static func loadStoredSnapshot(for dateKey: String, now: Date) -> DailyReflectionPayload? {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: appGroupIdentifier
        ) else {
            return nil
        }

        let snapshotURL = container.appendingPathComponent(storedSnapshotFileName)
        guard let data = try? Data(contentsOf: snapshotURL),
              let snapshot = try? JSONDecoder().decode(StoredDailyReflectionSnapshot.self, from: data),
              snapshot.schemaVersion == 1,
              snapshot.kind == "daily_reflection",
              snapshot.validForLocalDate == dateKey,
              let url = URL(string: snapshot.intent.url) else {
            return nil
        }

        let backdropBlend = widgetBackdropBlend(for: now)
        return DailyReflectionPayload(
            validForLocalDate: snapshot.validForLocalDate,
            reflection: snapshot.reflection,
            kemeticDisplay: displayWithoutKemeticYear(snapshot.kemeticDate.display),
            dayKey: snapshot.kemeticDate.dayKey,
            kYear: snapshot.kemeticDate.kYear,
            intentURL: url,
            expiresAt: nextReloadDate(after: now),
            isPlaceholder: false,
            backdropResourceName: backdropBlend.currentResourceName,
            nextBackdropResourceName: backdropBlend.nextResourceName,
            backdropBlendProgress: backdropBlend.progress
        )
    }

    private static func loadQuestion(dayKey: String) -> String? {
        guard let file = widgetResourceURL(forResource: "daily-reflection-days", withExtension: "json"),
              let data = try? Data(contentsOf: file),
              let daysFile = try? JSONDecoder().decode(ReflectionDaysFile.self, from: data),
              daysFile.schema == 1 else {
            return nil
        }
        return daysFile.days[dayKey]?.question
    }

    private static func kemeticDate(for date: Date) -> (dayKey: String, display: String, kYear: Int)? {
        let localStart = Calendar.current.startOfDay(for: date)
        let utcDate = utcDateOnly(from: localStart)
        var remainingDays = daysBetween(epochUTC, utcDate)
        var kYear = 1
        var kYearStart = epochUTC

        if remainingDays >= 0 {
            while true {
                let yearLength = kemeticYearLength(startingAt: kYearStart)
                if remainingDays < yearLength {
                    break
                }
                remainingDays -= yearLength
                kYear += 1
                kYearStart = addDays(yearLength, to: kYearStart)
            }
        } else {
            while remainingDays < 0 {
                let previousStart = previousKemeticYearStart(before: kYearStart)
                let previousLength = kemeticYearLength(startingAt: previousStart)
                remainingDays += previousLength
                kYear -= 1
                kYearStart = previousStart
            }
        }

        let kMonth: Int
        let kDay: Int
        if remainingDays < 360 {
            kMonth = (remainingDays / 30) + 1
            kDay = (remainingDays % 30) + 1
        } else {
            kMonth = 13
            kDay = remainingDays - 360 + 1
        }

        let dayKey = kemeticDayKey(month: kMonth, day: kDay)
        let display: String
        if kMonth == 13 {
            display = "Heriu Renpet \(kDay)"
        } else {
            display = "\(displayMonthName(for: kMonth)) \(kDay)"
        }
        return (dayKey, display, kYear)
    }

    private static func kemeticDayKey(month: Int, day: Int) -> String {
        let decan = ((day - 1) / 10) + 1
        let monthKey = monthKeyOverrides[month] ?? monthKeys[month] ?? "unknown"
        return "\(monthKey)_\(day)_\(decan)"
    }

    private static func displayMonthName(for month: Int) -> String {
        return displayMonthNames[month] ?? "Kemetic Day"
    }

    private static let epochUTC: Date = {
        var components = DateComponents()
        components.calendar = utcCalendar
        components.timeZone = utcCalendar.timeZone
        components.year = 2025
        components.month = 3
        components.day = 20
        return components.date!
    }()

    private static let utcCalendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    private static let monthKeyOverrides: [Int: String] = [
        2: "paophi",
        5: "sefbedet",
        10: "henti",
        11: "ipt",
        12: "mswtRa"
    ]

    private static let monthKeys: [Int: String] = [
        1: "thoth",
        2: "paopi",
        3: "hathor",
        4: "kaherka",
        5: "shefbedet",
        6: "rekhwer",
        7: "rekhnedjes",
        8: "renwet",
        9: "hnsw",
        10: "hentihet",
        11: "paipi",
        12: "mesutra",
        13: "epagomenal"
    ]

    private static let displayMonthNames: [Int: String] = [
        1: "Thoth",
        2: "Paopi",
        3: "Hathor",
        4: "Ka-ḥer-Ka",
        5: "Šef-Bedet",
        6: "Rekh-Wer",
        7: "Rekh-Nedjes",
        8: "Renwet",
        9: "Hnsw",
        10: "Ḥenti-ḥet",
        11: "Pa-Ipi",
        12: "Mesut-Ra"
    ]

    private static func utcDateOnly(from date: Date) -> Date {
        let parts = utcCalendar.dateComponents([.year, .month, .day], from: date)
        return utcCalendar.date(from: parts)!
    }

    private static func addDays(_ days: Int, to date: Date) -> Date {
        utcCalendar.date(byAdding: .day, value: days, to: date)!
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Int {
        utcCalendar.dateComponents([.day], from: utcDateOnly(from: start), to: utcDateOnly(from: end)).day ?? 0
    }

    private static func kemeticYearLength(startingAt start: Date) -> Int {
        let epagomenalStart = addDays(360, to: start)
        let gregorianYear = utcCalendar.component(.year, from: epagomenalStart)
        return isGregorianLeapYear(gregorianYear) ? 366 : 365
    }

    private static func previousKemeticYearStart(before start: Date) -> Date {
        let guess = addDays(-365, to: start)
        let previousLength = kemeticYearLength(startingAt: guess)
        return addDays(-previousLength, to: start)
    }

    private static func isGregorianLeapYear(_ year: Int) -> Bool {
        if year % 4 != 0 {
            return false
        }
        if year % 100 == 0 && year % 400 != 0 {
            return false
        }
        return true
    }
}

struct DailyReflectionProvider: TimelineProvider {
    func placeholder(in context: Context) -> DailyReflectionEntry {
        DailyReflectionEntry(date: Date(), payload: .placeholder())
    }

    func getSnapshot(in context: Context, completion: @escaping (DailyReflectionEntry) -> Void) {
        let payload = ReflectionWidgetDataSource.payload(preview: context.isPreview)
        completion(DailyReflectionEntry(date: Date(), payload: payload))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<DailyReflectionEntry>) -> Void) {
        let now = Date()
        let payload = ReflectionWidgetDataSource.payload(now: now).withBackdrop(for: now)
        let entry = DailyReflectionEntry(date: now, payload: payload)
        let reloadDate = min(
            payload.expiresAt,
            ReflectionWidgetDataSource.nextBackdropRefreshDate(after: now)
        )
        let entries = [entry]
        completion(Timeline(entries: entries, policy: .after(reloadDate)))
    }
}

struct WidgetBackdropImage: View {
    let resourceName: String

    var body: some View {
        GeometryReader { proxy in
            if let image = imageResource(named: resourceName) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipped()
            } else {
                LinearGradient(
                    colors: [
                        Color(red: 0.02, green: 0.02, blue: 0.02),
                        Color(red: 0.15, green: 0.11, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
    }

    private func imageResource(named name: String) -> UIImage? {
        guard let url = widgetResourceURL(forResource: name, withExtension: "png", subdirectory: "DayCycle") else {
            return nil
        }
        return UIImage(contentsOfFile: url.path)
    }
}

struct WidgetDayCycleBackdrop: View {
    let currentResourceName: String
    let nextResourceName: String
    let progress: Double

    var body: some View {
        ZStack {
            WidgetBackdropImage(resourceName: currentResourceName)

            if progress > 0.001 {
                WidgetBackdropImage(resourceName: nextResourceName)
                    .opacity(progress)
            }
        }
        .opacity(0.9)
    }
}

struct DailyReflectionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DailyReflectionEntry

    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: family == .systemSmall ? 6 : 8) {
                Text("Daily Reflection")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .lineLimit(1)

                Text(entry.payload.reflection)
                    .font(family == .systemSmall ? .callout : .title3)
                    .foregroundStyle(widgetProfileGoldText)
                    .lineLimit(family == .systemSmall ? 4 : 5)
                    .minimumScaleFactor(0.78)
                    .fixedSize(horizontal: false, vertical: true)
                    .shadow(color: .black.opacity(0.75), radius: 2, x: 0, y: 1)

                Spacer(minLength: 0)

                Text(entry.payload.kemeticDisplay)
                    .font(.caption)
                    .foregroundStyle(widgetProfileGoldText.opacity(0.72))
                    .shadow(color: .black.opacity(0.7), radius: 2, x: 0, y: 1)
                    .lineLimit(1)
            }
            .padding(family == .systemSmall ? 16 : 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .containerBackground(for: .widget) {
            WidgetDayCycleBackdrop(
                currentResourceName: entry.payload.backdropResourceName,
                nextResourceName: entry.payload.nextBackdropResourceName,
                progress: entry.payload.backdropBlendProgress
            )
                .overlay {
                    LinearGradient(
                        colors: [
                            .black.opacity(0.80),
                            .black.opacity(0.58),
                            .black.opacity(0.78)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .overlay {
            RoundedRectangle(cornerRadius: family == .systemSmall ? 24 : 30, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            widgetProfileGoldBase.opacity(0.95),
                            widgetProfileGoldLight.opacity(0.95),
                            widgetProfileGoldMid.opacity(0.85),
                            widgetProfileGoldDeep.opacity(0.75)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.8
                )
        }
        .widgetURL(entry.payload.intentURL)
        .unredacted()
    }
}

struct DailyReflectionWidget: Widget {
    let kind = "DailyReflectionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DailyReflectionProvider()) { entry in
            DailyReflectionWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Reflection")
        .description("Shows today's reflection and opens the planner.")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

@main
struct DailyReflectionWidgetBundle: WidgetBundle {
    var body: some Widget {
        DailyReflectionWidget()
    }
}
