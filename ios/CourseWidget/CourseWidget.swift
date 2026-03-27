import SwiftUI
import WidgetKit

private let courseWidgetAppGroupId = "group.com.tune.superhut.coursewidget"
private let courseWidgetPayloadKey = "course_widget_payload"

private struct CourseWidgetCourse: Decodable, Hashable, Identifiable {
  let name: String
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
  let isEmpty: Bool
  let updatedAt: String
  let courses: [CourseWidgetCourse]

  static let empty = CourseWidgetPayload(
    date: "",
    weekdayLabel: "",
    weekIndex: 0,
    isEmpty: true,
    updatedAt: "",
    courses: []
  )
}

private struct CourseWidgetEntry: TimelineEntry {
  let date: Date
  let payload: CourseWidgetPayload
}

private enum CourseWidgetStore {
  static func loadPayload() -> CourseWidgetPayload {
    let defaults = UserDefaults(suiteName: courseWidgetAppGroupId)
    guard
      let payloadString = defaults?.string(forKey: courseWidgetPayloadKey),
      let payloadData = payloadString.data(using: .utf8),
      let payload = try? JSONDecoder().decode(CourseWidgetPayload.self, from: payloadData)
    else {
      return .empty
    }
    return payload
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
        isEmpty: false,
        updatedAt: "",
        courses: [
          CourseWidgetCourse(
            name: "软件工程",
            location: "公共201",
            startSection: 1,
            endSection: 2,
            startTime: "08:00",
            sectionLabel: "1-2节"
          ),
          CourseWidgetCourse(
            name: "编译原理",
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
    completion(CourseWidgetEntry(date: Date(), payload: CourseWidgetStore.loadPayload()))
  }

  func getTimeline(in context: Context, completion: @escaping (Timeline<CourseWidgetEntry>) -> Void) {
    let entry = CourseWidgetEntry(date: Date(), payload: CourseWidgetStore.loadPayload())
    let nextRefresh = Calendar.current.date(byAdding: .minute, value: 30, to: Date()) ?? Date()
    completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
  }
}

private struct CourseWidgetEntryView: View {
  let entry: CourseWidgetEntry

  var body: some View {
    ZStack {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .fill(
          LinearGradient(
            colors: [
              Color(red: 0.93, green: 0.96, blue: 1.0),
              Color(red: 0.98, green: 0.99, blue: 1.0),
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )

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
          Text("今日无课")
            .font(.system(size: 14, weight: .medium))
            .foregroundColor(Color(red: 0.42, green: 0.47, blue: 0.56))
          Spacer(minLength: 0)
        } else {
          ForEach(Array(entry.payload.courses.prefix(3))) { course in
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
      .padding(14)
    }
    .widgetURL(URL(string: "superhut://widget/course"))
  }

  private var headerTitle: String {
    if entry.payload.weekdayLabel.isEmpty {
      return "今天课程"
    }
    return "今天 \(entry.payload.weekdayLabel)"
  }

  private var headerSubtitle: String {
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
    return "工大盒子课表"
  }

  private func courseMeta(_ course: CourseWidgetCourse) -> String {
    [course.startTime, course.sectionLabel, course.location]
      .filter { !$0.isEmpty }
      .joined(separator: " · ")
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
