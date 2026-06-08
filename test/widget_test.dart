import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Smoke: MaterialApp builds', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: Center(child: Text('Godawari Fish POS test')),
        ),
      ),
    );
    expect(find.textContaining('Godawari'), findsOneWidget);
  });
}
