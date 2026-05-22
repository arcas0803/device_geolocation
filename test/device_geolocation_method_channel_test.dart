import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/device_geolocation_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceGeolocation();
  const channel = MethodChannel('device_geolocation');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  final calls = <MethodCall>[];

  Map<String, dynamic> samplePositionMap() => {
    'latitude': 1.0,
    'longitude': 2.0,
    'timestamp': 0,
    'accuracy': 1.0,
    'altitude': 0.0,
    'altitude_accuracy': 0.0,
    'heading': 0.0,
    'heading_accuracy': 0.0,
    'speed': 0.0,
    'speed_accuracy': 0.0,
  };

  void install(Future<Object?>? Function(MethodCall) handler) {
    messenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      return handler(call);
    });
  }

  setUp(calls.clear);

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('checkPermission decodes int to enum', () async {
    install((_) async => LocationPermission.always.index);
    expect(await platform.checkPermission(), LocationPermission.always);
    expect(calls.single.method, 'checkPermission');
  });

  test('requestPermission forwards requestBackground arg', () async {
    install((_) async => LocationPermission.whileInUse.index);
    await platform.requestPermission(requestBackground: true);
    expect(calls.single.method, 'requestPermission');
    expect(calls.single.arguments, {'requestBackground': true});
  });

  test('isLocationServiceEnabled', () async {
    install((_) async => true);
    expect(await platform.isLocationServiceEnabled(), isTrue);
  });

  test('getLastKnownPosition forwards forceLocationManager', () async {
    install((_) async => samplePositionMap());
    final p = await platform.getLastKnownPosition(forceLocationManager: true);
    expect(p?.latitude, 1.0);
    expect(calls.single.arguments, {'forceLocationManager': true});
  });

  test(
    'getLastKnownPosition returns null when platform returns null',
    () async {
      install((_) async => null);
      expect(await platform.getLastKnownPosition(), isNull);
    },
  );

  test('getCurrentPosition forwards locationSettings', () async {
    install((_) async => samplePositionMap());
    final p = await platform.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: Duration(seconds: 7),
      ),
    );
    expect(p.latitude, 1.0);
    final args = calls.single.arguments as Map;
    expect(args['accuracy'], LocationAccuracy.high.index);
    expect(args['distanceFilter'], 5);
    expect(args['timeLimit'], 7000);
  });

  test('getCurrentPosition throws when platform returns null', () async {
    install((_) async => null);
    await expectLater(
      platform.getCurrentPosition(),
      throwsA(isA<PositionUpdateException>()),
    );
  });

  test('getLocationAccuracy decodes enum', () async {
    install((_) async => LocationAccuracyStatus.reduced.index);
    expect(
      await platform.getLocationAccuracy(),
      LocationAccuracyStatus.reduced,
    );
  });

  test('requestTemporaryFullAccuracy forwards purposeKey', () async {
    install((_) async => LocationAccuracyStatus.precise.index);
    final r = await platform.requestTemporaryFullAccuracy(
      purposeKey: 'PreciseLocation',
    );
    expect(r, LocationAccuracyStatus.precise);
    expect(calls.single.arguments, {'purposeKey': 'PreciseLocation'});
  });

  test('openAppSettings / openLocationSettings', () async {
    install((_) async => true);
    expect(await platform.openAppSettings(), isTrue);
    expect(await platform.openLocationSettings(), isTrue);
    expect(
      calls.map((c) => c.method),
      containsAll(['openAppSettings', 'openLocationSettings']),
    );
  });

  group('PlatformException mapping', () {
    Future<void> expectMapping(String code, Type type) async {
      install((_) async => throw PlatformException(code: code, message: 'x'));
      await expectLater(
        platform.checkPermission(),
        throwsA(predicate((e) => e.runtimeType == type)),
      );
    }

    test(
      'PERMISSION_DENIED',
      () => expectMapping('PERMISSION_DENIED', PermissionDeniedException),
    );
    test(
      'PERMISSION_DEFINITIONS_NOT_FOUND',
      () => expectMapping(
        'PERMISSION_DEFINITIONS_NOT_FOUND',
        PermissionDefinitionsNotFoundException,
      ),
    );
    test(
      'PERMISSION_REQUEST_IN_PROGRESS',
      () => expectMapping(
        'PERMISSION_REQUEST_IN_PROGRESS',
        PermissionRequestInProgressException,
      ),
    );
    test(
      'LOCATION_SERVICES_DISABLED',
      () => expectMapping(
        'LOCATION_SERVICES_DISABLED',
        LocationServiceDisabledException,
      ),
    );
    test(
      'POSITION_UNAVAILABLE',
      () => expectMapping('POSITION_UNAVAILABLE', PositionUpdateException),
    );
  });
}
