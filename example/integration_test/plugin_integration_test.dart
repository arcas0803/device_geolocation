import 'package:device_geolocation/device_geolocation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isLocationServiceEnabled returns a bool', (
    WidgetTester tester,
  ) async {
    final enabled = await DeviceGeolocation.isLocationServiceEnabled();
    expect(enabled, isA<bool>());
  });
}
