import 'package:dense_table_example/main.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DenseTable 100,000-row showcase sort and filter smoke test', (
    tester,
  ) async {
    await tester.pumpWidget(const DenseTableDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('DenseTable 1.5.0 Showcase'), findsOneWidget);
    expect(find.textContaining('Dataset: 100000 rows'), findsOneWidget);
    expect(find.text('pod-worker-000000'), findsOneWidget);

    await tester.tap(find.text('pod-worker-000000'));
    await tester.pump();
    expect(find.textContaining('Anchor: pod-worker-000000'), findsOneWidget);

    // 2-state toggle sort cycle offers both header x and toolbar Clear Sort.
    final clearButton = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('dense_clear_sort_');
    });
    expect(clearButton, findsNothing);
    await tester.tap(find.text('Namespace'));
    await tester.pumpAndSettle();
    expect(clearButton, findsOneWidget);
    expect(find.textContaining('Sort: Col #1 (ascending)'), findsOneWidget);

    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(clearButton, findsNothing);
    expect(find.textContaining('Sort: Unsorted'), findsOneWidget);

    await tester.tap(find.text('Namespace'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sort: Col #1 (ascending)'), findsOneWidget);

    await tester.tap(find.text('Clear Sort'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Sort: Unsorted'), findsOneWidget);
    expect(clearButton, findsNothing);

    await tester.tap(find.text('Filter: Degraded'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dataset: 20000 rows'), findsOneWidget);
    expect(find.textContaining('Selected: 0 (IDs: 1)'), findsOneWidget);

    await tester.tap(find.text('1K Rows'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dataset: 200 rows'), findsOneWidget);

    await tester.tap(find.text('Filter: All'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dataset: 1000 rows'), findsOneWidget);
  });

  testWidgets(
    'DenseTable 1.5.0 toggles frozen columns, pinned actions, visibility, and theme',
    (tester) async {
      await tester.pumpWidget(const DenseTableDemoApp());
      await tester.pumpAndSettle();

      expect(find.textContaining('Frozen: 2'), findsOneWidget);
      expect(find.textContaining('Actions: Pinned'), findsOneWidget);
      expect(find.textContaining('Region Col: Visible'), findsOneWidget);
      expect(find.text('Region'), findsOneWidget);
      expect(find.text('Actions'), findsOneWidget);
      expect(find.text('Inspect'), findsWidgets);

      await tester.tap(find.text('Inspect').first);
      await tester.pump();
      expect(
        find.textContaining('Inspected: pod-worker-000000'),
        findsOneWidget,
      );

      await tester.tap(find.text('Frozen Cols'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Frozen: 0'), findsOneWidget);

      await tester.tap(find.text('Frozen Cols'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Frozen: 2'), findsOneWidget);

      await tester.tap(find.text('Pin Actions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Actions: Scrollable'), findsOneWidget);

      await tester.tap(find.text('Pin Actions'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Actions: Pinned'), findsOneWidget);

      await tester.tap(find.text('Hide Column'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Region Col: Hidden'), findsOneWidget);
      expect(find.text('Region'), findsNothing);
      expect(find.text('Show Column'), findsOneWidget);
      expect(find.text('pod-worker-000000'), findsOneWidget);

      await tester.tap(find.text('Show Column'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Region Col: Visible'), findsOneWidget);
      expect(find.text('Region'), findsOneWidget);
      expect(find.text('Hide Column'), findsOneWidget);

      await tester.tap(find.text('Light Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Dark Theme'), findsOneWidget);

      await tester.tap(find.text('Dark Theme'));
      await tester.pumpAndSettle();
      expect(find.text('Light Theme'), findsOneWidget);

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'DenseTable 1.5.0 secondary tap selection and clipboard TSV copy smoke test',
    (tester) async {
      String? copiedText;
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          final args = call.arguments as Map<dynamic, dynamic>;
          copiedText = args['text'] as String?;
        }
        return null;
      });
      addTearDown(() {
        messenger.setMockMethodCallHandler(SystemChannels.platform, null);
      });

      await tester.pumpWidget(const DenseTableDemoApp());
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('pod-worker-000000'),
        buttons: kSecondaryButton,
      );
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Right-click: pod-worker-000000'),
        findsOneWidget,
      );
      expect(find.textContaining('Selected: 1 (IDs: 1)'), findsOneWidget);

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.textContaining('Copied: 1 row (8 cols)'), findsOneWidget);
      expect(copiedText, isNotNull);
      expect(copiedText, contains('pod-worker-000000'));
      expect(copiedText, contains('us-east-1'));

      // Hiding the Region column excludes it from TSV copy without shifting indices.
      await tester.tap(find.text('Hide Column'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('pod-worker-000000'));
      await tester.pumpAndSettle();

      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyC);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();

      expect(find.textContaining('Copied: 1 row (7 cols)'), findsOneWidget);
      expect(copiedText, isNotNull);
      expect(copiedText, contains('pod-worker-000000'));
      expect(copiedText, isNot(contains('us-east-1')));
    },
  );
}
