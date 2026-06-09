import Flutter
import Security
import UIKit
import WidgetKit

private typealias SuperhutSecTask = OpaquePointer

@_silgen_name("SecTaskCreateFromSelf")
private func superhutSecTaskCreateFromSelf(_ allocator: CFAllocator?) -> SuperhutSecTask?

@_silgen_name("SecTaskCopyValueForEntitlement")
private func superhutSecTaskCopyValueForEntitlement(
  _ task: SuperhutSecTask,
  _ entitlement: CFString,
  _ error: UnsafeMutablePointer<Unmanaged<CFError>?>?
) -> CFTypeRef?

@main
@objc class AppDelegate: FlutterAppDelegate {
  private let courseWidgetChannelName = "com.superhut.rice.superhut/coursetable_widget"
  private let widgetActionsChannelName = "com.superhut.rice.superhut/widget_actions"
  private let courseWidgetDefaultAppGroupIds = ["group.com.tune.superhut.coursewidget"]
  private let courseWidgetInfoAppGroupsKey = "SuperhutAppGroups"
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
        let didPersistStore = self.persistCourseWidgetStore(storeJson)
        let didPersistPayload = self.persistCourseWidgetPayload(payloadJson)
        self.reloadCourseWidgetTimelines()
        result(didPersistStore && didPersistPayload)
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

  private func persistCourseWidgetPayload(_ payloadJson: String?) -> Bool {
    guard let payloadJson, !payloadJson.isEmpty else {
      return true
    }

    return persistCourseWidgetValue(payloadJson, forKey: courseWidgetPayloadKey)
  }

  private func persistCourseWidgetStore(_ storeJson: String?) -> Bool {
    guard let storeJson, !storeJson.isEmpty else {
      return true
    }

    return persistCourseWidgetValue(storeJson, forKey: courseWidgetStoreKey)
  }

  private func persistCourseWidgetValue(_ value: String, forKey key: String) -> Bool {
    guard
      let appGroupId = resolveCourseWidgetAppGroupId(),
      let defaults = UserDefaults(suiteName: appGroupId)
    else {
      NSLog(
        "SuperHUT widget sync failed: no usable App Group. Check signed entitlements and provisioning profiles."
      )
      return false
    }

    defaults.set(value, forKey: key)
    let persisted = defaults.string(forKey: key) == value
    if !persisted {
      NSLog("SuperHUT widget sync failed: could not persist value for key %@.", key)
    }
    defaults.synchronize()
    return persisted
  }

  private func resolveCourseWidgetAppGroupId() -> String? {
    let candidates = candidateCourseWidgetAppGroupIds()
    for appGroupId in candidates {
      if FileManager.default.containerURL(
        forSecurityApplicationGroupIdentifier: appGroupId
      ) != nil {
        return appGroupId
      }
    }

    NSLog(
      "SuperHUT widget sync failed: no candidate App Group is accessible. candidates=%@",
      candidates.joined(separator: ", ")
    )
    return nil
  }

  private func candidateCourseWidgetAppGroupIds() -> [String] {
    var candidates = infoPlistCourseWidgetAppGroups()
    candidates.append(contentsOf: signedCourseWidgetAppGroups())
    candidates.append(contentsOf: courseWidgetDefaultAppGroupIds)
    return uniqueNonEmptyAppGroupIds(candidates)
  }

  private func infoPlistCourseWidgetAppGroups() -> [String] {
    if let groups = Bundle.main.object(forInfoDictionaryKey: courseWidgetInfoAppGroupsKey) as? [String] {
      return groups
    }
    if let group = Bundle.main.object(forInfoDictionaryKey: courseWidgetInfoAppGroupsKey) as? String {
      return [group]
    }
    return []
  }

  private func signedCourseWidgetAppGroups() -> [String] {
    var error: Unmanaged<CFError>?
    guard
      let task = superhutSecTaskCreateFromSelf(nil),
      let value = superhutSecTaskCopyValueForEntitlement(
        task,
        "com.apple.security.application-groups" as CFString,
        &error
      )
    else {
      return []
    }

    if let groups = value as? [String] {
      return groups
    }
    if let group = value as? String {
      return [group]
    }
    return []
  }

  private func uniqueNonEmptyAppGroupIds(_ values: [String]) -> [String] {
    var seen = Set<String>()
    var result = [String]()
    for value in values {
      let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
      if trimmed.isEmpty || seen.contains(trimmed) {
        continue
      }
      seen.insert(trimmed)
      result.append(trimmed)
    }
    return result
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
