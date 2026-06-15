import 'package:device_geolocation/device_geolocation.dart';
import 'package:device_geolocation/device_geolocation_method_channel.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final platform = MethodChannelDeviceGeolocation();
  const channel = MethodChannel('device_geolocation');
  const permissionChannel = EventChannel('device_geolocation/permissionUpdates');
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
    install((_) async => DeviceLocationPermission.always.index);
    expect(await platform.checkPermission(), DeviceLocationPermission.always);
    expect(calls.single.method, 'checkPermission');
  });

  test('requestPermission forwards requestBackground arg', () async {
    install((_) async => DeviceLocationPermission.whileInUse.index);
    await platform.requestPermission(requestBackground: true);
    expect(calls.single.method, 'requestPermission');
    expect(calls.single.arguments, {'requestBackground': true});
  });

  test('isLocationServiceEnabled', () async {
    install((_) async => true);
    expect(await platform.isLocationServiceEnabled(), isTrue);
  });

  test('getCurrentPosition forwards deviceLocationSettings', () async {
    install((_) async => samplePositionMap());
    final p = await platform.getCurrentPosition(
      deviceLocationSettings: const DeviceLocationSettings(
        accuracy: DeviceLocationAccuracy.high,
        distanceFilter: 5,
        timeLimit: Duration(seconds: 7),
      ),
    );
    expect(p.latitude, 1.0);
    final args = calls.single.arguments as Map;
    expect(args['accuracy'], DeviceLocationAccuracy.high.index);
    expect(args['distanceFilter'], 5);
    expect(args['timeLimit'], 7000);
  });

  test('getCurrentPosition uses default settings when null', () async {
    install((_) async => samplePositionMap());
    await platform.getCurrentPosition();
    final args = calls.single.arguments as Map;
    expect(args['accuracy'], DeviceLocationAccuracy.best.index);
    expect(args['distanceFilter'], 0);
  });

  test('getCurrentPosition throws when platform returns null', () async {
    install((_) async => null);
    await expectLater(
      platform.getCurrentPosition(),
      throwsA(isA<PositionUpdateException>()),
    );
  });

  test('getLocationAccuracy decodes enum', () async {
    install((_) async => DeviceLocationAccuracyStatus.reduced.index);
    expect(
      await platform.getLocationAccuracy(),
      DeviceLocationAccuracyStatus.reduced,
    );
  });

  test('requestTemporaryFullAccuracy forwards purposeKey', () async {
    install((_) async => DeviceLocationAccuracyStatus.precise.index);
    final r = await platform.requestTemporaryFullAccuracy(
      purposeKey: 'PreciseLocation',
    );
    expect(r, DeviceLocationAccuracyStatus.precise);
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

  group('getPermissionStream', () {
    tearDown(() {
      messenger.setMockMessageHandler(permissionChannel.name, null);
    });

    test('emits current permission immediately via polling', () async {
      install((_) async => DeviceLocationPermission.whileInUse.index);
      final values = <DeviceLocationPermission>[];
      final sub = platform
          .getPermissionStream(pollingInterval: const Duration(milliseconds: 50))
          .listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(values, isNotEmpty);
      expect(values.first, DeviceLocationPermission.whileInUse);
      await sub.cancel();
    });

    test('emits permission updates from native event channel', () async {
      install((_) async => DeviceLocationPermission.denied.index);

      messenger.setMockMessageHandler(
        permissionChannel.name,
        (message) async {
          final codec = permissionChannel.codec;
          final call = codec.decodeMethodCall(message);
          if (call.method == 'listen') {
            final envelope = codec.encodeSuccessEnvelope(
              DeviceLocationPermission.always.index,
            );
            // ignore: discarded_futures
            Future<void>.delayed(Duration.zero, () {
              // ignore: deprecated_member_use
              permissionChannel.binaryMessenger.handlePlatformMessage(
                permissionChannel.name,
                envelope,
                (_) {},
              );
            });
          }
          return codec.encodeSuccessEnvelope(null);
        },
      );

      final values = <DeviceLocationPermission>[];
      final sub = platform
          .getPermissionStream(pollingInterval: const Duration(days: 1))
          .listen(values.add);
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(values, contains(DeviceLocationPermission.always));
      await sub.cancel();
    });
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
