import 'package:dense_table_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DenseTable 100,000-row showcase smoke test', (tester) async {
    await tester.pumpWidget(const DenseTableDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('DenseTable 1.2.0 Showcase'), findsOneWidget);
    expect(find.textContaining('Dataset: 100000 rows'), findsOneWidget);
    expect(find.text('pod-worker-000000'), findsOneWidget);

    await tester.tap(find.text('pod-worker-000000'));
    await tester.pump();
    expect(find.textContaining('Anchor: pod-worker-000000'), findsOneWidget);

    await tester.tap(find.text('Filter: Degraded'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Dataset: 20000 rows'), findsOneWidget);
    expect(find.textContaining('Selected: 0 (IDs: 1)'), findsOneWidget);
  });
}
