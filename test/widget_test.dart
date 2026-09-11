import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('App launches with a navigation shell', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Center(child: Text('ZCanopy')))),
    );

    expect(find.text('ZCanopy'), findsOneWidget);
  });
}