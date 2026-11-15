import 'package:dense_table_example/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DenseTable 100,000-row showcase smoke test', (tester) async {
    await tester.pumpWidget(const DenseTableDemoApp());
    await tester.pumpAndSettle();

    expect(find.text('DenseTable 1.0.0 Showcase'), findsOneWidget);
    expect(find.textContaining('Dataset: 100000 rows'), findsOneWidget);
    expect(find.text('pod-worker-000000'), findsOneWidget);
  });
}
