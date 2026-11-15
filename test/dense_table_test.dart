import 'package:dense_table/dense_table.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrapTestHarness(Widget child) {
  return MediaQuery(
    data: const MediaQueryData(size: Size(1024, 768)),
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Align(
        alignment: Alignment.topLeft,
        child: child,
      ),
    ),
  );
}

void main() {
  group('100,000-Row O(1) Virtualization & Performance', () {
    testWidgets(
      'virtualizes 100,000 rows in O(1) without mounting off-screen rows',
      (tester) async {
        final controller = DenseTableController();
        var builtCells = 0;

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 800,
              height: 480,
              child: DenseTable.builder(
                controller: controller,
                rowCount: 100000,
                rawCellValue: (row, col) => col == 0 ? row : 'Item #$row',
                columns: const <DenseColumn>[
                  DenseColumn(title: 'ID', initialWidth: 100),
                  DenseColumn(title: 'Name', initialWidth: 260),
                  DenseColumn(title: 'State', initialWidth: 140),
                ],
                cellBuilder: (context, row, col) {
                  builtCells++;
                  if (col == 0) {
                    return Text('$row');
                  }
                  if (col == 1) {
                    return Text('Item #$row');
                  }
                  return Text(row.isEven ? 'READY' : 'IDLE');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Viewport is ~450px tall at 24px/row (~19 visible rows + cacheExtent).
        // Far fewer than 400 cells must be built out of 300,000 total cells.
        expect(builtCells, lessThan(400));
        expect(find.text('Item #0'), findsOneWidget);
        expect(find.text('Item #50000'), findsNothing);
        expect(find.text('Item #99999'), findsNothing);

        // O(1) jump straight to row 99,999.
        controller.scrollToVisualRow(99999);
        await tester.pumpAndSettle();

        expect(find.text('Item #99999'), findsOneWidget);
        expect(find.text('Item #0'), findsNothing);

        // Sort 100,000 rows descending by ID and verify top row is 99,999.
        controller.scrollToVisualRow(0);
        await tester.pumpAndSettle();
        controller.setSort(
          const DenseSortState(
            columnIndex: 0,
            direction: DenseSortDirection.descending,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Item #99999'), findsOneWidget);

        controller.dispose();
      },
    );
  });

  group('Layout Constraint Safety (External Package Embedding)', () {
    testWidgets(
      'never crashes inside unbounded vertical Column (shrinkWrap false & true)',
      (tester) async {
        await tester.pumpWidget(
          _wrapTestHarness(
            SingleChildScrollView(
              child: Column(
                children: <Widget>[
                  const Text('Section Above'),
                  DenseTable(
                    headers: const <String>['ID', 'Name', 'Status'],
                    columnWidths: const <int, double>{
                      0: 60,
                      1: 180,
                      2: 100,
                    },
                    data: List<List<dynamic>>.generate(
                      50,
                      (i) => <dynamic>[i, 'Row $i', 'OK'],
                    ),
                  ),
                  DenseTable(
                    shrinkWrap: true,
                    headers: const <String>['Key', 'Value'],
                    columnWidths: const <int, double>{0: 120, 1: 200},
                    data: List<List<dynamic>>.generate(
                      100000,
                      (i) => <dynamic>['k:$i', 'v:$i'],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Row 0'), findsOneWidget);
        expect(find.text('k:0'), findsOneWidget);
      },
    );

    testWidgets(
      'never overflows inside narrow split-pane narrower than sum of columns',
      (tester) async {
        await tester.pumpWidget(
          _wrapTestHarness(
            const SizedBox(
              width: 180,
              height: 160,
              child: DenseTable(
                headers: <String>[
                  'Cluster',
                  'Namespace',
                  'Pod',
                  'Node',
                ],
                columnWidths: <int, double>{
                  0: 220,
                  1: 200,
                  2: 320,
                  3: 240,
                },
                data: <List<dynamic>>[
                  <dynamic>[
                    'prod-apne2',
                    'kube-system',
                    'coredns-7db6d8ff4d-x92lm',
                    'ip-10-0-12-44',
                  ],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('prod-apne2'), findsOneWidget);
      },
    );

    testWidgets(
      'renders cleanly without WidgetsApp, Directionality, or MediaQuery ancestors',
      (tester) async {
        await tester.pumpWidget(
          const SizedBox(
            width: 500,
            height: 300,
            child: DenseTable(
              headers: <String>['Col A', 'Col B'],
              columnWidths: <int, double>{0: 120, 1: 180},
              selectionMode: DenseSelectionMode.multi,
              showCheckboxColumn: true,
              data: <List<dynamic>>[
                <dynamic>['Alpha', 10],
                <dynamic>['Beta', 20],
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('Alpha'), findsOneWidget);
      },
    );
  });

  group('Resizable Columns & Synchronized Horizontal Scroll', () {
    testWidgets(
      'drags column resize handle respecting minColumnWidth and syncs header scroll',
      (tester) async {
        final hScroll = ScrollController();
        int? resizedCol;
        double? resizedWidth;

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 300,
              height: 240,
              child: DenseTable(
                horizontalScrollController: hScroll,
                expandLastColumn: false,
                style: const DenseStyle(minColumnWidth: 50.0),
                headers: const <String>['ID', 'Name', 'Status'],
                columnWidths: const <int, double>{
                  0: 100.0,
                  1: 200.0,
                  2: 200.0,
                },
                onColumnResized: (col, width) {
                  resizedCol = col;
                  resizedWidth = width;
                },
                data: const <List<dynamic>>[
                  <dynamic>[1, 'Alpha', 'OK'],
                  <dynamic>[2, 'Beta', 'WARN'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tableTopLeft = tester.getTopLeft(find.byType(DenseTable));
        final handlePoint = tableTopLeft + const Offset(99.0, 14.0);
        await tester.dragFrom(handlePoint, const Offset(60.0, 0.0));
        await tester.pumpAndSettle();

        expect(resizedCol, 0);
        expect(resizedWidth, closeTo(160.0, 2.0));

        // Dragging far left clamps strictly to minColumnWidth (50.0).
        final wideHandlePoint = tableTopLeft + const Offset(159.0, 14.0);
        await tester.dragFrom(wideHandlePoint, const Offset(-300.0, 0.0));
        await tester.pumpAndSettle();
        expect(resizedWidth, 50.0);

        hScroll.jumpTo(120.0);
        await tester.pumpAndSettle();
        expect(hScroll.offset, closeTo(120.0, 0.5));

        hScroll.dispose();
      },
    );
  });

  group('Sortable Columns', () {
    testWidgets(
      'cycles ascending -> descending -> unsorted while preserving original selection',
      (tester) async {
        final controller = DenseTableController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 500,
              height: 260,
              child: DenseTable(
                controller: controller,
                selectionMode: DenseSelectionMode.single,
                headers: const <String>['Name', 'Latency'],
                columnWidths: const <int, double>{0: 200, 1: 150},
                data: const <List<dynamic>>[
                  <dynamic>['Gamma', '100.0 ms'],
                  <dynamic>['Alpha', '9.5 ms'],
                  <dynamic>['Beta', '12.0 ms'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Select 'Alpha' (original row index 1).
        await tester.tap(find.text('Alpha'));
        await tester.pump();
        expect(controller.selectedRows, <int>{1});

        // Click 'Latency' header -> ascending ('9.5 ms', '12.0 ms', '100.0 ms').
        await tester.tap(find.text('Latency'));
        await tester.pumpAndSettle();
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 1,
            direction: DenseSortDirection.ascending,
          ),
        );
        expect(
          tester.getTopLeft(find.text('Alpha')).dy,
          lessThan(tester.getTopLeft(find.text('Beta')).dy),
        );
        expect(
          tester.getTopLeft(find.text('Beta')).dy,
          lessThan(tester.getTopLeft(find.text('Gamma')).dy),
        );
        expect(controller.selectedRows, <int>{1});

        // Second click -> descending ('100.0 ms', '12.0 ms', '9.5 ms').
        await tester.tap(find.text('Latency'));
        await tester.pumpAndSettle();
        expect(
          controller.sortState?.direction,
          DenseSortDirection.descending,
        );
        expect(
          tester.getTopLeft(find.text('Gamma')).dy,
          lessThan(tester.getTopLeft(find.text('Alpha')).dy),
        );

        // Third click -> unsorted (original order restored).
        await tester.tap(find.text('Latency'));
        await tester.pumpAndSettle();
        expect(controller.sortState, isNull);

        controller.dispose();
      },
    );
  });

  group('Single/Multi Selection & Keyboard Navigation', () {
    testWidgets(
      'supports Shift+Click range select, Ctrl+A, Arrow keys, End/Home, and Enter',
      (tester) async {
        final controller = DenseTableController();
        int? activatedRow;

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 600,
              height: 240,
              child: DenseTable(
                controller: controller,
                autofocus: true,
                selectionMode: DenseSelectionMode.multi,
                showCheckboxColumn: true,
                onRowActivated: (row) => activatedRow = row,
                headers: const <String>['ID', 'Label'],
                columnWidths: const <int, double>{0: 80, 1: 240},
                data: List<List<dynamic>>.generate(
                  20,
                  (i) => <dynamic>[i, 'Row-$i'],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click Row-1 -> selects {1}.
        await tester.tap(find.text('Row-1'));
        await tester.pump();
        expect(controller.selectedRows, <int>{1});

        // Shift+Click Row-4 -> selects contiguous range {1, 2, 3, 4}.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(find.text('Row-4'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(controller.selectedRows, <int>{1, 2, 3, 4});

        // ArrowDown -> moves focus & selection to Row-5.
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pump();
        expect(controller.selectedRows, <int>{5});

        // Enter -> activates focused Row-5.
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(activatedRow, 5);

        // End key -> jumps to last row (Row-19) and scrolls it into view.
        await tester.sendKeyEvent(LogicalKeyboardKey.end);
        await tester.pumpAndSettle();
        expect(controller.selectedRows, <int>{19});
        expect(find.text('Row-19'), findsOneWidget);

        // Ctrl+A -> selects all 20 rows.
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();
        expect(controller.selectedCount, 20);

        // Escape -> clears selection.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();
        expect(controller.selectedCount, 0);

        controller.dispose();
      },
    );
  });

  group('Natural Value Comparator & DenseStyle', () {
    test('compareDenseValues orders numbers, nulls, and natural strings', () {
      expect(compareDenseValues(2, 10), lessThan(0));
      expect(compareDenseValues('9.5 ms', '12.0 ms'), lessThan(0));
      expect(compareDenseValues('Event #2', 'Event #10'), lessThan(0));
      expect(compareDenseValues('abc', null), lessThan(0));
      expect(compareDenseValues(null, 'abc'), greaterThan(0));
    });

    test('DenseStyle.light and copyWith preserve equality semantics', () {
      const dark = DenseStyle.dark();
      const light = DenseStyle.light();
      expect(dark, isNot(equals(light)));
      expect(dark.copyWith(rowHeight: 28.0).rowHeight, 28.0);
    });
  });

  group('Stable Row Identity (v1.1.0 rowIdBuilder & Off-Screen Focus)', () {
    testWidgets(
      'Shift+Click extends from the exact same record across external filtering and sorting',
      (tester) async {
        final controller = DenseTableController();
        var records = <(String, int, String)>[
          ('pod-alpha', 30, 'Pending'),
          ('pod-bravo', 40, 'Running'),
          ('pod-charlie', 10, 'Running'),
          ('pod-delta', 50, 'Degraded'),
          ('pod-echo', 20, 'Running'),
          ('pod-foxtrot', 60, 'Running'),
        ];
        var latestSelectedIds = const <Object>{};

        Widget buildFilteredTable() {
          return _wrapTestHarness(
            SizedBox(
              width: 640,
              height: 320,
              child: DenseTable.builder(
                controller: controller,
                autofocus: true,
                selectionMode: DenseSelectionMode.multi,
                showCheckboxColumn: true,
                rowCount: records.length,
                rowIdBuilder: (row) => records[row].$1,
                rawCellValue: (row, col) => switch (col) {
                  0 => records[row].$1,
                  1 => records[row].$2,
                  _ => records[row].$3,
                },
                onSelectedIdsChanged: (ids) => latestSelectedIds = ids,
                columns: const <DenseColumn>[
                  DenseColumn(title: 'Pod', initialWidth: 180),
                  DenseColumn(title: 'Latency', initialWidth: 120),
                  DenseColumn(title: 'Phase', initialWidth: 120),
                ],
                cellBuilder: (context, row, col) => switch (col) {
                  0 => Text(records[row].$1),
                  1 => Text('${records[row].$2}'),
                  _ => Text(records[row].$3),
                },
              ),
            ),
          );
        }

        await tester.pumpWidget(buildFilteredTable());
        await tester.pumpAndSettle();

        // Click 'pod-bravo' (original index 1 in unfiltered list).
        await tester.tap(find.text('pod-bravo'));
        await tester.pump();
        expect(controller.anchorRowId, 'pod-bravo');
        expect(controller.anchorRow, 1);
        expect(controller.selectedRowIds, <Object>{'pod-bravo'});

        // Apply external filter: keep only 'Running' pods!
        // Filtered order:
        //   0: ('pod-bravo', 40)
        //   1: ('pod-charlie', 10)
        //   2: ('pod-echo', 20)
        //   3: ('pod-foxtrot', 60)
        records = records.where((r) => r.$3 == 'Running').toList();
        await tester.pumpWidget(buildFilteredTable());
        await tester.pumpAndSettle();

        // Anchor moved from index 1 -> index 0 automatically via 'pod-bravo'!
        expect(controller.anchorRowId, 'pod-bravo');
        expect(controller.anchorRow, 0);
        expect(controller.selectedRows, <int>{0});

        // Sort by Latency ascending (column 1):
        // Visual order becomes:
        //   visual 0: pod-charlie (10)
        //   visual 1: pod-echo (20)
        //   visual 2: pod-bravo (40)  <-- anchor!
        //   visual 3: pod-foxtrot (60)
        await tester.tap(find.text('Latency'));
        await tester.pump();

        // Shift+Click 'pod-charlie' (visual 0) -> must select visual 0..2:
        // {'pod-charlie', 'pod-echo', 'pod-bravo'}, NOT 'pod-foxtrot'!
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.tap(find.text('pod-charlie'));
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();

        expect(
          controller.selectedRowIds,
          <Object>{'pod-charlie', 'pod-echo', 'pod-bravo'},
        );
        expect(
          latestSelectedIds,
          <Object>{'pod-charlie', 'pod-echo', 'pod-bravo'},
        );
        expect(controller.anchorRowId, 'pod-bravo');

        controller.dispose();
      },
    );

    testWidgets(
      'retains hidden selectedRowIds across filters and scopes toggleSelectAllVisible',
      (tester) async {
        final controller = DenseTableController(
          initialSelectedRowIds: const <Object>{'row-hidden'},
        );
        var items = <String>['row-hidden', 'row-vis-1', 'row-vis-2'];

        Widget buildView() {
          return _wrapTestHarness(
            SizedBox(
              width: 500,
              height: 260,
              child: DenseTable.builder(
                controller: controller,
                selectionMode: DenseSelectionMode.multi,
                showCheckboxColumn: true,
                rowCount: items.length,
                rowIdBuilder: (i) => items[i],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'ID', initialWidth: 240),
                ],
                cellBuilder: (_, row, __) => Text(items[row]),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        expect(controller.selectedRows, <int>{0});
        expect(controller.selectedRowIds, <Object>{'row-hidden'});

        // Filter out 'row-hidden' -> hidden ID remains preserved!
        items = <String>['row-vis-1', 'row-vis-2'];
        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();

        expect(controller.selectedCount, 0);
        expect(controller.totalSelectedIdCount, 1);
        expect(controller.isRowIdSelected('row-hidden'), isTrue);

        // Select all visible rows, then toggleSelectAllVisible off ->
        // removes 'row-vis-1' & 'row-vis-2', while preserving 'row-hidden'!
        controller.toggleSelectAllVisible(items.length);
        expect(
          controller.selectedRowIds,
          <Object>{'row-hidden', 'row-vis-1', 'row-vis-2'},
        );

        controller.toggleSelectAllVisible(items.length);
        expect(controller.selectedCount, 0);
        expect(controller.selectedRowIds, <Object>{'row-hidden'});

        // Restore full dataset -> 'row-hidden' re-highlights automatically!
        items = <String>['row-hidden', 'row-vis-1', 'row-vis-2'];
        await tester.pumpWidget(buildView());
        await tester.pumpAndSettle();
        expect(controller.selectedRows, <int>{0});

        controller.dispose();
      },
    );

    testWidgets(
      'live streaming insertions shift indices while keeping selection, focus, and scrollToRowId bound',
      (tester) async {
        final controller = DenseTableController();
        var streamRows = <String>['pod-1', 'pod-2', 'pod-3'];

        Widget buildStreamTable() {
          return _wrapTestHarness(
            SizedBox(
              width: 500,
              height: 240,
              child: DenseTable.builder(
                controller: controller,
                selectionMode: DenseSelectionMode.multi,
                rowCount: streamRows.length,
                rowIdBuilder: (i) => streamRows[i],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'Name', initialWidth: 240),
                ],
                cellBuilder: (_, row, __) => Text(streamRows[row]),
              ),
            ),
          );
        }

        await tester.pumpWidget(buildStreamTable());
        await tester.pumpAndSettle();

        controller.selectRowId('pod-2');
        expect(controller.selectedRows, <int>{1});
        expect(controller.focusedRow, 1);
        expect(controller.indexOfRowId('pod-2'), 1);

        // Prepend 2 new pods at the top of the live stream!
        streamRows = <String>['pod-new-a', 'pod-new-b', ...streamRows];
        await tester.pumpWidget(buildStreamTable());
        await tester.pumpAndSettle();

        expect(controller.selectedRows, <int>{3});
        expect(controller.focusedRow, 3);
        expect(controller.anchorRow, 3);
        expect(controller.indexOfRowId('pod-2'), 3);

        controller.setFocusedRowId('pod-new-b', updateAnchor: true);
        expect(controller.focusedRow, 1);
        expect(controller.anchorRowId, 'pod-new-b');

        controller.toggleRowId('pod-new-a');
        expect(controller.selectedRowIds, <Object>{'pod-2', 'pod-new-a'});

        controller.setSelectedRowIds(
          const <Object>{'pod-3'},
          focusedRowId: 'pod-3',
        );
        expect(controller.selectedRows, <int>{4});
        controller.scrollToRowId('pod-3');
        await tester.pump();

        controller.dispose();
      },
    );

    testWidgets(
      'retains keyboard focus when focused row scrolls 50,000 rows off-screen and snaps back on ArrowDown',
      (tester) async {
        final controller = DenseTableController();
        final focusNode = FocusNode();
        final verticalScroll = ScrollController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 600,
              height: 240,
              child: DenseTable.builder(
                controller: controller,
                focusNode: focusNode,
                verticalScrollController: verticalScroll,
                autofocus: true,
                selectionMode: DenseSelectionMode.multi,
                rowCount: 100000,
                rowIdBuilder: (i) => 'id-$i',
                columns: const <DenseColumn>[
                  DenseColumn(title: 'ID', initialWidth: 200),
                ],
                cellBuilder: (_, row, __) => Text('id-$row'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Click row 2 ('id-2') -> focused & table owns FocusNode.
        await tester.tap(find.text('id-2'));
        await tester.pump();
        expect(focusNode.hasFocus, isTrue);
        expect(controller.focusedRow, 2);

        // Scroll 50,000 rows away so 'id-2' is unmounted far off-screen!
        controller.scrollToVisualRow(50000);
        await tester.pumpAndSettle();
        expect(find.text('id-2'), findsNothing);
        expect(find.text('id-50000'), findsOneWidget);

        // FocusNode MUST remain focused on the table container!
        expect(focusNode.hasFocus, isTrue);

        // Pressing ArrowDown advances to row 3 ('id-3') and snaps viewport back!
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.pumpAndSettle();
        expect(controller.focusedRow, 3);
        expect(controller.focusedRowId, 'id-3');
        expect(find.text('id-3'), findsOneWidget);

        controller.dispose();
        focusNode.dispose();
        verticalScroll.dispose();
      },
    );
  });
}
