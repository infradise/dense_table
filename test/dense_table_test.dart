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
  });
}
