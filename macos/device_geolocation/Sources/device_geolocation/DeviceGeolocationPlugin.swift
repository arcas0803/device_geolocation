import Cocoa
import CoreLocation
import FlutterMacOS

public class DeviceGeolocationPlugin: NSObject, FlutterPlugin {
  private let locationManager = CLLocationManager()
  private let geolocationDelegate = GeolocationDelegate()
  private let positionStreamHandler: PositionStreamHandler
  private let serviceStreamHandler: ServiceStreamHandler

  override init() {
    self.positionStreamHandler = PositionStreamHandler(
      delegate: geolocationDelegate, locationManager: locationManager)
    self.serviceStreamHandler = ServiceStreamHandler(delegate: geolocationDelegate)
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
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "checkPermission":
      result(GeolocationDelegate.permissionIndex(from: locationManager.authorizationStatus))
    case "requestPermission":
      geolocationDelegate.requestPermission(result: result)
    case "isLocationServiceEnabled":
      DispatchQueue.global(qos: .userInitiated).async {
        let enabled = CLLocationManager.locationServicesEnabled()
        DispatchQueue.main.async { result(enabled) }
      }
    case "getLastKnownPosition":
      if let loc = locationManager.location {
        result(GeolocationDelegate.locationToMap(loc))
      } else {
        result(nil)
      }
    case "getCurrentPosition":
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
}

final class GeolocationDelegate: NSObject, CLLocationManagerDelegate, @unchecked Sendable {
  weak var manager: CLLocationManager?
  private var permissionResult: FlutterResult?
  private var currentPositionResult: FlutterResult?
  fileprivate var positionEventSink: FlutterEventSink?
  fileprivate var serviceEventSink: FlutterEventSink?
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

    if #available(macOS 14.0, *) {
      Task { @MainActor in
        do {
          for try await update in CLLocationUpdate.liveUpdates(.default) {
            if let loc = update.location {
              result(Self.locationToMap(loc))
              return
            }
          }
        } catch {
          result(
            FlutterError(
              code: "POSITION_UNAVAILABLE", message: error.localizedDescription,
              details: nil))
        }
      }
      return
    }

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

  func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    if let pr = permissionResult {
      permissionResult = nil
      pr(Self.permissionIndex(from: manager.authorizationStatus))
    }
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
  private var liveUpdatesTask: Task<Void, Never>?

  init(delegate: GeolocationDelegate, locationManager: CLLocationManager) {
    self.delegate = delegate
    self.locationManager = locationManager
  }

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink)
    -> FlutterError?
  {
    delegate.positionEventSink = events
    if #available(macOS 14.0, *) {
      liveUpdatesTask = Task { @MainActor [weak delegate] in
        do {
          for try await update in CLLocationUpdate.liveUpdates(.default) {
            if Task.isCancelled { return }
            if let loc = update.location {
              delegate?.positionEventSink?(GeolocationDelegate.locationToMap(loc))
            }
          }
        } catch {
          delegate?.positionEventSink?(
            FlutterError(
              code: "POSITION_UNAVAILABLE", message: error.localizedDescription,
              details: nil))
        }
      }
      return nil
    }
    delegate.startStreamingDelegate(args: arguments as? [String: Any])
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    liveUpdatesTask?.cancel()
    liveUpdatesTask = nil
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
