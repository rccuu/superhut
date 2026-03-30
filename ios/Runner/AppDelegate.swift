import Flutter
import UIKit
import WidgetKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let courseWidgetChannelName = "com.superhut.rice.superhut/coursetable_widget"
  private let widgetActionsChannelName = "com.superhut.rice.superhut/widget_actions"
  private let courseWidgetAppGroupId = "group.com.tune.superhut.coursewidget"
  private let courseWidgetStoreKey = "course_widget_store"
  private let courseWidgetPayloadKey = "course_widget_payload"

  private var widgetActionsChannel: FlutterMethodChannel?
  private var initialWidgetAction: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    if let url = launchOptions?[.url] as? URL {
      initialWidgetAction = widgetAction(from: url)
    }
    GeneratedPluginRegistrant.register(with: self)
    let didLaunch = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )
    setupWidgetChannels()
    return didLaunch
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    if let action = widgetAction(from: url) {
      initialWidgetAction = action
      widgetActionsChannel?.invokeMethod("navigateToFunction", arguments: action)
      return true
    }

    return super.application(app, open: url, options: options)
  }

  private func setupWidgetChannels() {
    guard let controller = window?.rootViewController as? FlutterViewController else {
      return
    }

    let courseWidgetChannel = FlutterMethodChannel(
      name: courseWidgetChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    courseWidgetChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(false)
        return
      }

      switch call.method {
      case "syncCourseTableWidget":
        let arguments = call.arguments as? [String: Any]
        let payloadJson = arguments?["payloadJson"] as? String
        let storeJson = arguments?["storeJson"] as? String
        self.persistCourseWidgetStore(storeJson)
        self.persistCourseWidgetPayload(payloadJson)
        self.reloadCourseWidgetTimelines()
        result(true)
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    let widgetActionsChannel = FlutterMethodChannel(
      name: widgetActionsChannelName,
      binaryMessenger: controller.binaryMessenger
    )
    widgetActionsChannel.setMethodCallHandler { [weak self] call, result in
      guard let self else {
        result(nil)
        return
      }

      switch call.method {
      case "getInitialWidgetAction":
        result(self.consumeInitialWidgetAction())
      default:
        result(FlutterMethodNotImplemented)
      }
    }

    self.widgetActionsChannel = widgetActionsChannel
  }

  private func persistCourseWidgetPayload(_ payloadJson: String?) {
    guard let payloadJson, !payloadJson.isEmpty else {
      return
    }

    let defaults = UserDefaults(suiteName: courseWidgetAppGroupId)
    defaults?.set(payloadJson, forKey: courseWidgetPayloadKey)
    defaults?.synchronize()
  }

  private func persistCourseWidgetStore(_ storeJson: String?) {
    guard let storeJson, !storeJson.isEmpty else {
      return
    }

    let defaults = UserDefaults(suiteName: courseWidgetAppGroupId)
    defaults?.set(storeJson, forKey: courseWidgetStoreKey)
    defaults?.synchronize()
  }

  private func reloadCourseWidgetTimelines() {
    if #available(iOS 14.0, *) {
      WidgetCenter.shared.reloadAllTimelines()
    }
  }

  private func consumeInitialWidgetAction() -> String? {
    defer { initialWidgetAction = nil }
    return initialWidgetAction
  }

  private func widgetAction(from url: URL) -> String? {
    guard url.scheme == "superhut", url.host == "widget" else {
      return nil
    }

    let path = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
    if path == "course" {
      return "course"
    }
    return nil
  }
}
