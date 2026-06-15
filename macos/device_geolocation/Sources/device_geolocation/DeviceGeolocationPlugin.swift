import Cocoa
import CoreLocation
import FlutterMacOS

public class DeviceGeolocationPlugin: NSObject, FlutterPlugin {
  private let locationManager = CLLocationManager()
  private let geolocationDelegate = GeolocationDelegate()
  private let positionStreamHandler: PositionStreamHandler
  private let serviceStreamHandler: ServiceStreamHandler
  private let permissionStreamHandler: PermissionStreamHandler

  override init() {
    self.positionStreamHandler = PositionStreamHandler(
      delegate: geolocationDelegate, locationManager: locationManager)
    self.serviceStreamHandler = ServiceStreamHandler(delegate: geolocationDelegate)
    self.permissionStreamHandler = PermissionStreamHandler(delegate: geolocationDelegate)
    super.init()
    locationManager.delegate = geolocationDelegate
    geolocationDelegate.manager = locationManager
  }

  public static func register(with registrar: FlutterPluginRegistrar) {
    let instance = DeviceGeolocationPlugin()
    let methodChannel = FlutterMethodChannel(
      name: "device_geolocation", binaryMessenger: registrar.messenger)
    registrar.addMethodCallDelegate(instance, channel: methodChannel)

    FlutterEventChannel(
      name: "device_geolocation/locationUpdates",
      binaryMessenger: registrar.messenger
    ).setStreamHandler(instance.positionStreamHandler)

    FlutterEventChannel(
      name: "device_geolocation/serviceUpdates",
      binaryMessenger: registrar.messenger
    ).setStreamHandler(instance.serviceStreamHandler)

    FlutterEventChannel(
      name: "device_geolocation/permissionUpdates",
      binaryMessenger: registrar.messenger
    ).setStreamHandler(instance.permissionStreamHandler)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermission":
      result(GeolocationDelegate.permissionIndex(from: locationManager.authorizationStatus))
    case "requestPermission":
      if !ensurePermissionDefinitionsDeclared(result: result) { return }
      geolocationDelegate.requestPermission(result: result)
    case "isLocationServiceEnabled":
      DispatchQueue.global(qos: .userInitiated).async {
        let enabled = CLLocationManager.locationServicesEnabled()
        DispatchQueue.main.async { result(enabled) }
      }
    case "getCurrentPosition":
      if !ensurePermissionDefinitionsDeclared(result: result) { return }
      let args = call.arguments as? [String: Any]
      geolocationDelegate.requestCurrentPosition(args: args, result: result)
    case "openAppSettings", "openLocationSettings":
      let urlString: String
      if #available(macOS 13.0, *) {
        urlString =
          "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_LocationServices"
      } else {
        urlString =
          "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices"
      }
      if let url = URL(string: urlString) {
        let ok = NSWorkspace.shared.open(url)
        result(ok)
      } else {
        result(false)
      }
    case "getLocationAccuracy":
      result(locationManager.accuracyAuthorization == .fullAccuracy ? 1 : 0)
    case "requestTemporaryFullAccuracy":
      let purposeKey = (call.arguments as? [String: Any])?["purposeKey"] as? String ?? ""
      locationManager.requestTemporaryFullAccuracyAuthorization(withPurposeKey: purposeKey) { _ in
        result(self.locationManager.accuracyAuthorization == .fullAccuracy ? 1 : 0)
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  private func ensurePermissionDefinitionsDeclared(result: @escaping FlutterResult) -> Bool {
    guard Bundle.main.object(forInfoDictionaryKey: "NSLocationUsageDescription") != nil ||
          Bundle.main.object(forInfoDictionaryKey: "NSLocationWhenInUseUsageDescription") != nil else {
      result(FlutterError(
        code: "PERMISSION_DEFINITIONS_NOT_FOUND",
        message: "Info.plist is missing NSLocationUsageDescription or NSLocationWhenInUseUsageDescription. " +
          "Add one of the keys with a usage description string.",
        details: nil))
      return false
    }
    return true
  }
}

final class GeolocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
  weak var manager: CLLocationManager?
  private var permissionResult: FlutterResult?
  private var currentPositionResult: FlutterResult?
  fileprivate var positionEventSink: FlutterEventSink?
  fileprivate var serviceEventSink: FlutterEventSink?
  fileprivate var permissionEventSink: FlutterEventSink?
  private var isStreaming = false

  static func permissionIndex(from status: CLAuthorizationStatus) -> Int {
    switch status {
    case .notDetermined: return 0
    case .denied, .restricted: return 1
    case .authorizedAlways: return 3
    @unknown default: return 4
    }
  }

  static func locationToMap(_ loc: CLLocation) -> [String: Any?] {
    [
      "latitude": loc.coordinate.latitude,
      "longitude": loc.coordinate.longitude,
      "timestamp": Int(loc.timestamp.timeIntervalSince1970 * 1000),
      "accuracy": loc.horizontalAccuracy,
      "altitude": loc.altitude,
      "altitude_accuracy": loc.verticalAccuracy,
      "heading": loc.course,
      "heading_accuracy": loc.courseAccuracy,
      "speed": loc.speed,
      "speed_accuracy": loc.speedAccuracy,
    ]
  }

