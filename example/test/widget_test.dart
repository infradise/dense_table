import 'package:dense_table_example/main.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DenseTable 100,000-row showcase smoke test', (tester) async {
    await tester.pumpWidget(const DenseTableDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('DenseTable 1.4.0 Showcase'), findsOneWidget);
    expect(find.textContaining('Dataset: 100000 rows'), findsOneWidget);
    expect(find.text('pod-worker-000000'), findsOneWidget);

    await tester.tap(find.text('pod-worker-000000'));
    await tester.pump();
    expect(find.textContaining('Anchor: pod-worker-000000'), findsOneWidget);

    // v1.4.0: the 2-state toggle sort cycle offers a header clear button.
    final clearButton = find.byWidgetPredicate((widget) {
      final key = widget.key;
      return key is ValueKey<String> &&
          key.value.startsWith('dense_clear_sort_');
    });
    expect(clearButton, findsNothing);
    await tester.tap(find.text('Namespace'));
    await tester.pumpAndSettle();
    expect(clearButton, findsOneWidget);
    await tester.tap(clearButton);
    await tester.pumpAndSettle();
    expect(clearButton, findsNothing);

    await tester.tap(find.text('Filter: Degraded'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dataset: 20000 rows'), findsOneWidget);
    expect(find.textContaining('Selected: 0 (IDs: 1)'), findsOneWidget);
  });
}
