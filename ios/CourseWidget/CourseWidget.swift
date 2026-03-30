import SwiftUI
import WidgetKit

private let courseWidgetAppGroupId = "group.com.tune.superhut.coursewidget"
private let courseWidgetStoreKey = "course_widget_store"

private struct CourseWidgetCourse: Decodable, Hashable, Identifiable {
  let name: String
  let meta: String?
  let location: String
  let startSection: Int
  let endSection: Int
  let startTime: String
  let sectionLabel: String

  var id: String {
    "\(startSection)-\(endSection)-\(name)-\(location)"
  }
}

private struct CourseWidgetPayload: Decodable {
  let date: String
  let weekdayLabel: String
  let weekIndex: Int
  let status: String?
  let headerTitle: String?
  let headerSubtitle: String?
  let emptyText: String?
  let isEmpty: Bool
  let updatedAt: String
  let courses: [CourseWidgetCourse]

  static let empty = CourseWidgetPayload(
    date: "",
    weekdayLabel: "",
    weekIndex: 0,
    status: "empty",
    headerTitle: "当前暂无课表",
    headerSubtitle: "同步或导入后显示课程",
    emptyText: "同步或导入后显示课程",
    isEmpty: true,
    updatedAt: "",
    courses: []
  )
}

private struct CourseWidgetStoreData: Decodable {
  let updatedAt: String
  let days: [String: CourseWidgetPayload]
  let dayCourses: [String: [CourseWidgetCourse]]?
}

private struct CourseWidgetEntry: TimelineEntry {
  let date: Date
  let payload: CourseWidgetPayload
}

private enum CourseWidgetRepository {
  static func loadStore() -> CourseWidgetStoreData? {
    let defaults = UserDefaults(suiteName: courseWidgetAppGroupId)
    if
      let storeString = defaults?.string(forKey: courseWidgetStoreKey),
      let storeData = storeString.data(using: .utf8),
      let store = try? JSONDecoder().decode(CourseWidgetStoreData.self, from: storeData)
    {
      return store
    }
    return nil
  }

  static func loadPayload(at date: Date = Date()) -> CourseWidgetPayload {
    if let store = loadStore() {
      return relevantPayload(from: store, now: date)
    }

    // 新链路以按天 store 为唯一真源，避免旧 payload 残留把过期文案继续带出来。
    return emptyPayload(for: date, updatedAt: "")
  }

  private static func emptyPayload(for date: Date, updatedAt: String) -> CourseWidgetPayload {
    return CourseWidgetPayload(
      date: dateKey(from: date),
      weekdayLabel: weekdayLabel(from: date),
      weekIndex: 0,
      status: "empty",
      headerTitle: "当前暂无课表",
      headerSubtitle: "同步或导入后显示课程",
      emptyText: "同步或导入后显示课程",
      isEmpty: true,
      updatedAt: updatedAt,
      courses: []
    )
  }

  static func buildTimelineEntries(from store: CourseWidgetStoreData, now: Date) -> [CourseWidgetEntry] {
    var entries = [CourseWidgetEntry(date: now, payload: relevantPayload(from: store, now: now))]
    let refreshDates = nextRefreshDates(from: store, now: now)
    entries.append(
      contentsOf: refreshDates.map { refreshDate in
        CourseWidgetEntry(
          date: refreshDate,
          payload: relevantPayload(from: store, now: refreshDate)
        )
      }
    )
    return entries
  }

  private static func dateKey(from date: Date) -> String {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.string(from: date)
  }

  private static func parseDateKey(_ value: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.dateFormat = "yyyy-MM-dd"
    return formatter.date(from: value)
  }

  private static func weekdayLabel(from date: Date) -> String {
    let labels = ["周日", "周一", "周二", "周三", "周四", "周五", "周六"]
    let weekday = Calendar.current.component(.weekday, from: date)
    return labels[max(0, min(labels.count - 1, weekday - 1))]
  }

  private static func relevantPayload(from store: CourseWidgetStoreData, now: Date) -> CourseWidgetPayload {
    let today = Calendar.current.startOfDay(for: now)
    let todayKey = dateKey(from: today)
    let updatedAt = store.updatedAt

    let todayCourses = remainingCourses(on: today, now: now, from: store)
    if !todayCourses.isEmpty {
      let weekIndex = weekIndex(for: today, from: store)
      return CourseWidgetPayload(
        date: todayKey,
        weekdayLabel: weekdayLabel(for: today, from: store),
        weekIndex: weekIndex,
        status: "today_courses",
        headerTitle: "今天课程",
        headerSubtitle: composeWeekSubtitle(date: today, weekIndex: weekIndex),
        emptyText: "今日暂无课程",
        isEmpty: false,
        updatedAt: updatedAt,
        courses: Array(todayCourses.prefix(2))
      )
    }

    guard let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today) else {
      return emptyPayload(for: today, updatedAt: updatedAt)
    }

