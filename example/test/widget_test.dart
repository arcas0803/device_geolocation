import 'package:device_geolocation_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter/material.dart';

void main() {
  testWidgets('Example app renders', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    await tester.pump();

    expect(find.text('device_geolocation example'), findsOneWidget);

    // Dispose the example widget so its stream subscriptions are cancelled
    // before the test framework checks for pending timers.
    await tester.pumpWidget(Container());
    await tester.pump(const Duration(milliseconds: 100));
  });
}
