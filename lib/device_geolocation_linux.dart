import 'dart:async';
import 'dart:io';

import 'package:dbus/dbus.dart';

import 'device_geolocation_platform_interface.dart';
import 'src/enums/enums.dart';
import 'src/models/models.dart';

/// Linux implementation of [DeviceGeolocationPlatform] backed by the
/// GeoClue2 D-Bus service (`org.freedesktop.GeoClue2`).
class DeviceGeolocationLinux extends DeviceGeolocationPlatform {
  DeviceGeolocationLinux({DBusClient? bus}) : _bus = bus ?? DBusClient.system();

  /// Registers this implementation with [DeviceGeolocationPlatform.instance].
  static void registerWith() {
    DeviceGeolocationPlatform.instance = DeviceGeolocationLinux();
  }

  static const String _service = 'org.freedesktop.GeoClue2';
  static const String _managerPath = '/org/freedesktop/GeoClue2/Manager';
  static const String _managerIface = 'org.freedesktop.GeoClue2.Manager';
  static const String _clientIface = 'org.freedesktop.GeoClue2.Client';
  static const String _locationIface = 'org.freedesktop.GeoClue2.Location';
  static const String _desktopId = 'flutter';

  final DBusClient _bus;

  DBusRemoteObject _manager() => DBusRemoteObject(
    _bus,
    name: _service,
    path: DBusObjectPath(_managerPath),
  );

  Future<DBusRemoteObject> _getOrCreateClient() async {
    final manager = _manager();
    final reply = await manager.callMethod(
      _managerIface,
      'GetClient',
      [],
      replySignature: DBusSignature('o'),
    );
    final path = (reply.values.first as DBusObjectPath);
    final client = DBusRemoteObject(_bus, name: _service, path: path);
    await client.setProperty(_clientIface, 'DesktopId', DBusString(_desktopId));
    return client;
  }

  Future<void> _startClient(
    DBusRemoteObject client,
    int accuracyLevel, {
    int distanceThreshold = 0,
    int timeThreshold = 0,
  }) async {
    await client.setProperty(
      _clientIface,
      'RequestedAccuracyLevel',
      DBusUint32(accuracyLevel),
    );
    if (distanceThreshold > 0) {
      await client.setProperty(
        _clientIface,
        'DistanceThreshold',
        DBusUint32(distanceThreshold),
      );
    }
    if (timeThreshold > 0) {
      await client.setProperty(
        _clientIface,
        'TimeThreshold',
        DBusUint32(timeThreshold),
      );
    }
    await client.callMethod(_clientIface, 'Start', []);
  }

  Future<void> _stopClient(DBusRemoteObject client) async {
    try {
      await client.callMethod(_clientIface, 'Stop', []);
    } catch (_) {
      // Ignore — client may have been removed already.
    }
  }

  int _accuracyToGeoClueLevel(LocationAccuracy accuracy) {
    switch (accuracy) {
      case LocationAccuracy.reduced:
      case LocationAccuracy.lowest:
        return 1; // COUNTRY
      case LocationAccuracy.low:
        return 4; // CITY
      case LocationAccuracy.medium:
        return 5; // NEIGHBORHOOD
      case LocationAccuracy.high:
        return 6; // STREET
      case LocationAccuracy.best:
      case LocationAccuracy.bestForNavigation:
        return 8; // EXACT
    }
  }