    let tomorrowCourses = actualCourses(on: tomorrow, from: store)
    let todayWeekIndex = weekIndex(for: today, from: store)

    if Calendar.current.component(.weekday, from: today) == 1, !tomorrowCourses.isEmpty {
      let mondayWeekIndex = weekIndex(for: tomorrow, from: store)
      return CourseWidgetPayload(
        date: todayKey,
        weekdayLabel: weekdayLabel(for: today, from: store),
        weekIndex: todayWeekIndex,
        status: "next_monday",
        headerTitle: "周一有课",
        headerSubtitle: mondayWeekIndex > 0 ? "下周第\(mondayWeekIndex)周" : "明天上午别睡过",
        emptyText: "周一有课",
        isEmpty: false,
        updatedAt: updatedAt,
        courses: Array(tomorrowCourses.prefix(2))
      )
    }

    if !tomorrowCourses.isEmpty {
      let tomorrowWeekIndex = weekIndex(for: tomorrow, from: store)
      return CourseWidgetPayload(
        date: todayKey,
        weekdayLabel: weekdayLabel(for: today, from: store),
        weekIndex: todayWeekIndex,
        status: "tomorrow_courses",
        headerTitle: "明天有课",
        headerSubtitle: composeWeekSubtitle(date: tomorrow, weekIndex: tomorrowWeekIndex),
        emptyText: "明天有课",
        isEmpty: false,
        updatedAt: updatedAt,
        courses: Array(tomorrowCourses.prefix(2))
      )
    }

    if let nextCourseDate = nextCourseDate(after: today, from: store) {
      let nextCourses = actualCourses(on: nextCourseDate, from: store)
      let nextWeekIndex = weekIndex(for: nextCourseDate, from: store)
      let sameWeek = startOfMonday(for: nextCourseDate) == startOfMonday(for: today)
      return CourseWidgetPayload(
        date: todayKey,
        weekdayLabel: weekdayLabel(for: today, from: store),
        weekIndex: todayWeekIndex,
        status: "next_course",
        headerTitle: "下次课程",
        headerSubtitle: sameWeek
          ? composeWeekSubtitle(date: nextCourseDate, weekIndex: nextWeekIndex)
          : composeWeekSubtitle(date: nextCourseDate, weekIndex: nextWeekIndex, prefix: "本周无课"),
        emptyText: "下次课程",
        isEmpty: false,
        updatedAt: updatedAt,
        courses: Array(nextCourses.prefix(2))
      )
    }

