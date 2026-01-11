import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dense_table_example/main.dart';

void main() {
  testWidgets('DenseTable example app smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: MyApp()));

    // 2. Wait for all animations and scheduled frames to complete.
    await tester.pumpAndSettle();

    // 3. Verify that the app title is displayed.
    expect(find.text('DenseTable Example'), findsOneWidget);

    // 4. Verify that the table header is present.
    expect(find.text('Process Log (1,000 rows)'), findsOneWidget);
  });
}
