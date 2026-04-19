// This is a basic Flutter widget test.
//
// It verifies that the app starts correctly and the home screen shows
// the expected title and search button.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:myapp/main.dart';

void main() {
  testWidgets('App starts and displays home screen', (WidgetTester tester) async {
    await tester.pumpWidget(const FlightApp());
    await tester.pumpAndSettle();

    expect(find.text('Accueil'), findsOneWidget);
    expect(find.text('Rechercher'), findsOneWidget);
    expect(find.byIcon(Icons.search), findsOneWidget);
  });
}