    return emptyPayload(for: today, updatedAt: updatedAt)
  }

  private static func nextRefreshDates(from store: CourseWidgetStoreData, now: Date) -> [Date] {
    let today = Calendar.current.startOfDay(for: now)
    var dates = [Date]()

    for course in remainingCourses(on: today, now: now, from: store) {
      guard let endAt = courseEndTime(for: course, on: today), endAt > now else {
        continue
      }
      dates.append(endAt)
    }

    for offset in 1...7 {
      guard let nextDay = Calendar.current.date(byAdding: .day, value: offset, to: today) else {
        continue
      }
      dates.append(nextDay)
    }

    var seen = Set<Int>()
    return dates
      .filter { $0 > now }
      .sorted()
      .filter { date in
        let key = Int(date.timeIntervalSince1970)
        return seen.insert(key).inserted
      }
  }

  private static func actualCourses(on date: Date, from store: CourseWidgetStoreData) -> [CourseWidgetCourse] {
    let key = dateKey(from: date)
    if let dayCourses = store.dayCourses?[key], !dayCourses.isEmpty {
      return dayCourses.sorted { $0.startSection < $1.startSection }
    }

    if let payload = store.days[key], payload.status == "today_courses", !payload.courses.isEmpty {
      return payload.courses.sorted { $0.startSection < $1.startSection }
    }

    return []
  }

  private static func remainingCourses(
    on date: Date,
    now: Date,
    from store: CourseWidgetStoreData
  ) -> [CourseWidgetCourse] {
    let courses = actualCourses(on: date, from: store)
    let today = Calendar.current.startOfDay(for: now)
    if today != Calendar.current.startOfDay(for: date) {
      return courses
    }

    return courses.filter { course in
      guard let endAt = courseEndTime(for: course, on: date) else {
        return true
      }
      return endAt > now
    }
  }

  private static func nextCourseDate(after currentDate: Date, from store: CourseWidgetStoreData) -> Date? {
    let actualKeys = actualCourseDateKeys(from: store).sorted()
    for key in actualKeys {
      guard let date = parseDateKey(key) else {
        continue
      }
      if date > currentDate {
        return date
      }
    }
    return nil
  }

  private static func actualCourseDateKeys(from store: CourseWidgetStoreData) -> Set<String> {
    if let dayCourses = store.dayCourses, !dayCourses.isEmpty {
      return Set(dayCourses.keys)
    }

    return Set(
      store.days.compactMap { key, payload in
        payload.status == "today_courses" && !payload.courses.isEmpty ? key : nil
      }
    )
  }

  private static func weekIndex(for date: Date, from store: CourseWidgetStoreData) -> Int {
    store.days[dateKey(from: date)]?.weekIndex ?? 0
  }

  private static func weekdayLabel(for date: Date, from store: CourseWidgetStoreData) -> String {
    let key = dateKey(from: date)
    if let payload = store.days[key], !payload.weekdayLabel.isEmpty {
      return payload.weekdayLabel
    }
    return weekdayLabel(from: date)
  }

  private static func composeWeekSubtitle(date: Date, weekIndex: Int, prefix: String? = nil) -> String {
    var parts = [String]()
    if let prefix, !prefix.isEmpty {
      parts.append(prefix)
    }
    parts.append(weekdayLabel(from: date))
    if weekIndex > 0 {
      parts.append("第\(weekIndex)周")
    }
    return parts.joined(separator: " · ")
  }

  private static func startOfMonday(for date: Date) -> Date {
    var calendar = Calendar(identifier: .gregorian)
    calendar.firstWeekday = 2
    let weekday = calendar.component(.weekday, from: date)
    let offset = (weekday + 5) % 7
    return calendar.startOfDay(
      for: calendar.date(byAdding: .day, value: -offset, to: date) ?? date
    )
  }

  private static func courseEndTime(for course: CourseWidgetCourse, on date: Date) -> Date? {
    let section = course.endSection > 0 ? course.endSection : course.startSection
    guard let clock = sectionEndTime(for: section) else {
      return nil
    }
    return dateTime(on: date, clock: clock)
  }

  private static func sectionEndTime(for section: Int) -> String? {
    switch section {
    case 1: return "08:45"
    case 2: return "09:40"
    case 3: return "10:45"
    case 4: return "11:40"
    case 5: return "14:45"
    case 6: return "15:40"
    case 7: return "16:45"
    case 8: return "17:40"
    case 9: return "19:45"
    case 10: return "20:40"
    default: return nil
    }
  }

  private static func dateTime(on date: Date, clock: String) -> Date? {
    let parts = clock.split(separator: ":")
    guard parts.count == 2,
          let hour = Int(parts[0]),
          let minute = Int(parts[1]) else {
      return nil
    }
    return Calendar.current.date(
      bySettingHour: hour,
      minute: minute,
      second: 0,
      of: date
    )
  }

}

private struct Provider: TimelineProvider {
  func placeholder(in context: Context) -> CourseWidgetEntry {
    CourseWidgetEntry(
      date: Date(),
      payload: CourseWidgetPayload(
        date: "2026-03-27",
        weekdayLabel: "周五",
        weekIndex: 3,
        status: "today_courses",
        headerTitle: "今天课程",
        headerSubtitle: "周五 · 第3周",
        emptyText: "今日暂无课程",
        isEmpty: false,
        updatedAt: "",
        courses: [
          CourseWidgetCourse(
            name: "08:00 软件工程",
            meta: "公共201",
            location: "公共201",
            startSection: 1,
            endSection: 2,
            startTime: "08:00",
            sectionLabel: "1-2节"
          ),
          CourseWidgetCourse(
            name: "10:00 编译原理",
            meta: "公共202",
            location: "公共202",
            startSection: 3,
            endSection: 4,
            startTime: "10:00",
            sectionLabel: "3-4节"
          ),
        ]
      )
    )
  }