  func requestPermission(result: @escaping FlutterResult) {
    if permissionResult != nil {
      result(
        FlutterError(
          code: "PERMISSION_REQUEST_IN_PROGRESS",
          message: "A permission request is already in progress.", details: nil))
      return
    }
    guard let manager = manager else {
      result(
        FlutterError(
          code: "POSITION_UNAVAILABLE", message: "Location manager unavailable.",
          details: nil))
      return
    }
    let status = manager.authorizationStatus
    if status == .authorizedAlways {
      result(Self.permissionIndex(from: status))
      return
    }
    permissionResult = result
    manager.requestAlwaysAuthorization()
  }

  func requestCurrentPosition(args: [String: Any]?, result: @escaping FlutterResult) {
    guard let manager = manager else {
      result(
        FlutterError(
          code: "POSITION_UNAVAILABLE", message: "Location manager unavailable.",
          details: nil))
      return
    }
    let status = manager.authorizationStatus
    guard status == .authorizedAlways else {
      result(
        FlutterError(
          code: "PERMISSION_DENIED", message: "Location permission denied.", details: nil))
      return
    }
    let accuracyIndex = args?["accuracy"] as? Int ?? 4
    manager.desiredAccuracy = Self.desiredAccuracy(accuracyIndex)
    currentPositionResult = result
    manager.requestLocation()
  }

  static func desiredAccuracy(_ index: Int) -> CLLocationAccuracy {
    switch index {
    case 0: return kCLLocationAccuracyThreeKilometers
    case 1: return kCLLocationAccuracyKilometer
    case 2: return kCLLocationAccuracyHundredMeters
    case 3: return kCLLocationAccuracyNearestTenMeters
    case 4: return kCLLocationAccuracyBest
    case 5: return kCLLocationAccuracyBestForNavigation
    case 6: return kCLLocationAccuracyReduced
    default: return kCLLocationAccuracyBest
    }
  }

  func startStreamingDelegate(args: [String: Any]?) {
    guard let manager = manager else { return }
    manager.desiredAccuracy = Self.desiredAccuracy(args?["accuracy"] as? Int ?? 4)
    manager.distanceFilter = (args?["distanceFilter"] as? Double) ?? kCLDistanceFilterNone
    isStreaming = true
    manager.startUpdatingLocation()
  }

  func stopStreamingDelegate() {
    isStreaming = false
    manager?.stopUpdatingLocation()
  }

  // MARK: - CLLocationManagerDelegate

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    let index = Self.permissionIndex(from: manager.authorizationStatus)
    if let pr = permissionResult {
      permissionResult = nil
      pr(index)
    }
    permissionEventSink?(index)
    DispatchQueue.global(qos: .userInitiated).async {
      let enabled = CLLocationManager.locationServicesEnabled()
      DispatchQueue.main.async { self.serviceEventSink?(enabled ? 1 : 0) }
    }
  }

  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let loc = locations.last else { return }
    if let cr = currentPositionResult {
      currentPositionResult = nil
      cr(Self.locationToMap(loc))
      if !isStreaming { manager.stopUpdatingLocation() }
    }
    if isStreaming { positionEventSink?(Self.locationToMap(loc)) }
  }

  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    if let cr = currentPositionResult {
      currentPositionResult = nil
      cr(
        FlutterError(
          code: "POSITION_UNAVAILABLE", message: error.localizedDescription, details: nil))
    }
    positionEventSink?(
      FlutterError(
        code: "POSITION_UNAVAILABLE", message: error.localizedDescription, details: nil))
  }
}

final class PositionStreamHandler: NSObject, FlutterStreamHandler {
  private let delegate: GeolocationDelegate
  private let locationManager: CLLocationManager

  init(delegate: GeolocationDelegate, locationManager: CLLocationManager) {
    self.delegate = delegate
    self.locationManager = locationManager
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    delegate.positionEventSink = events
    delegate.startStreamingDelegate(args: arguments as? [String: Any])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate.stopStreamingDelegate()
    delegate.positionEventSink = nil
    return nil
  }
}

final class ServiceStreamHandler: NSObject, FlutterStreamHandler {
  private let delegate: GeolocationDelegate
  init(delegate: GeolocationDelegate) { self.delegate = delegate }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    delegate.serviceEventSink = events
    DispatchQueue.global(qos: .userInitiated).async {
      let enabled = CLLocationManager.locationServicesEnabled()
      DispatchQueue.main.async { events(enabled ? 1 : 0) }
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate.serviceEventSink = nil
    return nil
  }
}

final class PermissionStreamHandler: NSObject, FlutterStreamHandler {
  private let delegate: GeolocationDelegate
  init(delegate: GeolocationDelegate) { self.delegate = delegate }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    delegate.permissionEventSink = events
    DispatchQueue.main.async {
      guard let manager = self.delegate.manager else { return }
      events(GeolocationDelegate.permissionIndex(from: manager.authorizationStatus))
    }
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    delegate.permissionEventSink = nil
    return nil
  }
}
