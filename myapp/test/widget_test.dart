import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:myapp/main.dart';

void main() {
  setUp(() {
    // No stored token → unauthenticated state
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Unauthenticated user sees login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlightApp());

    // Loading spinner while auth check runs
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // Let the async auth check finish
    await tester.pumpAndSettle();

    // Should land on the login screen
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.text('Connexion'), findsWidgets);
  });
}