  func getSnapshot(in context: Context, completion: @escaping (CourseWidgetEntry) -> Void) {
    completion(CourseWidgetEntry(date: Date(), payload: CourseWidgetRepository.loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CourseWidgetEntry>) -> Void) {
    let now = Date()
    if let store = CourseWidgetRepository.loadStore() {
      let entries = CourseWidgetRepository.buildTimelineEntries(from: store, now: now)
      completion(Timeline(entries: entries, policy: .atEnd))
      return
    }

    let entry = CourseWidgetEntry(date: now, payload: CourseWidgetRepository.loadPayload(at: now))
    let nextRefresh = Calendar.current.startOfDay(
      for: Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now
    )
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }
}

private struct CourseWidgetEntryView: View {
  let entry: CourseWidgetEntry

  var body: some View {
    content
      .padding(14)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
      .courseWidgetBackground()
    .widgetURL(URL(string: "superhut://widget/course"))
  }

  private var content: some View {
    VStack(alignment: .leading, spacing: 10) {
      VStack(alignment: .leading, spacing: 4) {
        Text(headerTitle)
          .font(.system(size: 17, weight: .semibold))
          .foregroundColor(Color(red: 0.15, green: 0.22, blue: 0.38))

        Text(headerSubtitle)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.53))
      }

      if entry.payload.isEmpty || entry.payload.courses.isEmpty {
        Spacer(minLength: 0)
        Text(emptyStateText)
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(Color(red: 0.42, green: 0.47, blue: 0.56))
        Spacer(minLength: 0)
      } else {
        ForEach(Array(entry.payload.courses.prefix(2))) { course in
          VStack(alignment: .leading, spacing: 2) {
            Text(course.name)
              .font(.system(size: 13, weight: .semibold))
              .foregroundColor(Color(red: 0.14, green: 0.18, blue: 0.25))
              .lineLimit(1)

            Text(courseMeta(course))
              .font(.system(size: 11))
              .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.53))
              .lineLimit(1)
          }
          .padding(.horizontal, 10)
          .padding(.vertical, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
              .fill(Color.white.opacity(0.82))
          )
        }
        Spacer(minLength: 0)
      }
    }
  }

  private var headerTitle: String {
    if let title = entry.payload.headerTitle, !title.isEmpty {
      return title
    }
    if entry.payload.weekdayLabel.isEmpty {
      return "今天课程"
    }
    return "今天 \(entry.payload.weekdayLabel)"
  }

  private var headerSubtitle: String {
    if let subtitle = entry.payload.headerSubtitle, !subtitle.isEmpty {
      return subtitle
    }
    let shortDate: String
    if entry.payload.date.count >= 10 {
      shortDate = entry.payload.date.dropFirst(5).replacingOccurrences(of: "-", with: "/")
    } else {
      shortDate = ""
    }

    if entry.payload.weekIndex > 0, !shortDate.isEmpty {
      return "\(shortDate) · 第\(entry.payload.weekIndex)周"
    }
    if entry.payload.weekIndex > 0 {
      return "第\(entry.payload.weekIndex)周"
    }
    if !shortDate.isEmpty {
      return shortDate
    }
    return ""
  }

  private var emptyStateText: String {
    if let text = entry.payload.emptyText, !text.isEmpty {
      return text
    }
    return "今日无课"
  }

  private func courseMeta(_ course: CourseWidgetCourse) -> String {
    if let meta = course.meta, !meta.isEmpty {
      return meta
    }
    return [course.startTime, course.sectionLabel, course.location]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
  }
}

private struct CourseWidgetBackgroundView: View {
  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.93, green: 0.96, blue: 1.0),
          Color(red: 0.98, green: 0.99, blue: 1.0),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )

      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.45), lineWidth: 1)
        .padding(1)
    }
  }
}

private extension View {
  @ViewBuilder
  func courseWidgetBackground() -> some View {
    if #available(iOSApplicationExtension 17.0, *) {
      containerBackground(for: .widget) {
        CourseWidgetBackgroundView()
      }
    } else {
      background(CourseWidgetBackgroundView())
    }
  }
}

struct CourseWidget: Widget {
  private let kind = "CourseWidget"

  var body: some WidgetConfiguration {
    StaticConfiguration(kind: kind, provider: Provider()) { entry in
      CourseWidgetEntryView(entry: entry)
    }
    .configurationDisplayName("今日课表")
    .description("在桌面查看今天的课程安排。")
    .supportedFamilies([.systemMedium, .systemLarge])
  }
}
