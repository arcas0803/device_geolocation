import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PermissionDeniedException prints message', () {
    expect(PermissionDeniedException('nope').toString(), contains('nope'));
    expect(
      PermissionDeniedException().toString(),
      contains('permission denied'),
    );
  });

  test('PermissionDefinitionsNotFoundException prints message', () {
    expect(
      PermissionDefinitionsNotFoundException('missing entry').toString(),
      contains('missing entry'),
    );
    expect(
      PermissionDefinitionsNotFoundException().toString(),
      contains('missing platform permission declarations'),
    );
  });

  test('PermissionRequestInProgressException prints message', () {
    expect(
      PermissionRequestInProgressException('busy').toString(),
      contains('busy'),
    );
    expect(
      PermissionRequestInProgressException().toString(),
      contains('a permission request is already in progress'),
    );
  });

  test('LocationServiceDisabledException prints class name', () {
    expect(
      LocationServiceDisabledException().toString(),
      'LocationServiceDisabledException',
    );
  });

  test('PositionUpdateException prints message', () {
    expect(PositionUpdateException('boom').toString(), contains('boom'));
    expect(
      PositionUpdateException().toString(),
      contains('unable to obtain position'),
    );
  });
}
