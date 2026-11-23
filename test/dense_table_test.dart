import 'package:dense_table/dense_table.dart';
import 'package:flutter/gestures.dart';
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

  group(
      'Header Customization, Toggle Sort Cycle & Virtualized RowSpan (v1.2.0)',
      () {
    testWidgets(
      'supports DenseSortCycle.toggle, initialSortDirection, inline unsorted icons, activeHeaderTextStyle, and headerBuilder',
      (tester) async {
        final controller = DenseTableController();
        final seenDirections = <DenseSortDirection?>[];

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 640,
              height: 260,
              child: DenseTable(
                controller: controller,
                sortCycle: DenseSortCycle.toggle,
                style: const DenseStyle(
                  showUnsortedSortIcon: true,
                  sortIconInline: true,
                  activeHeaderTextStyle: TextStyle(
                    color: Color(0xFF38BDF8),
                    fontSize: 12.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                sortIconBuilder: (context, direction) {
                  seenDirections.add(direction);
                  final label = switch (direction) {
                    null => 'SORT_IDLE',
                    DenseSortDirection.ascending => 'SORT_ASC',
                    DenseSortDirection.descending => 'SORT_DESC',
                  };
                  return Text(label);
                },
                headers: const <String>['Fav', 'Cluster', 'Modified'],
                columns: <DenseColumn>[
                  DenseColumn(
                    title: 'Fav',
                    initialWidth: 50,
                    headerKey: const ValueKey<String>('hdr_fav'),
                    headerBuilder: (context, col, idx, dir) {
                      return Text(dir == null ? 'STAR' : 'STAR_${dir.name}');
                    },
                  ),
                  const DenseColumn(
                    title: 'Cluster',
                    initialWidth: 200,
                    headerKey: ValueKey<String>('hdr_cluster'),
                  ),
                  const DenseColumn(
                    title: 'Modified',
                    initialWidth: 160,
                    initialSortDirection: DenseSortDirection.descending,
                    headerKey: ValueKey<String>('hdr_modified'),
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>[1, 'alpha', 100],
                  <dynamic>[0, 'bravo', 300],
                  <dynamic>[1, 'charlie', 200],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Unsorted indicators rendered for Cluster & Modified; custom headerBuilder for Fav.
        expect(find.text('STAR'), findsOneWidget);
        expect(find.text('SORT_IDLE'), findsNWidgets(2));
        expect(seenDirections, contains(null));

        // Tap 'Modified' -> starts at initialSortDirection (descending) because configured!
        await tester.tap(find.byKey(const ValueKey<String>('hdr_modified')));
        await tester.pumpAndSettle();
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 2,
            direction: DenseSortDirection.descending,
          ),
        );
        expect(find.text('SORT_DESC'), findsOneWidget);
        expect(
          tester.getTopLeft(find.text('bravo')).dy,
          lessThan(tester.getTopLeft(find.text('charlie')).dy),
        );

        // Second tap on 'Modified' with DenseSortCycle.toggle -> flips to ascending (never null!).
        await tester.tap(find.byKey(const ValueKey<String>('hdr_modified')));
        await tester.pumpAndSettle();
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 2,
            direction: DenseSortDirection.ascending,
          ),
        );
        expect(find.text('SORT_ASC'), findsOneWidget);

        // Third tap on 'Modified' -> flips back to descending!
        await tester.tap(find.byKey(const ValueKey<String>('hdr_modified')));
        await tester.pumpAndSettle();
        expect(
          controller.sortState?.direction,
          DenseSortDirection.descending,
        );

        // Tap 'Fav' -> triggers headerBuilder with active ascending direction!
        await tester.tap(find.byKey(const ValueKey<String>('hdr_fav')));
        await tester.pumpAndSettle();
        expect(find.text('STAR_ascending'), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'virtualizes multi-row RowSpan across 100,000 rows without losing merged labels off-screen',
      (tester) async {
        final controller = DenseTableController();
        var mergedBuilds = 0;
        int? tappedRow;

        // Group every 50 consecutive rows into a merged Namespace span (2,000 spans across 100,000 rows).
        DenseRowSpan? resolveSpan(int visualRow, int col) {
          if (col == 0) {
            final groupStart = (visualRow ~/ 50) * 50;
            return DenseRowSpan(
              startRow: groupStart,
              rowSpan: 50,
              backgroundColor: const Color(0x1438BDF8),
            );
          }
          return null;
        }

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 640,
              height: 300,
              child: DenseTable.builder(
                controller: controller,
                enableSorting: false,
                rowSpanBuilder: resolveSpan,
                onRowTap: (row) => tappedRow = row,
                style: const DenseStyle(
                  rowHeight: 30.0,
                  showUnsortedSortIcon: true,
                ),
                rowCount: 100000,
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'Namespace',
                    initialWidth: 180,
                    alignment: Alignment.center,
                  ),
                  DenseColumn(title: 'Pod', initialWidth: 260),
                ],
                cellBuilder: (context, row, col) {
                  if (col == 0) {
                    mergedBuilds++;
                    return Text('ns-${row ~/ 50}');
                  }
                  return Text('pod-$row');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Only 1 merged cell ('ns-0') is mounted for rows 0..49 in a 300px viewport!
        expect(find.text('ns-0'), findsOneWidget);
        expect(mergedBuilds, lessThan(5));

        // Scroll to row 25 (middle of the 0..49 span, so startRow 0 is 750px above viewport!).
        // 'ns-0' MUST remain mounted and visible inside the viewport!
        controller.scrollToVisualRow(25);
        await tester.pumpAndSettle();
        expect(find.text('pod-0'), findsNothing);
        expect(find.text('pod-25'), findsOneWidget);
        expect(find.text('ns-0'), findsOneWidget);

        // Tapping a row still passes straight through to onRowTap!
        await tester.tap(find.text('pod-26'));
        await tester.pump();
        expect(tappedRow, 26);

        // Jump to row 99,990 (span 1999: rows 99,950..99,999).
        controller.scrollToVisualRow(99990);
        await tester.pumpAndSettle();
        expect(find.text('ns-1999'), findsOneWidget);
        expect(find.text('pod-99990'), findsOneWidget);

        expect(
          const DenseRowSpan(startRow: 0, rowSpan: 10),
          equals(const DenseRowSpan(startRow: 0, rowSpan: 10)),
        );

        controller.dispose();
      },
    );
  });

  group('v1.3 Spreadsheet-Style Inline Cell Editing & Dirty Staging', () {
    testWidgets(
      'supports double-click & F2 entry, Enter commit + move down, and Escape cancel with table focus retention',
      (tester) async {
        final controller = DenseTableController();
        final tableFocus = FocusNode();
        final committed = <DenseCellChange>[];
        var activatedCount = 0;

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 600,
              height: 260,
              child: DenseTable(
                controller: controller,
                focusNode: tableFocus,
                selectionMode: DenseSelectionMode.single,
                onCellEditCommitted: committed.add,
                onRowActivated: (_) => activatedCount++,
                headers: const <String>['ID', 'Service', 'Port'],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'ID', initialWidth: 80),
                  DenseColumn(
                    title: 'Service',
                    initialWidth: 220,
                    editable: true,
                  ),
                  DenseColumn(
                    title: 'Port',
                    initialWidth: 120,
                    editable: true,
                    alignment: Alignment.centerRight,
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>[1, 'auth-api', 8080],
                  <dynamic>[2, 'billing-worker', 9090],
                  <dynamic>[3, 'cache-proxy', 6379],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Double-clicking a non-editable column ('ID') triggers row activation, NOT editing.
        await tester.tap(find.text('1'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.text('1'));
        await tester.pump();
        expect(controller.isEditing, isFalse);
        expect(activatedCount, 1);

        // Double-clicking editable 'Service' cell (0, 1) opens EditableText without firing onRowActivated.
        await tester.tap(find.text('auth-api'));
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(find.text('auth-api'));
        await tester.pump();

        expect(controller.isEditing, isTrue);
        expect(controller.editingCell, const DenseCellCoord(0, 1));
        expect(activatedCount, 1);
        expect(find.byType(EditableText), findsOneWidget);

        // Type new service name and commit via Enter -> moves focus to row 1, col 1.
        await tester.enterText(find.byType(EditableText), 'identity-api');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(controller.isEditing, isFalse);
        expect(tableFocus.hasFocus, isTrue);
        expect(committed.length, 1);
        expect(committed.single.coord, const DenseCellCoord(0, 1));
        expect(committed.single.previousValue, 'auth-api');
        expect(committed.single.newText, 'identity-api');
        expect(controller.isCellDirty(0, 1), isTrue);
        expect(find.text('identity-api'), findsOneWidget);
        expect(controller.focusedRow, 1);
        expect(controller.focusedColumn, 1);

        // Press F2 on focused row 1, col 1 -> enter draft -> Escape cancels without committing.
        await tester.sendKeyEvent(LogicalKeyboardKey.f2);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(1, 1));

        await tester.enterText(find.byType(EditableText), 'aborted-draft');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pump();

        expect(controller.isEditing, isFalse);
        expect(tableFocus.hasFocus, isTrue);
        expect(committed.length, 1);
        expect(controller.isCellDirty(1, 1), isFalse);
        expect(find.text('billing-worker'), findsOneWidget);

        tableFocus.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'navigates editable columns via Tab & Shift+Tab with row wrapping and 2D horizontal auto-scroll',
      (tester) async {
        final controller = DenseTableController();
        final hScroll = ScrollController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 320,
              height: 240,
              child: DenseTable(
                controller: controller,
                horizontalScrollController: hScroll,
                expandLastColumn: false,
                headers: const <String>[
                  'PK',
                  'Name',
                  'System',
                  'ReqCPU',
                  'LimMem',
                ],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'PK', initialWidth: 70),
                  DenseColumn(title: 'Name', initialWidth: 140, editable: true),
                  DenseColumn(
                    title: 'System',
                    initialWidth: 120,
                    editable: false,
                  ),
                  DenseColumn(
                    title: 'ReqCPU',
                    initialWidth: 160,
                    editable: true,
                  ),
                  DenseColumn(
                    title: 'LimMem',
                    initialWidth: 200,
                    editable: true,
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>['r0', 'api', 'locked', '100m', '256Mi'],
                  <dynamic>['r1', 'web', 'locked', '200m', '512Mi'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(hScroll.offset, 0.0);
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(0, 1));

        await tester.enterText(find.byType(EditableText), 'api-v2');
        await tester.pump();

        // Tab -> commits (0, 1), skips non-editable col 2 ('System'), opens (0, 3) ('ReqCPU').
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(0, 3));
        expect(controller.dirtyTextAt(0, 1), 'api-v2');

        await tester.enterText(find.byType(EditableText), '250m');
        await tester.pump();

        // Tab -> commits (0, 3) and opens off-screen right column (0, 4) ('LimMem'), scrolling horizontally!
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(0, 4));
        expect(hScroll.offset, greaterThan(150.0));

        await tester.enterText(find.byType(EditableText), '1024Mi');
        await tester.pump();

        // Tab at end of row 0 -> wraps to first editable column of row 1: (1, 1) and scrolls back left!
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(1, 1));
        expect(hScroll.offset, lessThan(100.0));
        expect(controller.dirtyCellCount, 3);

        // Shift+Tab from (1, 1) -> wraps backward to (0, 4) with '1024Mi' loaded!
        await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(0, 4));
        final editor = tester.widget<EditableText>(find.byType(EditableText));
        expect(editor.controller.text, '1024Mi');

        hScroll.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'enforces cell validator, clears error on edit, and clears dirty state when reverted to baseline',
      (tester) async {
        final controller = DenseTableController();
        final committed = <DenseCellChange>[];

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 500,
              height: 220,
              child: DenseTable(
                controller: controller,
                onCellEditCommitted: committed.add,
                headers: const <String>['ID', 'Replicas'],
                columns: <DenseColumn>[
                  const DenseColumn(title: 'ID', initialWidth: 100),
                  DenseColumn(
                    title: 'Replicas',
                    initialWidth: 160,
                    editable: true,
                    validator: (_, __, ___, draft) {
                      final parsed = int.tryParse(draft);
                      if (parsed == null || parsed < 0) {
                        return 'Replicas must be a non-negative integer';
                      }
                      return null;
                    },
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>['deploy-1', 3],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();

        // Invalid input blocks commit and exposes editingError.
        await tester.enterText(find.byType(EditableText), '-5');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(controller.isEditing, isTrue);
        expect(
          controller.editingError,
          'Replicas must be a non-negative integer',
        );
        expect(committed, isEmpty);
        expect(controller.hasDirtyCells, isFalse);

        // Typing valid text immediately clears editingError, and Enter commits.
        await tester.enterText(find.byType(EditableText), '8');
        await tester.pump();
        expect(controller.editingError, isNull);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(controller.isEditing, isFalse);
        expect(controller.dirtyCellCount, 1);
        expect(controller.dirtyChangeAt(0, 1)?.previousValue, 3);
        expect(controller.dirtyTextAt(0, 1), '8');

        // Editing a second time to '12' preserves baseline previousValue == 3.
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), '12');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(controller.dirtyChangeAt(0, 1)?.previousValue, 3);
        expect(controller.dirtyTextAt(0, 1), '12');

        // Editing back to baseline '3' automatically clears dirty state!
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), '3');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(controller.hasDirtyCells, isFalse);
        expect(controller.dirtyCellCount, 0);

        controller.dispose();
      },
    );

    testWidgets(
      'reconciles dirtyCells across external filtering via rowIdBuilder and honors canEditCell',
      (tester) async {
        final controller = DenseTableController();
        final allRecords = <({String id, String role})>[
          (id: 'u-1', role: 'system'),
          (id: 'u-2', role: 'viewer'),
          (id: 'u-3', role: 'editor'),
        ];
        var filterQuery = '';

        late StateSetter rebuildHost;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setHostState) {
              rebuildHost = setHostState;
              final visible = allRecords
                  .where(
                      (r) => filterQuery.isEmpty || r.id.contains(filterQuery))
                  .toList(growable: false);

              return _wrapTestHarness(
                SizedBox(
                  width: 500,
                  height: 240,
                  child: DenseTable.builder(
                    controller: controller,
                    rowCount: visible.length,
                    rowIdBuilder: (row) => visible[row].id,
                    rawCellValue: (row, col) =>
                        col == 0 ? visible[row].id : visible[row].role,
                    canEditCell: (row, col) => visible[row].id != 'u-1',
                    columns: const <DenseColumn>[
                      DenseColumn(title: 'ID', initialWidth: 120),
                      DenseColumn(
                        title: 'Role',
                        initialWidth: 200,
                        editable: true,
                      ),
                    ],
                    cellBuilder: (context, row, col) => Text(
                      col == 0 ? visible[row].id : visible[row].role,
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // System row 'u-1' is blocked by canEditCell.
        expect(controller.startEditing(0, 1), isFalse);

        // Edit 'u-3' (initially row 2) -> 'admin'.
        expect(controller.startEditing(2, 1), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), 'admin');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();

        expect(controller.isCellDirty(2, 1), isTrue);
        expect(find.text('admin'), findsOneWidget);

        // Filter to 'u-3' -> 'u-3' shifts to row index 0, dirty state follows 'u-3'!
        rebuildHost(() => filterQuery = 'u-3');
        await tester.pumpAndSettle();
        expect(controller.dirtyCellCount, 1);
        expect(controller.isCellDirty(0, 1), isTrue);
        expect(find.text('admin'), findsOneWidget);

        // Filter to 'u-2' -> 'u-3' is hidden, but allDirtyChanges & totalDirtyCellCount retain it!
        rebuildHost(() => filterQuery = 'u-2');
        await tester.pumpAndSettle();
        expect(controller.dirtyCellCount, 0);
        expect(controller.totalDirtyCellCount, 1);
        expect(controller.allDirtyChanges.single.rowId, 'u-3');
        expect(controller.allDirtyChanges.single.newText, 'admin');

        // Clear filter -> 'u-3' returns at index 2 with dirty 'admin' intact!
        rebuildHost(() => filterQuery = '');
        await tester.pumpAndSettle();
        expect(controller.dirtyCellCount, 1);
        expect(controller.isCellDirty(2, 1), isTrue);
        expect(find.text('admin'), findsOneWidget);

        controller.clearDirtyCells();
        await tester.pump();
        expect(controller.hasDirtyCells, isFalse);
        expect(find.text('editor'), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'preserves active inline draft across 100,000-row off-screen scroll and supports custom editorBuilder',
      (tester) async {
        final controller = DenseTableController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 600,
              height: 260,
              child: DenseTable.builder(
                controller: controller,
                editTrigger: DenseEditTrigger.singleTap,
                rowCount: 100000,
                rawCellValue: (row, col) =>
                    col == 0 ? 'Row $row' : (col == 1 ? 'val-$row' : 'IDLE'),
                columns: <DenseColumn>[
                  const DenseColumn(title: 'Key', initialWidth: 140),
                  const DenseColumn(
                    title: 'Value',
                    initialWidth: 220,
                    editable: true,
                  ),
                  DenseColumn(
                    title: 'Mode',
                    initialWidth: 160,
                    editable: true,
                    editorBuilder: (context, editCtx) {
                      return GestureDetector(
                        key: const ValueKey<String>('custom_enum_pick'),
                        onTap: () => editCtx.commit('TURBO'),
                        child: Text('PICK:${editCtx.initialText}'),
                      );
                    },
                  ),
                ],
                cellBuilder: (context, row, col) {
                  if (col == 0) {
                    return Text('Row $row');
                  }
                  if (col == 1) {
                    return Text('val-$row');
                  }
                  return const Text('IDLE');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Single-tap on 'val-0' (DenseEditTrigger.singleTap) immediately opens editor!
        await tester.tap(find.text('val-0'));
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(0, 1));

        await tester.enterText(
          find.byType(EditableText),
          'draft-survives-100k-scroll',
        );
        await tester.pump();

        // Scroll far off-screen to row 50,000 and back to row 0!
        controller.scrollToVisualRow(50000);
        await tester.pumpAndSettle();
        expect(find.text('Row 50000'), findsOneWidget);
        expect(controller.isEditing, isTrue);

        controller.scrollToVisualRow(0);
        await tester.pumpAndSettle();
        expect(controller.editingCell, const DenseCellCoord(0, 1));
        expect(
          tester
              .widget<EditableText>(find.byType(EditableText))
              .controller
              .text,
          'draft-survives-100k-scroll',
        );

        // Commit via controller.commitEditing()!
        expect(controller.commitEditing(), isTrue);
        await tester.pump();
        expect(find.text('draft-survives-100k-scroll'), findsOneWidget);

        // Single-tap custom editorBuilder column (0, 2) and commit custom enum!
        await tester.tap(find.text('IDLE').first);
        await tester.pump();
        expect(find.text('PICK:IDLE'), findsOneWidget);
        await tester
            .tap(find.byKey(const ValueKey<String>('custom_enum_pick')));
        await tester.pump();
        expect(controller.isEditing, isFalse);
        expect(controller.dirtyTextAt(0, 2), 'TURBO');
        expect(find.text('TURBO'), findsOneWidget);

        controller.dispose();
      },
    );

    testWidgets(
      'reconciles active editor, column focus, sortState, and dirtyCells when columns shrink dynamically, and aligns editValueGetter baseline revert',
      (tester) async {
        final controller = DenseTableController();
        var useWideSchema = true;
        late StateSetter rebuildHost;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setHostState) {
              rebuildHost = setHostState;
              final cols = useWideSchema
                  ? const <DenseColumn>[
                      DenseColumn(title: 'Pod', initialWidth: 120),
                      DenseColumn(
                        title: 'CPU',
                        initialWidth: 140,
                        editable: true,
                      ),
                      DenseColumn(
                        title: 'Memory',
                        initialWidth: 140,
                        editable: true,
                      ),
                    ]
                  : const <DenseColumn>[
                      DenseColumn(title: 'Pod', initialWidth: 120),
                    ];
              return _wrapTestHarness(
                SizedBox(
                  width: 500,
                  height: 220,
                  child: DenseTable.builder(
                    controller: controller,
                    rowCount: 2,
                    rowIdBuilder: (row) => 'pod-$row',
                    rawCellValue: (row, col) {
                      if (col == 0) {
                        return 'pod-$row';
                      }
                      if (col == 1) {
                        return 250 + row * 100; // numeric sort key
                      }
                      return 512;
                    },
                    editValueGetter: (row, col) {
                      if (col == 1) {
                        return '${250 + row * 100}m'; // formatted unit string
                      }
                      if (col == 2) {
                        return '512Mi';
                      }
                      return 'pod-$row';
                    },
                    columns: cols,
                    cellBuilder: (context, row, col) {
                      if (col == 0) {
                        return Text('pod-$row');
                      }
                      if (col == 1) {
                        return Text('${250 + row * 100}m');
                      }
                      return const Text('512Mi');
                    },
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // 1. Edit formatted CPU column (0, 1): numeric previousValue == 250, baselineText == '250m'.
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), '500m');
        await tester.pump();
        expect(controller.commitEditing(), isTrue);
        await tester.pump();

        expect(controller.isCellDirty(0, 1), isTrue);
        expect(controller.dirtyChangeAt(0, 1)?.previousValue, 250);
        expect(controller.dirtyChangeAt(0, 1)?.baselineText, '250m');

        // Reverting back to '250m' clears dirty state even though rawCellValue is int 250!
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), '250m');
        await tester.pump();
        expect(controller.commitEditing(), isTrue);
        await tester.pump();
        expect(controller.isCellDirty(0, 1), isFalse);

        // 2. Stage dirty edit on col 2, sort by col 2, and open active editor on col 2.
        expect(controller.startEditing(0, 2), isTrue);
        await tester.pump();
        await tester.enterText(find.byType(EditableText), '1024Mi');
        await tester.pump();
        expect(controller.commitEditing(), isTrue);
        await tester.pump();
        controller.setSort(
          const DenseSortState(
            columnIndex: 2,
            direction: DenseSortDirection.descending,
          ),
        );
        await tester.pump();
        expect(controller.startEditing(1, 2), isTrue);
        await tester.pump();
        expect(controller.editingCell, const DenseCellCoord(1, 2));

        // 3. Shrink schema from 3 columns down to 1 column while editing col 2!
        rebuildHost(() => useWideSchema = false);
        await tester.pumpAndSettle();

        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);
        expect(controller.focusedColumn, 0);
        expect(controller.sortState, isNull);
        expect(controller.hasDirtyCells, isFalse);

        // 4. Unmounting DenseTable while controller is mid-edit clears editingCell on external controller.
        rebuildHost(() => useWideSchema = true);
        await tester.pumpAndSettle();
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        expect(controller.isEditing, isTrue);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump();
        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);

        controller.dispose();
      },
    );
  });

  group('Sort Clear Button for the 2-state toggle cycle (v1.4.0)', () {
    Future<DenseTableController> pumpClearableTable(
      WidgetTester tester, {
      required bool showSortClearButton,
      List<DenseSortState?>? sortChanges,
    }) async {
      final controller = DenseTableController();
      await tester.pumpWidget(
        _wrapTestHarness(
          SizedBox(
            width: 480,
            height: 260,
            child: DenseTable(
              controller: controller,
              sortCycle: DenseSortCycle.toggle,
              showSortClearButton: showSortClearButton,
              onSortChanged: sortChanges?.add,
              headers: const <String>['Name', 'Score'],
              columns: const <DenseColumn>[
                DenseColumn(
                  title: 'Name',
                  initialWidth: 200,
                  headerKey: ValueKey<String>('hdr_name'),
                ),
                DenseColumn(
                  title: 'Score',
                  initialWidth: 160,
                  headerKey: ValueKey<String>('hdr_score'),
                ),
              ],
              data: const <List<dynamic>>[
                <dynamic>['charlie', 3],
                <dynamic>['alpha', 1],
                <dynamic>['bravo', 2],
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return controller;
    }

    double rowY(WidgetTester tester, String name) =>
        tester.getTopLeft(find.text(name)).dy;

    testWidgets(
      'clear button appears only on the actively sorted header and restores the original row order',
      (tester) async {
        final changes = <DenseSortState?>[];
        final controller = await pumpClearableTable(
          tester,
          showSortClearButton: true,
          sortChanges: changes,
        );
        const clearName = ValueKey<String>('dense_clear_sort_0');
        const clearScore = ValueKey<String>('dense_clear_sort_1');

        // Unsorted: no clear button anywhere.
        expect(find.byKey(clearName), findsNothing);
        expect(find.byKey(clearScore), findsNothing);
        expect(rowY(tester, 'charlie'), lessThan(rowY(tester, 'alpha')));

        // Sort by Name ascending -> clear button only on Name.
        await tester.tap(find.byKey(const ValueKey<String>('hdr_name')));
        await tester.pumpAndSettle();
        expect(find.byKey(clearName), findsOneWidget);
        expect(find.byKey(clearScore), findsNothing);
        expect(rowY(tester, 'alpha'), lessThan(rowY(tester, 'charlie')));

        // The 2-state toggle never leaves the sorted state on header taps.
        await tester.tap(find.byKey(const ValueKey<String>('hdr_name')));
        await tester.pumpAndSettle();
        expect(controller.sortState?.direction, DenseSortDirection.descending);
        expect(find.byKey(clearName), findsOneWidget);

        // Tapping the clear button returns to the original order.
        await tester.tap(find.byKey(clearName));
        await tester.pumpAndSettle();
        expect(controller.sortState, isNull);
        expect(find.byKey(clearName), findsNothing);
        expect(rowY(tester, 'charlie'), lessThan(rowY(tester, 'alpha')));
        expect(rowY(tester, 'alpha'), lessThan(rowY(tester, 'bravo')));
        expect(changes.last, isNull);
        expect(changes.whereType<DenseSortState>(), isNotEmpty);

        controller.dispose();
      },
    );

    testWidgets(
      'no clear button by default and DenseTableController.clearSort() resets sorting',
      (tester) async {
        final controller = await pumpClearableTable(
          tester,
          showSortClearButton: false,
        );
        await tester.tap(find.byKey(const ValueKey<String>('hdr_score')));
        await tester.pumpAndSettle();
        expect(controller.sortState?.columnIndex, 1);
        expect(
          find.byKey(const ValueKey<String>('dense_clear_sort_1')),
          findsNothing,
        );

        controller.clearSort();
        await tester.pumpAndSettle();
        expect(controller.sortState, isNull);
        expect(rowY(tester, 'charlie'), lessThan(rowY(tester, 'alpha')));

        controller.dispose();
      },
    );
  });

  group('Frozen Leading Columns (v1.5.0)', () {
    testWidgets(
      'pins leading header and cells during horizontal scroll, keeps checkbox clickable, supports frozen resize, and calls cellBuilder once per visible cell',
      (tester) async {
        final controller = DenseTableController();
        final hScroll = ScrollController();
        final buildCounts = <(int, int), int>{};
        int? resizedCol;
        double? resizedWidth;

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 502,
              height: 300,
              child: DenseTable.builder(
                controller: controller,
                horizontalScrollController: hScroll,
                selectionMode: DenseSelectionMode.multi,
                showCheckboxColumn: true,
                frozenColumnCount: 1,
                expandLastColumn: false,
                onColumnResized: (col, width) {
                  resizedCol = col;
                  resizedWidth = width;
                },
                rowCount: 6,
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'ID',
                    initialWidth: 120,
                    headerKey: ValueKey<String>('f_hdr_0'),
                  ),
                  DenseColumn(
                    title: 'Col1',
                    initialWidth: 180,
                    headerKey: ValueKey<String>('f_hdr_1'),
                  ),
                  DenseColumn(
                    title: 'Col2',
                    initialWidth: 180,
                    headerKey: ValueKey<String>('f_hdr_2'),
                  ),
                  DenseColumn(
                    title: 'Col3',
                    initialWidth: 200,
                    headerKey: ValueKey<String>('f_hdr_3'),
                  ),
                  DenseColumn(
                    title: 'Col4',
                    initialWidth: 200,
                    headerKey: ValueKey<String>('f_hdr_4'),
                  ),
                ],
                cellBuilder: (context, row, col) {
                  buildCounts[(row, col)] = (buildCounts[(row, col)] ?? 0) + 1;
                  return Text(
                    'r$row-c$col',
                    key: ValueKey<String>('f_cell_${row}_$col'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Every visible (row, col) cell must be built exactly once (no double build when pinned).
        for (var r = 0; r < 6; r++) {
          for (var c = 0; c < 5; c++) {
            expect(
              buildCounts[(r, c)],
              1,
              reason: 'Cell ($r, $c) must only be built once',
            );
          }
        }

        final tableTopLeft = tester.getTopLeft(find.byType(DenseTable));
        final innerLeft = tableTopLeft.dx + 1.0;
        final innerTop = tableTopLeft.dy + 1.0;

        final hdr0Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_hdr_0')),
        );
        final hdr1Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_hdr_1')),
        );
        final cell00Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_cell_0_0')),
        );
        final cell01Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_cell_0_1')),
        );

        // Checkbox (34px) + Col 0 (120px) occupy screen x = 0..154.
        expect(hdr0Before.dx, closeTo(innerLeft + 34.0, 0.5));
        expect(hdr1Before.dx, closeTo(innerLeft + 154.0, 0.5));

        // Scroll horizontally by 300px.
        hScroll.jumpTo(300.0);
        await tester.pumpAndSettle();
        expect(hScroll.offset, closeTo(300.0, 0.5));

        // Leading header, leading cell, and checkbox stay pinned; scrollable columns move left.
        final hdr0After = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_hdr_0')),
        );
        final hdr1After = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_hdr_1')),
        );
        final cell00After = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_cell_0_0')),
        );
        final cell01After = tester.getTopLeft(
          find.byKey(const ValueKey<String>('f_cell_0_1')),
        );

        expect(hdr0After.dx, closeTo(hdr0Before.dx, 0.5));
        expect(cell00After.dx, closeTo(cell00Before.dx, 0.5));
        expect(hdr1After.dx, closeTo(hdr1Before.dx - 300.0, 0.5));
        expect(cell01After.dx, closeTo(cell01Before.dx - 300.0, 0.5));

        // Horizontal scroll alone must not invoke cellBuilder again for visible cells.
        for (var r = 0; r < 6; r++) {
          for (var c = 0; c < 5; c++) {
            expect(buildCounts[(r, c)], 1);
          }
        }

        // Pinned row checkboxes and header select-all checkbox remain clickable while scrolled.
        await tester.tapAt(
          Offset(innerLeft + 17.0, innerTop + 28.0 + 12.0),
        );
        await tester.pump();
        expect(controller.selectedRows, <int>{0});

        await tester.tapAt(
          Offset(innerLeft + 17.0, innerTop + 28.0 + 24.0 + 12.0),
        );
        await tester.pump();
        expect(controller.selectedRows, <int>{0, 1});

        // Header select-all checkbox selects all 6 rows while scrolled horizontally.
        await tester.tapAt(Offset(innerLeft + 17.0, innerTop + 14.0));
        await tester.pump();
        expect(controller.selectedCount, 6);

        // Resize frozen column 0 while horizontally scrolled (right edge at innerLeft + 154).
        await tester.dragFrom(
          Offset(innerLeft + 152.0, innerTop + 14.0),
          const Offset(50.0, 0.0),
        );
        await tester.pumpAndSettle();

        expect(resizedCol, 0);
        expect(resizedWidth, closeTo(170.0, 2.0));
        expect(
          tester.getSize(find.byKey(const ValueKey<String>('f_hdr_0'))).width,
          closeTo(170.0, 2.0),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('f_hdr_0'))).dx,
          closeTo(innerLeft + 34.0, 0.5),
        );
        expect(hScroll.offset, closeTo(300.0, 0.5));

        hScroll.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'auto-disables pinning gracefully on narrow viewports (>= 85% pinned width)',
      (tester) async {
        final hScroll = ScrollController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 242, // viewportWidth = 240; 85% = 204
              height: 200,
              child: DenseTable.builder(
                horizontalScrollController: hScroll,
                frozenColumnCount: 1,
                pinActionsColumn: true,
                actionsWidth: 90,
                expandLastColumn: false,
                rowCount: 3,
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'ID',
                    initialWidth: 140, // 140 + 90 = 230 >= 204 -> fallback
                    headerKey: ValueKey<String>('narrow_hdr_0'),
                  ),
                  DenseColumn(
                    title: 'Name',
                    initialWidth: 180,
                    headerKey: ValueKey<String>('narrow_hdr_1'),
                  ),
                ],
                cellBuilder: (_, row, col) => Text('n-$row-$col'),
                rowActionsBuilder: (_, row) => Text('act-$row'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        final hdr0Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('narrow_hdr_0')),
        );
        final act0Before = tester.getTopLeft(find.text('act-0'));

        hScroll.jumpTo(120.0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Both leading column and trailing actions scroll flatly without overlapping.
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('narrow_hdr_0')))
              .dx,
          closeTo(hdr0Before.dx - 120.0, 0.5),
        );
        expect(
          tester.getTopLeft(find.text('act-0')).dx,
          closeTo(act0Before.dx - 120.0, 0.5),
        );

        // frozenColumnCount exceeding total column count also falls back cleanly.
        final clampScroll = ScrollController();
        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 300,
              height: 180,
              child: DenseTable(
                horizontalScrollController: clampScroll,
                frozenColumnCount: 10,
                expandLastColumn: false,
                headers: const <String>['A', 'B'],
                columnWidths: const <int, double>{0: 200, 1: 200},
                data: const <List<dynamic>>[
                  <dynamic>['a0', 'b0'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        clampScroll.jumpTo(80.0);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        clampScroll.dispose();
        hScroll.dispose();
      },
    );

    testWidgets(
      'pins frozen RowSpan merged cell and clips scrollable RowSpan merged cell at the freeze boundary',
      (tester) async {
        final hScroll = ScrollController();

        DenseRowSpan? resolveSpan(int visualRow, int col) {
          if (col == 0 || col == 1) {
            final start = (visualRow ~/ 3) * 3;
            return DenseRowSpan(
              startRow: start,
              rowSpan: 3,
              backgroundColor: const Color(0x2238BDF8),
            );
          }
          return null;
        }

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 462, // viewportWidth = 460
              height: 260,
              child: DenseTable.builder(
                horizontalScrollController: hScroll,
                frozenColumnCount: 1,
                expandLastColumn: false,
                rowSpanBuilder: resolveSpan,
                rowCount: 6,
                columns: const <DenseColumn>[
                  DenseColumn(title: 'FrozenSpan', initialWidth: 120),
                  DenseColumn(title: 'ScrollSpan', initialWidth: 150),
                  DenseColumn(title: 'Pod', initialWidth: 200),
                  DenseColumn(title: 'Node', initialWidth: 200),
                ],
                cellBuilder: (_, row, col) {
                  if (col == 0) {
                    return Text(
                      'frozen-ns-${row ~/ 3}',
                      key: ValueKey<String>('frozen_span_${row ~/ 3}'),
                    );
                  }
                  if (col == 1) {
                    return Text(
                      'scroll-grp-${row ~/ 3}',
                      key: ValueKey<String>('scroll_span_${row ~/ 3}'),
                    );
                  }
                  return Text('cell-$row-$col');
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final innerLeft = tester.getTopLeft(find.byType(DenseTable)).dx + 1.0;
        final frozenSpanFinder =
            find.byKey(const ValueKey<String>('frozen_span_0'));
        final scrollSpanFinder =
            find.byKey(const ValueKey<String>('scroll_span_0'));

        final frozenBefore = tester.getTopLeft(frozenSpanFinder);
        final scrollBefore = tester.getTopLeft(scrollSpanFinder);

        hScroll.jumpTo(100.0);
        await tester.pumpAndSettle();

        // Frozen merged cell translates with horizontal scroll so its screen X stays pinned.
        final frozenAfter = tester.getTopLeft(frozenSpanFinder);
        expect(frozenAfter.dx, closeTo(frozenBefore.dx, 0.5));
        final frozenPositioned = tester.widget<Positioned>(
          find
              .ancestor(
                of: frozenSpanFinder,
                matching: find.byType(Positioned),
              )
              .first,
        );
        expect(frozenPositioned.left, closeTo(100.0, 0.5));

        // Scrollable merged cell shifts left and is clipped by a ClipRect at the freeze boundary.
        final scrollAfter = tester.getTopLeft(scrollSpanFinder);
        expect(scrollAfter.dx, closeTo(scrollBefore.dx - 100.0, 0.5));
        final scrollClipFinder = find
            .ancestor(
              of: scrollSpanFinder,
              matching: find.byType(ClipRect),
            )
            .first;
        expect(
          tester.getTopLeft(scrollClipFinder).dx,
          closeTo(innerLeft + 120.0, 0.5),
        );
        expect(
          tester.getSize(scrollClipFinder).width,
          closeTo(460.0 - 120.0, 0.5),
        );

        hScroll.dispose();
      },
    );

    testWidgets(
      'double-clicking a frozen editable cell while scrolled edits the frozen column, and editing scrollable columns scrolls into the unoccluded center band',
      (tester) async {
        final controller = DenseTableController();
        final hScroll = ScrollController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 462, // viewportWidth = 460
              height: 240,
              child: DenseTable.builder(
                controller: controller,
                horizontalScrollController: hScroll,
                frozenColumnCount: 1,
                pinActionsColumn: true,
                actionsWidth: 90,
                expandLastColumn: false,
                rowCount: 3,
                rawCellValue: (row, col) => 'v-$row-$col',
                columns: const <DenseColumn>[
                  DenseColumn(title: 'Key', initialWidth: 110, editable: true),
                  DenseColumn(title: 'ColA', initialWidth: 130, editable: true),
                  DenseColumn(title: 'ColB', initialWidth: 130, editable: true),
                  DenseColumn(title: 'ColC', initialWidth: 150, editable: true),
                  DenseColumn(title: 'ColD', initialWidth: 150, editable: true),
                ],
                cellBuilder: (_, row, col) => Text('v-$row-$col'),
                rowActionsBuilder: (_, row) => Text('op-$row'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final tableTopLeft = tester.getTopLeft(find.byType(DenseTable));
        final innerLeft = tableTopLeft.dx + 1.0;
        final innerTop = tableTopLeft.dy + 1.0;

        // Scroll horizontally so scrollable ColB (x=240..370) sits behind frozen Col 0.
        hScroll.jumpTo(250.0);
        await tester.pumpAndSettle();

        // Double-click inside frozen Col 0 (screen x = innerLeft + 50).
        final frozenTapPoint = Offset(innerLeft + 50.0, innerTop + 28.0 + 12.0);
        await tester.tapAt(frozenTapPoint);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tapAt(frozenTapPoint);
        await tester.pumpAndSettle();

        expect(controller.isEditing, isTrue);
        expect(controller.editingCell, const DenseCellCoord(0, 0));
        final frozenEditorRect = tester.getRect(find.byType(EditableText));
        expect(frozenEditorRect.left, greaterThanOrEqualTo(innerLeft));
        expect(frozenEditorRect.right, lessThanOrEqualTo(innerLeft + 110.0));

        // Cancel frozen edit.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        expect(controller.isEditing, isFalse);

        // Start editing Col 1 (currently occluded behind frozen Col 0) -> scrolls left into center band.
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pumpAndSettle();
        expect(hScroll.offset, closeTo(0.0, 0.5));
        final col1EditorRect = tester.getRect(find.byType(EditableText));
        expect(col1EditorRect.left, greaterThanOrEqualTo(innerLeft + 110.0));
        expect(col1EditorRect.right, lessThanOrEqualTo(innerLeft + 370.0));

        // Start editing Col 4 (off-screen past pinned right actions) -> scrolls right into center band.
        expect(controller.startEditing(0, 4), isTrue);
        await tester.pumpAndSettle();
        expect(hScroll.offset, closeTo(300.0, 0.5));
        final col4EditorRect = tester.getRect(find.byType(EditableText));
        expect(col4EditorRect.left, greaterThanOrEqualTo(innerLeft + 110.0));
        expect(col4EditorRect.right, lessThanOrEqualTo(innerLeft + 370.0));

        hScroll.dispose();
        controller.dispose();
      },
    );
  });

  group('Pinned Trailing Actions Column (v1.5.0)', () {
    testWidgets(
      'pins actions header and body with custom alignment/header/padding, prevents underlying cell edits, calls rowActionsBuilder once, and does not pin checkbox when frozenColumnCount == 0',
      (tester) async {
        final controller = DenseTableController();
        final hScroll = ScrollController();
        final actionTaps = <int>[];
        final actionBuildCounts = <int, int>{};

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 462, // viewportWidth = 460
              height: 300,
              child: DenseTable.builder(
                controller: controller,
                horizontalScrollController: hScroll,
                selectionMode: DenseSelectionMode.multi,
                showCheckboxColumn: true,
                frozenColumnCount: 0,
                pinActionsColumn: true,
                actionsWidth: 100,
                actionsAlignment: Alignment.centerRight,
                actionsHeaderChild: const Text(
                  'OPS',
                  key: ValueKey<String>('pin_act_hdr'),
                ),
                actionsCellPadding: const EdgeInsets.only(right: 12.0),
                expandLastColumn: false,
                rowCount: 5,
                rawCellValue: (row, col) => 'r$row-c$col',
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'A',
                    initialWidth: 160,
                    editable: true,
                    headerKey: ValueKey<String>('pa_hdr_0'),
                  ),
                  DenseColumn(
                    title: 'B',
                    initialWidth: 160,
                    editable: true,
                    headerKey: ValueKey<String>('pa_hdr_1'),
                  ),
                  DenseColumn(
                    title: 'C',
                    initialWidth: 160,
                    editable: true,
                    headerKey: ValueKey<String>('pa_hdr_2'),
                  ),
                  DenseColumn(
                    title: 'D',
                    initialWidth: 160,
                    editable: true,
                    headerKey: ValueKey<String>('pa_hdr_3'),
                  ),
                ],
                cellBuilder: (_, row, col) => Text('r$row-c$col'),
                rowActionsBuilder: (_, row) {
                  actionBuildCounts[row] = (actionBuildCounts[row] ?? 0) + 1;
                  return GestureDetector(
                    key: ValueKey<String>('pin_act_btn_$row'),
                    onTap: () => actionTaps.add(row),
                    child: const SizedBox(
                      width: 36,
                      height: 18,
                      child: Text('Run'),
                    ),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // rowActionsBuilder called exactly once per visible row.
        for (var r = 0; r < 5; r++) {
          expect(actionBuildCounts[r], 1);
        }

        // Custom actionsHeaderChild replaces default 'Actions' label.
        expect(
            find.byKey(const ValueKey<String>('pin_act_hdr')), findsOneWidget);
        expect(find.text('Actions'), findsNothing);

        final tableTopLeft = tester.getTopLeft(find.byType(DenseTable));
        final innerLeft = tableTopLeft.dx + 1.0;
        final innerTop = tableTopLeft.dy + 1.0;

        // Alignment.centerRight + actionsCellPadding(right: 12) places header & button right at V - 12.
        final expectedRight = innerLeft + 460.0 - 12.0;
        expect(
          tester
              .getTopRight(find.byKey(const ValueKey<String>('pin_act_hdr')))
              .dx,
          closeTo(expectedRight, 0.5),
        );
        expect(
          tester
              .getTopRight(find.byKey(const ValueKey<String>('pin_act_btn_0')))
              .dx,
          closeTo(expectedRight, 0.5),
        );

        // Locate leading header checkbox (14x14 CustomPaint) before scrolling.
        final checkboxFinder = find.descendant(
          of: find.byType(DenseTable),
          matching: find.byWidgetPredicate(
            (w) => w is CustomPaint && w.size == const Size(14.0, 14.0),
          ),
        );
        final headerCheckboxBefore = tester.getTopLeft(checkboxFinder.first);
        final hdr0Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('pa_hdr_0')),
        );

        // Scroll horizontally by 200px.
        hScroll.jumpTo(200.0);
        await tester.pumpAndSettle();

        // Actions header and body remain pinned at the right viewport edge.
        expect(
          tester
              .getTopRight(find.byKey(const ValueKey<String>('pin_act_hdr')))
              .dx,
          closeTo(expectedRight, 0.5),
        );
        expect(
          tester
              .getTopRight(find.byKey(const ValueKey<String>('pin_act_btn_0')))
              .dx,
          closeTo(expectedRight, 0.5),
        );

        // Horizontal scroll does not re-invoke rowActionsBuilder.
        for (var r = 0; r < 5; r++) {
          expect(actionBuildCounts[r], 1);
        }

        // Because frozenColumnCount == 0, checkbox column scrolled left (NOT pinned).
        expect(
          tester.getTopLeft(checkboxFinder.first).dx,
          closeTo(headerCheckboxBefore.dx - 200.0, 0.5),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('pa_hdr_0'))).dx,
          closeTo(hdr0Before.dx - 200.0, 0.5),
        );

        // Rapid double-tap on pinned action button hits the button and does NOT start editing.
        final btn0 = find.byKey(const ValueKey<String>('pin_act_btn_0'));
        await tester.tap(btn0);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(btn0);
        await tester.pumpAndSettle();
        expect(actionTaps, <int>[0, 0]);
        expect(controller.isEditing, isFalse);

        // Double-tapping empty padding inside the pinned actions cell also does NOT edit cells underneath.
        final emptyActionSpot = Offset(
          innerLeft + 460.0 - 90.0,
          innerTop + 28.0 + 12.0,
        );
        await tester.tapAt(emptyActionSpot);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tapAt(emptyActionSpot);
        await tester.pumpAndSettle();
        expect(controller.isEditing, isFalse);

        hScroll.dispose();
        controller.dispose();
      },
    );
  });

  group('Per-Column cellPadding (v1.5.0)', () {
    testWidgets(
      'renders EdgeInsets.zero column flush while sibling keeps style.cellPadding in header, body, and inline editor',
      (tester) async {
        final controller = DenseTableController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 400,
              height: 200,
              child: DenseTable.builder(
                controller: controller,
                expandLastColumn: false,
                style: const DenseStyle(
                  cellPadding: EdgeInsets.symmetric(horizontal: 12.0),
                ),
                rowCount: 2,
                rawCellValue: (row, col) => col == 0 ? 'F$row' : 'P$row',
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'Flush',
                    initialWidth: 120,
                    editable: true,
                    cellPadding: EdgeInsets.zero,
                    headerChild: Text(
                      'Flush',
                      key: ValueKey<String>('pad_hdr_flush'),
                    ),
                  ),
                  DenseColumn(
                    title: 'Padded',
                    initialWidth: 160,
                    editable: true,
                    headerChild: Text(
                      'Padded',
                      key: ValueKey<String>('pad_hdr_default'),
                    ),
                  ),
                ],
                cellBuilder: (_, row, col) => Text(
                  col == 0 ? 'F$row' : 'P$row',
                  key: ValueKey<String>('pad_body_${row}_$col'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final innerLeft = tester.getTopLeft(find.byType(DenseTable)).dx + 1.0;

        // Header geometry.
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('pad_hdr_flush')))
              .dx,
          closeTo(innerLeft, 0.5),
        );
        expect(
          tester
              .getTopLeft(
                find.byKey(const ValueKey<String>('pad_hdr_default')),
              )
              .dx,
          closeTo(innerLeft + 120.0 + 12.0, 0.5),
        );

        // Body geometry.
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('pad_body_0_0')))
              .dx,
          closeTo(innerLeft, 0.5),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('pad_body_0_1')))
              .dx,
          closeTo(innerLeft + 120.0 + 12.0, 0.5),
        );

        // Inline editor geometry for flush column (0px horizontal padding).
        expect(controller.startEditing(0, 0), isTrue);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(EditableText)).dx,
          closeTo(innerLeft, 0.5),
        );

        // Inline editor geometry for default-padded sibling column (12px horizontal padding).
        expect(controller.startEditing(0, 1), isTrue);
        await tester.pumpAndSettle();
        expect(
          tester.getTopLeft(find.byType(EditableText)).dx,
          closeTo(innerLeft + 120.0 + 12.0, 0.5),
        );

        controller.dispose();
      },
    );
  });

  group('Column Visibility (v1.5.0 DenseColumn.visible)', () {
    testWidgets(
      'omits hidden columns from header, layout, and cellBuilder while preserving logical column indices',
      (tester) async {
        final controller = DenseTableController();
        final builtCols = <int>{};
        final rawCols = <int>{};
        final committed = <DenseCellChange>[];

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 500,
              height: 220,
              child: DenseTable.builder(
                controller: controller,
                expandLastColumn: false,
                onCellEditCommitted: committed.add,
                rowCount: 3,
                rawCellValue: (row, col) {
                  rawCols.add(col);
                  return switch (col) {
                    0 => 'id-$row',
                    1 => 'secret-$row',
                    _ => 300 - row * 100,
                  };
                },
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'ID',
                    initialWidth: 100,
                    headerKey: ValueKey<String>('vis_hdr_0'),
                  ),
                  DenseColumn(
                    title: 'Secret',
                    initialWidth: 180,
                    visible: false,
                    editable: true,
                    headerKey: ValueKey<String>('vis_hdr_1'),
                  ),
                  DenseColumn(
                    title: 'Port',
                    initialWidth: 140,
                    editable: true,
                    headerKey: ValueKey<String>('vis_hdr_2'),
                  ),
                ],
                cellBuilder: (_, row, col) {
                  builtCols.add(col);
                  return Text(
                    col == 0 ? 'id-$row' : '${300 - row * 100}',
                    key: ValueKey<String>('vis_cell_${row}_$col'),
                  );
                },
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final innerLeft = tester.getTopLeft(find.byType(DenseTable)).dx + 1.0;

        // Hidden column 1 is absent from header, cellBuilder, and takes zero width.
        expect(find.byKey(const ValueKey<String>('vis_hdr_1')), findsNothing);
        expect(find.text('Secret'), findsNothing);
        expect(builtCols, <int>{0, 2});
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('vis_hdr_2'))).dx,
          closeTo(innerLeft + 100.0, 0.5),
        );

        // Sorting visible col 2 reports logical columnIndex == 2 to sortState & rawCellValue.
        await tester.tap(find.byKey(const ValueKey<String>('vis_hdr_2')));
        await tester.pumpAndSettle();
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 2,
            direction: DenseSortDirection.ascending,
          ),
        );
        expect(rawCols, contains(2));
        expect(rawCols, isNot(contains(1)));

        // Editing visible col 2 reports logical columnIndex == 2 in onCellEditCommitted.
        final cellFinder = find.byKey(const ValueKey<String>('vis_cell_0_2'));
        await tester.tap(cellFinder);
        await tester.pump(const Duration(milliseconds: 40));
        await tester.tap(cellFinder);
        await tester.pumpAndSettle();
        expect(controller.editingCell, const DenseCellCoord(0, 2));

        await tester.enterText(find.byType(EditableText), '9090');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(committed.single.coord, const DenseCellCoord(0, 2));
        expect(committed.single.newText, '9090');

        controller.dispose();
      },
    );

    testWidgets(
      'preserves resized widths, sortState, and dirtyCells across visible toggle, and cancels active edit while restoring table focus',
      (tester) async {
        final controller = DenseTableController();
        final tableFocus = FocusNode();
        var showCol1 = true;
        late StateSetter rebuildHost;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setHostState) {
              rebuildHost = setHostState;
              return _wrapTestHarness(
                SizedBox(
                  width: 560,
                  height: 240,
                  child: DenseTable.builder(
                    controller: controller,
                    focusNode: tableFocus,
                    expandLastColumn: false,
                    rowCount: 3,
                    rawCellValue: (row, col) => switch (col) {
                      0 => 'r$row',
                      1 => 30 - row * 10,
                      _ => 'tail-$row',
                    },
                    columns: <DenseColumn>[
                      const DenseColumn(
                        title: 'ID',
                        initialWidth: 100,
                        headerKey: ValueKey<String>('tog_hdr_0'),
                      ),
                      DenseColumn(
                        title: 'Score',
                        initialWidth: 120,
                        visible: showCol1,
                        editable: true,
                        headerKey: const ValueKey<String>('tog_hdr_1'),
                      ),
                      const DenseColumn(
                        title: 'Tail',
                        initialWidth: 140,
                        headerKey: ValueKey<String>('tog_hdr_2'),
                      ),
                    ],
                    cellBuilder: (_, row, col) => Text(
                      col == 0
                          ? 'r$row'
                          : (col == 1 ? '${30 - row * 10}' : 'tail-$row'),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final tableTopLeft = tester.getTopLeft(find.byType(DenseTable));
        final innerLeft = tableTopLeft.dx + 1.0;
        final innerTop = tableTopLeft.dy + 1.0;

        // 1. Resize col 1 from 120 -> 200, sort by col 1, and stage a dirty edit on (0, 1).
        await tester.dragFrom(
          Offset(innerLeft + 219.0, innerTop + 14.0),
          const Offset(80.0, 0.0),
        );
        await tester.pumpAndSettle();
        expect(
          tester.getSize(find.byKey(const ValueKey<String>('tog_hdr_1'))).width,
          closeTo(200.0, 2.0),
        );

        await tester.tap(find.byKey(const ValueKey<String>('tog_hdr_1')));
        await tester.pumpAndSettle();
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 1,
            direction: DenseSortDirection.ascending,
          ),
        );

        expect(controller.startEditing(0, 1), isTrue);
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(EditableText), '99');
        await tester.pump();
        expect(controller.commitEditing(), isTrue);
        await tester.pumpAndSettle();
        expect(controller.dirtyTextAt(0, 1), '99');

        // 2. Open active editor on (1, 1), then hide col 1 -> cancels edit cleanly & restores focus.
        expect(controller.startEditing(1, 1), isTrue);
        await tester.pumpAndSettle();
        expect(controller.isEditing, isTrue);
        expect(find.byType(EditableText), findsOneWidget);

        rebuildHost(() => showCol1 = false);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(controller.isEditing, isFalse);
        expect(controller.editingCell, isNull);
        expect(find.byType(EditableText), findsNothing);
        expect(tableFocus.hasFocus, isTrue);
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 1,
            direction: DenseSortDirection.ascending,
          ),
        );
        expect(controller.dirtyTextAt(0, 1), '99');

        // 3. Re-show col 1 -> resized width, sortState, and dirtyCells are all intact.
        rebuildHost(() => showCol1 = true);
        await tester.pumpAndSettle();

        expect(
          tester.getSize(find.byKey(const ValueKey<String>('tog_hdr_1'))).width,
          closeTo(200.0, 2.0),
        );
        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 1,
            direction: DenseSortDirection.ascending,
          ),
        );
        expect(controller.dirtyTextAt(0, 1), '99');
        expect(find.text('99'), findsOneWidget);

        tableFocus.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'skips hidden columns during ArrowLeft/ArrowRight navigation and renders safely when all columns are hidden',
      (tester) async {
        final controller = DenseTableController();
        var hideAll = false;
        late StateSetter rebuildHost;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setHostState) {
              rebuildHost = setHostState;
              return _wrapTestHarness(
                SizedBox(
                  width: 480,
                  height: 220,
                  child: DenseTable.builder(
                    controller: controller,
                    autofocus: true,
                    selectionMode: DenseSelectionMode.multi,
                    showCheckboxColumn: true,
                    frozenColumnCount: 1,
                    pinActionsColumn: true,
                    rowSpanBuilder: (vRow, col) => col == 0 && vRow < 2
                        ? const DenseRowSpan(startRow: 0, rowSpan: 2)
                        : null,
                    rowCount: 3,
                    rawCellValue: (row, col) => 'v-$row-$col',
                    columns: <DenseColumn>[
                      DenseColumn(
                        title: 'C0',
                        initialWidth: 100,
                        editable: true,
                        visible: !hideAll,
                      ),
                      const DenseColumn(
                        title: 'C1',
                        initialWidth: 100,
                        editable: true,
                        visible: false,
                      ),
                      const DenseColumn(
                        title: 'C2',
                        initialWidth: 100,
                        editable: true,
                        visible: false,
                      ),
                      DenseColumn(
                        title: 'C3',
                        initialWidth: 120,
                        editable: true,
                        visible: !hideAll,
                      ),
                    ],
                    cellBuilder: (_, row, col) => Text('v-$row-$col'),
                    rowActionsBuilder: (_, row) => Text('a$row'),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        // Focus unmerged cell (2, 0), then ArrowRight must jump directly across hidden C1 & C2 to C3.
        await tester.tap(find.text('v-2-0'));
        await tester.pump();
        expect(controller.focusedColumn, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.focusedColumn, 3);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pump();
        expect(controller.focusedColumn, 3);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.focusedColumn, 0);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pump();
        expect(controller.focusedColumn, 0);

        // Hide every column -> renders safely and handles keys without RangeError/StateError.
        rebuildHost(() => hideAll = true);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        controller.dispose();
      },
    );

    testWidgets(
      'pins visible column cleanly with zero gaps when earlier frozen columns are hidden',
      (tester) async {
        final hScroll = ScrollController();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 462,
              height: 220,
              child: DenseTable.builder(
                horizontalScrollController: hScroll,
                frozenColumnCount: 2,
                expandLastColumn: false,
                rowCount: 3,
                columns: const <DenseColumn>[
                  DenseColumn(
                    title: 'Hidden0',
                    initialWidth: 100,
                    visible: false,
                    headerKey: ValueKey<String>('ifh_hdr_0'),
                  ),
                  DenseColumn(
                    title: 'Frozen1',
                    initialWidth: 120,
                    visible: true,
                    headerKey: ValueKey<String>('ifh_hdr_1'),
                  ),
                  DenseColumn(
                    title: 'Scroll2',
                    initialWidth: 180,
                    headerKey: ValueKey<String>('ifh_hdr_2'),
                  ),
                  DenseColumn(
                    title: 'Scroll3',
                    initialWidth: 200,
                    headerKey: ValueKey<String>('ifh_hdr_3'),
                  ),
                  DenseColumn(
                    title: 'Scroll4',
                    initialWidth: 200,
                    headerKey: ValueKey<String>('ifh_hdr_4'),
                  ),
                ],
                cellBuilder: (_, row, col) => Text(
                  'r$row-c$col',
                  key: ValueKey<String>('ifh_cell_${row}_$col'),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final innerLeft = tester.getTopLeft(find.byType(DenseTable)).dx + 1.0;

        // Col 0 is hidden -> Col 1 starts flush at innerLeft + 0 with zero gap.
        expect(find.byKey(const ValueKey<String>('ifh_hdr_0')), findsNothing);
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('ifh_hdr_1'))).dx,
          closeTo(innerLeft, 0.5),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('ifh_hdr_2'))).dx,
          closeTo(innerLeft + 120.0, 0.5),
        );
        final cell01Before = tester.getTopLeft(
          find.byKey(const ValueKey<String>('ifh_cell_0_1')),
        );
        expect(cell01Before.dx, closeTo(innerLeft + 8.0, 0.5));

        hScroll.jumpTo(200.0);
        await tester.pumpAndSettle();

        // Col 1 stays pinned at innerLeft; Col 2 scrolls left by 200px.
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('ifh_hdr_1'))).dx,
          closeTo(innerLeft, 0.5),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('ifh_cell_0_1')))
              .dx,
          closeTo(cell01Before.dx, 0.5),
        );
        expect(
          tester.getTopLeft(find.byKey(const ValueKey<String>('ifh_hdr_2'))).dx,
          closeTo(innerLeft + 120.0 - 200.0, 0.5),
        );

        hScroll.dispose();
      },
    );
  });

  group('Zero-Dependency Clipboard Copy (v1.5.0)', () {
    List<String?> installClipboardMock(WidgetTester tester) {
      final writes = <String?>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (MethodCall call) async {
          if (call.method == 'Clipboard.setData') {
            final args = call.arguments as Map<Object?, Object?>?;
            writes.add(args?['text'] as String?);
          }
          return null;
        },
      );
      addTearDown(() {
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        );
      });
      return writes;
    }

    testWidgets(
      'copies focused or multi-selected rows in visual sorted order skipping hidden columns, supports copyValueBuilder and RFC-style TSV quoting',
      (tester) async {
        final clipboardWrites = installClipboardMock(tester);
        final controller = DenseTableController();
        final events = <DenseCopyEvent>[];

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 560,
              height: 240,
              child: DenseTable(
                controller: controller,
                autofocus: true,
                selectionMode: DenseSelectionMode.multi,
                onCopy: events.add,
                headers: const <String>['Name', 'Secret', 'Score'],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'Name', initialWidth: 160),
                  DenseColumn(
                    title: 'Secret',
                    initialWidth: 120,
                    visible: false,
                  ),
                  DenseColumn(
                    title: 'Score',
                    initialWidth: 120,
                    headerKey: ValueKey<String>('copy_hdr_score'),
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>['Gamma', 'hid-0', 30],
                  <dynamic>['Alpha', 'hid-1', 10],
                  <dynamic>['Delta', 'hid-2', 40],
                  <dynamic>['Beta', 'hid-3', 20],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Single focused row (no selection): copies exact TSV skipping hidden column 1.
        controller.setFocusedRow(1);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(
          events.last,
          const DenseCopyEvent(
            rowIndices: <int>[1],
            columnIndices: <int>[0, 2],
            text: 'Alpha\t10',
          ),
        );
        expect(clipboardWrites.last, 'Alpha\t10');

        // Multi-select original rows {0, 1, 3}, then sort ascending by Score -> visual order [1, 3, 0].
        controller.setSelectedRows(const <int>{0, 1, 3}, focusedRow: 0);
        await tester.tap(find.byKey(const ValueKey<String>('copy_hdr_score')));
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
        await tester.pump();

        expect(
          events.last,
          const DenseCopyEvent(
            rowIndices: <int>[1, 3, 0],
            columnIndices: <int>[0, 2],
            text: 'Alpha\t10\nBeta\t20\nGamma\t30',
          ),
        );
        expect(clipboardWrites.last, 'Alpha\t10\nBeta\t20\nGamma\t30');

        // Sort descending by Score -> visual order of selected rows flips to [0, 3, 1].
        await tester.tap(find.byKey(const ValueKey<String>('copy_hdr_score')));
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(events.last.rowIndices, <int>[0, 3, 1]);
        expect(events.last.text, 'Gamma\t30\nBeta\t20\nAlpha\t10');

        // Verify copyValueBuilder override and TSV quoting rules (quotes only \t/\n/\r, leaves plain JSON untouched).
        events.clear();
        clipboardWrites.clear();
        final customController = DenseTableController(
          initialSelectedRows: const <int>{0},
        );
        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 560,
              height: 200,
              child: DenseTable.builder(
                controller: customController,
                autofocus: true,
                selectionMode: DenseSelectionMode.single,
                onCopy: events.add,
                copyValueBuilder: (row, col) => switch (col) {
                  0 => '{"env":"prod","count":3}',
                  1 => 'tab\there',
                  2 => 'line1\n"quoted"\rline3',
                  _ => 'plain',
                },
                rowCount: 1,
                columns: const <DenseColumn>[
                  DenseColumn(title: 'Json', initialWidth: 140),
                  DenseColumn(title: 'Tab', initialWidth: 120),
                  DenseColumn(title: 'Multi', initialWidth: 140),
                  DenseColumn(title: 'Plain', initialWidth: 100),
                ],
                cellBuilder: (_, row, col) => Text('cell-$row-$col'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        const expectedTsv =
            '{"env":"prod","count":3}\t"tab\there"\t"line1\n""quoted""\rline3"\tplain';
        expect(events.single.text, expectedTsv);
        expect(clipboardWrites.single, expectedTsv);

        customController.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'does not intercept Cmd/Ctrl+C when enableCopyShortcut is false',
      (tester) async {
        final clipboardWrites = installClipboardMock(tester);
        final controller = DenseTableController(
          initialSelectedRows: const <int>{0},
        );
        final events = <DenseCopyEvent>[];
        var parentSawCtrlC = false;

        await tester.pumpWidget(
          _wrapTestHarness(
            Focus(
              onKeyEvent: (_, event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.keyC &&
                    HardwareKeyboard.instance.isControlPressed) {
                  parentSawCtrlC = true;
                  return KeyEventResult.handled;
                }
                return KeyEventResult.ignored;
              },
              child: SizedBox(
                width: 480,
                height: 200,
                child: DenseTable(
                  controller: controller,
                  autofocus: true,
                  selectionMode: DenseSelectionMode.single,
                  enableCopyShortcut: false,
                  onCopy: events.add,
                  headers: const <String>['ID', 'Name'],
                  data: const <List<dynamic>>[
                    <dynamic>[1, 'Alpha'],
                  ],
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(parentSawCtrlC, isTrue);
        expect(events, isEmpty);
        expect(clipboardWrites, isEmpty);

        controller.dispose();
      },
    );

    testWidgets(
      'ignores Cmd/Ctrl+C at table level while inline editing so EditableText handles it',
      (tester) async {
        final clipboardWrites = installClipboardMock(tester);
        final controller = DenseTableController(
          initialSelectedRows: const <int>{0},
        );
        final events = <DenseCopyEvent>[];

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 480,
              height: 200,
              child: DenseTable(
                controller: controller,
                autofocus: true,
                selectionMode: DenseSelectionMode.single,
                enableCopyShortcut: true,
                onCopy: events.add,
                headers: const <String>['ID', 'Name'],
                columns: const <DenseColumn>[
                  DenseColumn(title: 'ID', initialWidth: 100),
                  DenseColumn(
                    title: 'Name',
                    initialWidth: 200,
                    editable: true,
                  ),
                ],
                data: const <List<dynamic>>[
                  <dynamic>[1, 'Alpha'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(controller.startEditing(0, 1), isTrue);
        await tester.pumpAndSettle();
        expect(controller.isEditing, isTrue);

        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(controller.isEditing, isTrue);
        expect(events, isEmpty);
        expect(clipboardWrites, isNot(contains('1\tAlpha')));

        controller.dispose();
      },
    );

    test('DenseCopyEvent implements value equality, hashCode, and toString',
        () {
      const a = DenseCopyEvent(
        rowIndices: <int>[0, 2],
        columnIndices: <int>[0, 1],
        text: 'a\tb',
      );
      final b = DenseCopyEvent(
        rowIndices: List<int>.of(const <int>[0, 2]),
        columnIndices: List<int>.of(const <int>[0, 1]),
        text: 'a\tb',
      );
      const diffRows = DenseCopyEvent(
        rowIndices: <int>[0, 1],
        columnIndices: <int>[0, 1],
        text: 'a\tb',
      );
      const diffCols = DenseCopyEvent(
        rowIndices: <int>[0, 2],
        columnIndices: <int>[0, 2],
        text: 'a\tb',
      );
      const diffText = DenseCopyEvent(
        rowIndices: <int>[0, 2],
        columnIndices: <int>[0, 1],
        text: 'x\ty',
      );

      expect(identical(a, b), isFalse);
      expect(a, equals(a));
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(diffRows)));
      expect(a, isNot(equals(diffCols)));
      expect(a, isNot(equals(diffText)));
      expect(
        a.toString(),
        'DenseCopyEvent(rowIndices: [0, 2], columnIndices: [0, 1], text: a\tb)',
      );
    });
  });

  group('Secondary Tap Hygiene (v1.5.0)', () {
    testWidgets(
      'enables click cursor for onRowSecondaryTapDown alone and applies selectOnSecondaryTap preserving multi-selection',
      (tester) async {
        // 1. Plain non-interactive table uses MouseCursor.defer.
        await tester.pumpWidget(
          _wrapTestHarness(
            const SizedBox(
              width: 400,
              height: 180,
              child: DenseTable(
                headers: <String>['Name'],
                data: <List<dynamic>>[
                  <dynamic>['Row-0'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final deferCursor = tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.text('Row-0'),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            )
            .cursor;
        expect(deferCursor, MouseCursor.defer);

        // 2. onRowSecondaryTapDown alone enables SystemMouseCursors.click.
        final secondaryHits = <int>[];
        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 400,
              height: 180,
              child: DenseTable(
                onRowSecondaryTapDown: (row, _) => secondaryHits.add(row),
                headers: const <String>['Name'],
                data: const <List<dynamic>>[
                  <dynamic>['Row-0'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final clickCursor = tester
            .widget<MouseRegion>(
              find
                  .ancestor(
                    of: find.text('Row-0'),
                    matching: find.byType(MouseRegion),
                  )
                  .first,
            )
            .cursor;
        expect(clickCursor, SystemMouseCursors.click);

        // 3. selectOnSecondaryTap: true selects unselected row & preserves existing multi-selection.
        final controller = DenseTableController();
        final observedSelections = <Set<int>>[];
        secondaryHits.clear();

        await tester.pumpWidget(
          _wrapTestHarness(
            SizedBox(
              width: 400,
              height: 240,
              child: DenseTable(
                controller: controller,
                selectionMode: DenseSelectionMode.multi,
                selectOnSecondaryTap: true,
                onRowSecondaryTapDown: (row, _) {
                  secondaryHits.add(row);
                  observedSelections.add(Set<int>.of(controller.selectedRows));
                },
                headers: const <String>['Name'],
                data: const <List<dynamic>>[
                  <dynamic>['Row-0'],
                  <dynamic>['Row-1'],
                  <dynamic>['Row-2'],
                  <dynamic>['Row-3'],
                ],
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Right-click unselected Row-1 -> selects {1} before invoking onRowSecondaryTapDown.
        await tester.tap(
          find.text('Row-1'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        expect(controller.selectedRows, <int>{1});
        expect(controller.focusedRow, 1);
        expect(secondaryHits, <int>[1]);
        expect(observedSelections.last, <int>{1});

        // Multi-select {0, 1, 2}, then right-click already-selected Row-2 -> keeps {0, 1, 2}!
        controller.setSelectedRows(const <int>{0, 1, 2}, focusedRow: 0);
        await tester.pump();
        await tester.tap(
          find.text('Row-2'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        expect(controller.selectedRows, <int>{0, 1, 2});
        expect(controller.focusedRow, 2);
        expect(secondaryHits, <int>[1, 2]);
        expect(observedSelections.last, <int>{0, 1, 2});

        // Right-click unselected Row-3 -> replaces selection with {3}.
        await tester.tap(
          find.text('Row-3'),
          buttons: kSecondaryMouseButton,
        );
        await tester.pump();
        expect(controller.selectedRows, <int>{3});
        expect(controller.focusedRow, 3);
        expect(observedSelections.last, <int>{3});

        controller.dispose();
      },
    );
  });

  group('DenseStyle v1.5.0 Pinned Column Tokens', () {
    test(
      'provides expected defaults, copyWith, equality, hashCode, and rejects negative shadow width',
      () {
        const base = DenseStyle();
        const dark = DenseStyle.dark();
        const light = DenseStyle.light();

        expect(base.pinnedColumnDividerColor, isNull);
        expect(base.pinnedColumnShadowColor, const Color(0x4D000000));
        expect(base.pinnedColumnShadowWidth, 6.0);

        expect(dark.pinnedColumnDividerColor, isNull);
        expect(dark.pinnedColumnShadowColor, const Color(0x4D000000));
        expect(dark.pinnedColumnShadowWidth, 6.0);
        expect(base, equals(dark));
        expect(base.hashCode, equals(dark.hashCode));

        expect(light.pinnedColumnDividerColor, isNull);
        expect(light.pinnedColumnShadowColor, const Color(0x1F000000));
        expect(light.pinnedColumnShadowWidth, 6.0);

        final custom = base.copyWith(
          pinnedColumnDividerColor: const Color(0xFF4C8BF5),
          pinnedColumnShadowColor: const Color(0x66000000),
          pinnedColumnShadowWidth: 10.0,
        );
        const manual = DenseStyle(
          pinnedColumnDividerColor: Color(0xFF4C8BF5),
          pinnedColumnShadowColor: Color(0x66000000),
          pinnedColumnShadowWidth: 10.0,
        );
        expect(custom, equals(manual));
        expect(custom.hashCode, equals(manual.hashCode));
        expect(custom, isNot(equals(base)));
        expect(
          base.copyWith(pinnedColumnDividerColor: const Color(0xFF112233)),
          isNot(equals(base)),
        );
        expect(
          base.copyWith(pinnedColumnShadowColor: const Color(0xFF112233)),
          isNot(equals(base)),
        );
        expect(
          base.copyWith(pinnedColumnShadowWidth: 0.0).pinnedColumnShadowWidth,
          0.0,
        );

        expect(
          () => DenseStyle(pinnedColumnShadowWidth: -1.0),
          throwsAssertionError,
        );
        expect(
          () => DenseStyle.dark(pinnedColumnShadowWidth: -0.5),
          throwsAssertionError,
        );
        expect(
          () => DenseStyle.light(pinnedColumnShadowWidth: -2.0),
          throwsAssertionError,
        );
        expect(
          () => DenseTable(
            headers: const <String>['A'],
            data: const <List<dynamic>>[],
            frozenColumnCount: -1,
          ),
          throwsAssertionError,
        );
        expect(
          () => DenseTable.builder(
            columns: const <DenseColumn>[DenseColumn(title: 'A')],
            rowCount: 0,
            cellBuilder: (_, __, ___) => const SizedBox.shrink(),
            frozenColumnCount: -1,
          ),
          throwsAssertionError,
        );
      },
    );
  });

  group('100,000-Row Stress Test with v1.5.0 Features Active', () {
    testWidgets(
      'maintains O(1) virtualization across 100,000 rows with frozen column, pinned actions, visibility toggle, sort clear, horizontal/vertical scroll, and Cmd/Ctrl+C',
      (tester) async {
        final clipboardWrites = <String?>[];
        tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          (MethodCall call) async {
            if (call.method == 'Clipboard.setData') {
              final args = call.arguments as Map<Object?, Object?>?;
              clipboardWrites.add(args?['text'] as String?);
            }
            return null;
          },
        );
        addTearDown(() {
          tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
            SystemChannels.platform,
            null,
          );
        });

        final controller = DenseTableController();
        final hScroll = ScrollController();
        final copyEvents = <DenseCopyEvent>[];
        var builtCells = 0;
        var showNotesColumn = false;
        late StateSetter rebuildHost;

        await tester.pumpWidget(
          StatefulBuilder(
            builder: (context, setHostState) {
              rebuildHost = setHostState;
              return _wrapTestHarness(
                SizedBox(
                  width: 562, // viewportWidth = 560
                  height: 360,
                  child: DenseTable.builder(
                    controller: controller,
                    horizontalScrollController: hScroll,
                    autofocus: true,
                    selectionMode: DenseSelectionMode.multi,
                    frozenColumnCount: 1,
                    pinActionsColumn: true,
                    actionsWidth: 90,
                    sortCycle: DenseSortCycle.toggle,
                    showSortClearButton: true,
                    expandLastColumn: false,
                    onCopy: copyEvents.add,
                    rowCount: 100000,
                    rawCellValue: (row, col) => switch (col) {
                      0 => row,
                      1 => 'note-$row',
                      2 => 'svc-$row',
                      3 => row * 2,
                      _ => 'us-east-${row % 4}',
                    },
                    columns: <DenseColumn>[
                      const DenseColumn(
                        title: 'ID',
                        initialWidth: 100,
                        headerKey: ValueKey<String>('s100k_hdr_0'),
                      ),
                      DenseColumn(
                        title: 'Notes',
                        initialWidth: 140,
                        visible: showNotesColumn,
                        headerKey: const ValueKey<String>('s100k_hdr_1'),
                      ),
                      const DenseColumn(
                        title: 'Service',
                        initialWidth: 180,
                        headerKey: ValueKey<String>('s100k_hdr_2'),
                      ),
                      const DenseColumn(
                        title: 'Metric',
                        initialWidth: 160,
                        headerKey: ValueKey<String>('s100k_hdr_3'),
                      ),
                      const DenseColumn(
                        title: 'Region',
                        initialWidth: 180,
                        headerKey: ValueKey<String>('s100k_hdr_4'),
                      ),
                    ],
                    cellBuilder: (_, row, col) {
                      builtCells++;
                      return Text(switch (col) {
                        0 => 'ID-$row',
                        1 => 'note-$row',
                        2 => 'svc-$row',
                        3 => '${row * 2}',
                        _ => 'us-east-${row % 4}',
                      });
                    },
                    rowActionsBuilder: (_, row) => Text(
                      'op-$row',
                      key: ValueKey<String>('s100k_act_$row'),
                    ),
                  ),
                ),
              );
            },
          ),
        );
        await tester.pumpAndSettle();

        final innerLeft = tester.getTopLeft(find.byType(DenseTable)).dx + 1.0;

        // O(1) initial virtualization: far fewer than 400 cells built out of 500,000.
        expect(builtCells, lessThan(400));
        expect(find.text('ID-0'), findsOneWidget);
        expect(find.text('ID-99900'), findsNothing);
        expect(find.byKey(const ValueKey<String>('s100k_hdr_1')), findsNothing);

        // Horizontal scroll + vertical O(1) jump to row 99,900.
        hScroll.jumpTo(220.0);
        controller.scrollToVisualRow(99900);
        await tester.pumpAndSettle();

        expect(find.text('ID-99900'), findsOneWidget);
        expect(find.text('ID-0'), findsNothing);
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('s100k_hdr_0')))
              .dx,
          closeTo(innerLeft, 0.5),
        );
        expect(
          tester.getTopLeft(find.text('ID-99900')).dx,
          closeTo(innerLeft + 8.0, 0.5),
        );
        expect(
          tester
              .getTopLeft(find.byKey(const ValueKey<String>('s100k_act_99900')))
              .dx,
          greaterThan(innerLeft + 460.0),
        );

        // Toggle DenseColumn.visible dynamically at row 99,900.
        rebuildHost(() => showNotesColumn = true);
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey<String>('s100k_hdr_1')),
          findsOneWidget,
        );

        rebuildHost(() => showNotesColumn = false);
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey<String>('s100k_hdr_1')), findsNothing);

        // Sort 100,000 rows descending by ID via frozen header taps and scroll to top.
        controller.scrollToVisualRow(0);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ID'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('ID'));
        await tester.pumpAndSettle();

        expect(
          controller.sortState,
          const DenseSortState(
            columnIndex: 0,
            direction: DenseSortDirection.descending,
          ),
        );
        expect(find.text('ID-99999'), findsOneWidget);

        // Select rows {99997, 99999} and copy via Ctrl+C -> visual descending order, skipping hidden col 1.
        controller
            .setSelectedRows(const <int>{99997, 99999}, focusedRow: 99999);
        await tester.pump();
        await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
        await tester.sendKeyEvent(LogicalKeyboardKey.keyC);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
        await tester.pump();

        expect(
          copyEvents.single,
          const DenseCopyEvent(
            rowIndices: <int>[99999, 99997],
            columnIndices: <int>[0, 2, 3, 4],
            text:
                '99999\tsvc-99999\t199998\tus-east-3\n99997\tsvc-99997\t199994\tus-east-1',
          ),
        );
        expect(clipboardWrites.single, copyEvents.single.text);

        // Clear sort via clear button on frozen header -> returns to natural order.
        await tester.tap(
          find.byKey(const ValueKey<String>('dense_clear_sort_0')),
        );
        await tester.pumpAndSettle();
        expect(controller.sortState, isNull);
        expect(find.text('ID-0'), findsOneWidget);

        // Also confirm programmatic clearSort() works after sorting.
        controller.setSort(
          const DenseSortState(
            columnIndex: 0,
            direction: DenseSortDirection.descending,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('ID-99999'), findsOneWidget);
        controller.clearSort();
        await tester.pumpAndSettle();
        expect(controller.sortState, isNull);
        expect(find.text('ID-0'), findsOneWidget);

        expect(tester.takeException(), isNull);
        expect(builtCells, lessThan(5000));

        hScroll.dispose();
        controller.dispose();
      },
    );

    testWidgets(
      'preserves external controller delegates across single-frame widget reparenting',
      (tester) async {
        final controller = DenseTableController();
        final vScroll = ScrollController();

        Widget buildTable() {
          return SizedBox(
            width: 480,
            height: 200,
            child: DenseTable.builder(
              controller: controller,
              verticalScrollController: vScroll,
              rowCount: 100,
              rowIdBuilder: (row) => 'rec-$row',
              rawCellValue: (row, col) => col == 0 ? 'rec-$row' : 'val-$row',
              columns: const <DenseColumn>[
                DenseColumn(title: 'ID', initialWidth: 140),
                DenseColumn(title: 'Value', initialWidth: 200, editable: true),
              ],
              cellBuilder: (_, row, col) =>
                  Text(col == 0 ? 'rec-$row' : 'val-$row'),
            ),
          );
        }

        await tester.pumpWidget(_wrapTestHarness(Focus(child: buildTable())));
        await tester.pumpAndSettle();

        // Reparent without the Focus wrapper in a single frame: new state mounts
        // before old state disposes.
        await tester.pumpWidget(_wrapTestHarness(buildTable()));
        await tester.pumpAndSettle();

        expect(controller.startEditing(0, 1), isTrue);
        await tester.pump();
        expect(controller.isEditing, isTrue);
        controller.cancelEditing();
        await tester.pump();

        controller.scrollToRow(60);
        await tester.pumpAndSettle();
        expect(vScroll.offset, greaterThan(0.0));
        expect(controller.rowIdAt(60), 'rec-60');

        vScroll.dispose();
        controller.dispose();
      },
    );
  });
}