  Future<Position> _readLocation(DBusObjectPath path) async {
    final loc = DBusRemoteObject(_bus, name: _service, path: path);
    Future<double> readDouble(String name) async {
      final v = await loc.getProperty(
        _locationIface,
        name,
        signature: DBusSignature('d'),
      );
      return (v as DBusDouble).value;
    }

    final lat = await readDouble('Latitude');
    final lon = await readDouble('Longitude');
    final accuracy = await readDouble('Accuracy');
    final altitude = await readDouble('Altitude');
    final speed = await readDouble('Speed');
    final heading = await readDouble('Heading');

    int timestampMs = DateTime.now().millisecondsSinceEpoch;
    try {
      final ts = await loc.getProperty(
        _locationIface,
        'Timestamp',
        signature: DBusSignature('(tt)'),
      );
      final values = (ts as DBusStruct).children;
      final seconds = (values[0] as DBusUint64).value;
      final micros = (values[1] as DBusUint64).value;
      timestampMs = seconds * 1000 + micros ~/ 1000;
    } catch (_) {
      // Some GeoClue versions omit Timestamp — fall back to "now".
    }

    return Position(
      latitude: lat,
      longitude: lon,
      timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs, isUtc: true),
      accuracy: accuracy,
      altitude: altitude == -1.7976931348623157e308 ? 0.0 : altitude,
      altitudeAccuracy: 0.0,
      heading: heading == -1.0 ? 0.0 : heading,
      headingAccuracy: 0.0,
      speed: speed == -1.0 ? 0.0 : speed,
      speedAccuracy: 0.0,
    );
  }

  @override
  Future<LocationPermission> checkPermission() async =>
      LocationPermission.whileInUse;

  @override
  Future<LocationPermission> requestPermission({
    bool requestBackground = false,
  }) async => LocationPermission.whileInUse;

  @override
  Future<bool> isLocationServiceEnabled() async {
    try {
      final value = await _manager().getProperty(
        _managerIface,
        'LocationAvailable',
        signature: DBusSignature('b'),
      );
      return (value as DBusBoolean).value;
    } catch (_) {
      return false;
    }
  }

  @override
  Future<Position?> getLastKnownPosition({
    bool forceLocationManager = false,
  }) async {
    // GeoClue2 does not expose a cached last-known position.
    return null;
  }

  @override
  Future<Position> getCurrentPosition({
    LocationSettings? locationSettings,
  }) async {
    final settings = locationSettings ?? const LocationSettings();
    final client = await _getOrCreateClient();
    final completer = Completer<Position>();
    StreamSubscription<DBusSignal>? subscription;

    final signals = DBusRemoteObjectSignalStream(
      object: client,
      interface: _clientIface,
      name: 'LocationUpdated',
      signature: DBusSignature('oo'),
    );

    subscription = signals.listen(
      (signal) async {
        try {
          final newPath = signal.values[1] as DBusObjectPath;
          final position = await _readLocation(newPath);
          if (!completer.isCompleted) completer.complete(position);
          await subscription?.cancel();
          await _stopClient(client);
        } catch (e) {
          if (!completer.isCompleted) completer.completeError(e);
        }
      },
      onError: (Object e, StackTrace st) {
        if (!completer.isCompleted) completer.completeError(e, st);
      },
    );

    try {
      await _startClient(client, _accuracyToGeoClueLevel(settings.accuracy));
    } catch (e) {
      await subscription.cancel();
      rethrow;
    }

    if (settings.timeLimit != null) {
      return completer.future.timeout(
        settings.timeLimit!,
        onTimeout: () async {
          await subscription?.cancel();
          await _stopClient(client);
          throw TimeoutException(
            'getCurrentPosition timed out',
            settings.timeLimit,
          );
        },
      );
    }
    return completer.future;
  }

  @override
  Stream<Position> getPositionStream({LocationSettings? locationSettings}) {
    final settings = locationSettings ?? const LocationSettings();
    late StreamController<Position> controller;
    DBusRemoteObject? client;
    StreamSubscription<DBusSignal>? subscription;

    Future<void> start() async {
      client = await _getOrCreateClient();
      final signals = DBusRemoteObjectSignalStream(
        object: client!,
        interface: _clientIface,
        name: 'LocationUpdated',
        signature: DBusSignature('oo'),
      );
      subscription = signals.listen((signal) async {
        try {
          final newPath = signal.values[1] as DBusObjectPath;
          final position = await _readLocation(newPath);
          if (!controller.isClosed) controller.add(position);
        } catch (e, st) {
          if (!controller.isClosed) controller.addError(e, st);
        }
      }, onError: controller.addError);
      await _startClient(
        client!,
        _accuracyToGeoClueLevel(settings.accuracy),
        distanceThreshold: settings.distanceFilter,
      );
    }

    Future<void> stop() async {
      await subscription?.cancel();
      subscription = null;
      if (client != null) {
        await _stopClient(client!);
        client = null;
      }
    }

    controller = StreamController<Position>(
      onListen: () {
        unawaited(
          start().catchError((Object e, StackTrace st) {
            if (!controller.isClosed) controller.addError(e, st);
          }),
        );
      },
      onCancel: stop,
    );

    return controller.stream;
  }

  @override
  Stream<ServiceStatus> getServiceStatusStream() async* {
    yield (await isLocationServiceEnabled())
        ? ServiceStatus.enabled
        : ServiceStatus.disabled;
  }

  @override
  Future<LocationAccuracyStatus> getLocationAccuracy() async =>
      LocationAccuracyStatus.precise;

  @override
  Future<LocationAccuracyStatus> requestTemporaryFullAccuracy({
    required String purposeKey,
  }) async => LocationAccuracyStatus.precise;

  @override
  Future<bool> openAppSettings() => openLocationSettings();

  @override
  Future<bool> openLocationSettings() async {
    final attempts = <List<String>>[
      ['gnome-control-center', 'privacy', 'location'],
      ['systemsettings5', 'kcm_location'],
      ['xdg-open', 'settings://privacy/location'],
    ];
    for (final args in attempts) {
      try {
        final r = await Process.run(args.first, args.sublist(1));
        if (r.exitCode == 0) return true;
      } catch (_) {
        // Try next.
      }
    }
    return false;
  }
}
