// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flutter1/main.dart';

void main() {
  testWidgets('Community app smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CommunityApp());

    // Verify that our app title appears.
    expect(find.text('קהילה מקומית'), findsOneWidget);
    
    // Verify that the search field is present.
    expect(find.byIcon(Icons.search), findsOneWidget);
    
    // Verify that the floating action button is present.
    expect(find.text('בקשה חדשה'), findsOneWidget);
    
    // Verify that we have some help requests displayed.
    expect(find.text('צריך תיקון ברז'), findsOneWidget);
    expect(find.text('שיעור מתמטיקה'), findsOneWidget);
    expect(find.text('הובלה קטנה'), findsOneWidget);
  });
  
  testWidgets('Help request card interaction test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const CommunityApp());

    // Find and tap the first "אני יכול לעזור" button
    final helpButtons = find.text('אני יכול לעזור');
    expect(helpButtons, findsWidgets);
    
    await tester.tap(helpButtons.first);
    await tester.pump();

    // Verify that a dialog appears
    expect(find.text('אני יכול לעזור!'), findsOneWidget);
  });
}
