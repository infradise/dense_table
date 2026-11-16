import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'dense_column.dart';
import 'dense_controller.dart';
import 'dense_style.dart';

/// Signature for building trailing action widgets for a row in [DenseTable].
typedef DenseRowActionsBuilder = Widget Function(
  int rowIndex,
  List<dynamic> rowData,
);

/// Signature for building trailing action widgets by original row index in
/// [DenseTable.builder].
typedef DenseIndexedRowActionsBuilder = Widget Function(
  BuildContext context,
  int rowIndex,
);

/// High-density, zero-dependency virtualized data table widget for Flutter.
///
/// [DenseTable] renders 100,000+ rows smoothly using fixed-extent `O(1)`
/// viewport virtualization while supporting:
/// - Interactive drag-to-resize columns with double-click width reset
/// - Synchronized 2D horizontal & vertical desktop scrollbars
/// - Click-to-sort columns (`ascending -> descending -> unsorted`) backed by a
///   cached index permutation
/// - Single and multi-row selection (`Click`, `Ctrl`/`Cmd`+`Click`,
///   `Shift`+`Click` range, `Ctrl`/`Cmd`+`A`, optional checkbox column)
/// - Full keyboard navigation (`ArrowUp`/`Down`, `Shift`+`ArrowUp`/`Down`,
///   `PageUp`/`Down`, `Home`/`End`, `Space`, `Enter`, `Escape`)
/// - Adaptive layout constraints that never overflow or crash inside bounded
///   or unbounded parent widgets (`Expanded`, `Column`, `Dialog`, `SplitView`,
///   `SingleChildScrollView`, or non-`Material` shells).
class DenseTable extends StatefulWidget {
  /// Creates a [DenseTable] from column [headers] (or [columns]) and matrix [data].
  ///
  /// Fully backward-compatible with `dense_table` `0.1.0` while unlocking
  /// column resizing, sorting, selection, and keyboard navigation.
  const DenseTable({
    super.key,
    required List<String> this.headers,
    required List<List<dynamic>> this.data,
    this.columnWidths = const <int, double>{},
    this.columns,
    this.rowIdBuilder,
    this.dataIdentity,
    this.style = const DenseStyle(),
    this.controller,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.selectionMode = DenseSelectionMode.none,
    this.showCheckboxColumn = false,
    this.enableSorting = true,
    this.sortCycle = DenseSortCycle.tristate,
    this.sortIconBuilder,
    this.rowSpanBuilder,
    this.editTrigger = DenseEditTrigger.doubleTap,
    this.canEditCell,
    this.editValueGetter,
    this.onCellEditCommitted,
    this.trackDirtyCells = true,
    this.displayDirtyText = true,
    this.commitOnTapOutside = true,
    this.enableColumnResize = true,
    this.enableKeyboardNavigation = true,
    this.autofocus = false,
    this.focusNode,
    this.expandLastColumn = true,
    this.shrinkWrap = false,
    this.fallbackHeight = 400.0,
    this.maxShrinkWrapHeight = 1200.0,
    this.tailActions = false,
    this.actionsHeader = 'Actions',
    this.actionsWidth = 100.0,
    this.actions,
    this.emptyPlaceholder,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onRowSecondaryTapDown,
    this.onRowActivated,
    this.onSelectionChanged,
    this.onSelectedIdsChanged,
    this.onSortChanged,
    this.onColumnResized,
  })  : _rowCount = null,
        _cellBuilder = null,
        _rawCellValue = null,
        _indexedActions = null;

  /// Creates a lazy [DenseTable] that builds cells on demand for visible rows.
  ///
  /// Ideal for 100,000+ to 1,000,000+ typed domain models, cursors, or virtual
  /// streams without allocating intermediate `List<List<dynamic>>` rows.
  /// Provide [rawCellValue] to enable built-in client-side sorting, or handle
  /// [onSortChanged] externally.
  const DenseTable.builder({
    super.key,
    required List<DenseColumn> this.columns,
    required int rowCount,
    required DenseCellBuilder cellBuilder,
    DenseRawValueGetter? rawCellValue,
    this.rowIdBuilder,
    this.dataIdentity,
    this.style = const DenseStyle(),
    this.controller,
    this.verticalScrollController,
    this.horizontalScrollController,
    this.selectionMode = DenseSelectionMode.none,
    this.showCheckboxColumn = false,
    this.enableSorting = true,
    this.sortCycle = DenseSortCycle.tristate,
    this.sortIconBuilder,
    this.rowSpanBuilder,
    this.editTrigger = DenseEditTrigger.doubleTap,
    this.canEditCell,
    this.editValueGetter,
    this.onCellEditCommitted,
    this.trackDirtyCells = true,
    this.displayDirtyText = true,
    this.commitOnTapOutside = true,
    this.enableColumnResize = true,
    this.enableKeyboardNavigation = true,
    this.autofocus = false,
    this.focusNode,
    this.expandLastColumn = true,
    this.shrinkWrap = false,
    this.fallbackHeight = 400.0,
    this.maxShrinkWrapHeight = 1200.0,
    this.actionsHeader = 'Actions',
    this.actionsWidth = 100.0,
    DenseIndexedRowActionsBuilder? rowActionsBuilder,
    this.emptyPlaceholder,
    this.onRowTap,
    this.onRowDoubleTap,
    this.onRowSecondaryTapDown,
    this.onRowActivated,
    this.onSelectionChanged,
    this.onSelectedIdsChanged,
    this.onSortChanged,
    this.onColumnResized,
  })  : assert(rowCount >= 0, 'rowCount must be non-negative.'),
        headers = null,
        data = null,
        columnWidths = const <int, double>{},
        tailActions = rowActionsBuilder != null,
        actions = null,
        _rowCount = rowCount,
        _cellBuilder = cellBuilder,
        _rawCellValue = rawCellValue,
        _indexedActions = rowActionsBuilder;

  /// Column header labels when using the standard [DenseTable] constructor.
  final List<String>? headers;

  /// Matrix row data when using the standard [DenseTable] constructor.
  final List<List<dynamic>>? data;

  /// Initial column widths (`columnIndex -> logicalPixelWidth`).
  final Map<int, double> columnWidths;

  /// Optional rich column definitions overriding [headers] and [columnWidths].
  final List<DenseColumn>? columns;

  /// Optional callback returning a stable record ID (UID, primary key, or path)
  /// for each row (`0 .. rowCount - 1`).
  ///
  /// When provided, selection, keyboard focus, and the Shift-selection anchor
  /// remain bound to the underlying record across external search filtering,
  /// pagination, and live streaming insertions/deletions.
  final DenseRowIdGetter? rowIdBuilder;

  /// Optional identity token (such as a reference to the backing `List<T>` or
  /// a revision counter) enabling `O(1)` change detection on [DenseTable.builder]
  /// rebuilds without rescanning [rowIdBuilder].
  final Object? dataIdentity;

  /// Visual theme and dimension configuration.
  final DenseStyle style;

  /// Optional external controller for selection, sorting, and scrolling.
  final DenseTableController? controller;

  /// Optional external vertical [ScrollController] for the virtualized body.
  final ScrollController? verticalScrollController;

  /// Optional external horizontal [ScrollController] synced with the header.
  final ScrollController? horizontalScrollController;

  /// Selection mode (`none`, `single`, or `multi`).
  final DenseSelectionMode selectionMode;

  /// Whether to prepend a compact selection checkbox column on the left.
  final bool showCheckboxColumn;

  /// Whether clicking sortable column headers toggles column sorting.
  final bool enableSorting;

  /// Sort state cycle applied when clicking a sortable column header.
  final DenseSortCycle sortCycle;

  /// Optional builder for custom sort indicator widgets (`null` = unsorted).
  final DenseSortIconBuilder? sortIconBuilder;

  /// Optional resolver for vertically merged cells (`RowSpan`) across
  /// consecutive visual rows.
  final DenseRowSpanResolver? rowSpanBuilder;

  /// Gesture policy controlling how inline cell editing is triggered on
  /// columns marked `editable: true`.
  final DenseEditTrigger editTrigger;

  /// Optional per-cell predicate dynamically enabling or disabling inline
  /// editing (for example, locking system rows or null-PK records).
  final DenseCellEditablePredicate? canEditCell;

  /// Optional extractor returning the initial editable string for
  /// `(rowIndex, columnIndex)` when inline editing starts.
  final DenseCellEditValueGetter? editValueGetter;

  /// Called whenever a modified inline cell edit passes validation and commits.
  final DenseCellEditCommittedCallback? onCellEditCommitted;

  /// Whether committed edits are recorded in `DenseTableController.dirtyCells`
  /// and marked with a corner dirty indicator until cleared.
  final bool trackDirtyCells;

  /// Whether cells present in `DenseTableController.dirtyCells` automatically
  /// display their staged `newText` in place of the underlying cell widget.
  final bool displayDirtyText;

  /// Whether clicking outside the active inline cell editor automatically
  /// validates and commits the pending edit.
  final bool commitOnTapOutside;

  /// Whether dragging column header borders resizes columns interactively.
  final bool enableColumnResize;

  /// Whether arrow/page/home/end/enter/space shortcuts navigate rows.
  final bool enableKeyboardNavigation;

  /// Whether this table requests keyboard focus automatically on mount.
  final bool autofocus;

  /// Optional external [FocusNode] for keyboard navigation.
  final FocusNode? focusNode;

  /// Whether leftover viewport width expands flex/trailing columns so rows
  /// span the full width of the table without right-side dead space.
  final bool expandLastColumn;

  /// Whether the table shrinks vertically to fit its rows up to
  /// [maxShrinkWrapHeight].
  final bool shrinkWrap;

  /// Bounded height used automatically when [DenseTable] is placed inside an
  /// unbounded vertical parent (such as a `Column` without `Expanded` or a
  /// vertical `SingleChildScrollView`) with `shrinkWrap: false`.
  final double fallbackHeight;

  /// Safety cap in logical pixels when `shrinkWrap: true` inside an unbounded
  /// vertical parent so large datasets remain virtualized instead of freezing.
  final double maxShrinkWrapHeight;

  /// Whether a trailing actions column is shown when [actions] is provided.
  final bool tailActions;

  /// Header label for the trailing actions column.
  final String actionsHeader;

  /// Width in logical pixels for the trailing actions column.
  final double actionsWidth;

  /// Optional builder for trailing row actions in the matrix constructor.
  final DenseRowActionsBuilder? actions;

  /// Optional widget displayed in the table body when there are zero rows.
  final Widget? emptyPlaceholder;

  /// Called immediately (`0ms` delay) on primary single click of a row.
  final ValueChanged<int>? onRowTap;

  /// Called when the same row is double-clicked within `300ms`.
  final ValueChanged<int>? onRowDoubleTap;

  /// Called on secondary (right-click) pointer down on a row.
  final void Function(int rowIndex, TapDownDetails details)?
      onRowSecondaryTapDown;

  /// Called when a row is activated via `Enter` key or double-click.
  final ValueChanged<int>? onRowActivated;

  /// Called whenever the set of selected original row indices changes.
  final ValueChanged<Set<int>>? onSelectionChanged;

  /// Called whenever the set of selected stable row IDs changes (when
  /// [rowIdBuilder] is provided).
  final ValueChanged<Set<Object>>? onSelectedIdsChanged;

  /// Called whenever the active [DenseSortState] changes (`null` = unsorted).
  final ValueChanged<DenseSortState?>? onSortChanged;

  /// Called when a column is resized interactively (`columnIndex, newWidth`).
  final void Function(int columnIndex, double newWidth)? onColumnResized;

  final int? _rowCount;
  final DenseCellBuilder? _cellBuilder;
  final DenseRawValueGetter? _rawCellValue;
  final DenseIndexedRowActionsBuilder? _indexedActions;

  @override
  State<DenseTable> createState() => _DenseTableState();
}

class _DenseTableState extends State<DenseTable> {
  static const double _defaultColWidth = 120.0;
  static const Duration _doubleTapWindow = Duration(milliseconds: 300);

  DenseTableController? _internalController;
  ScrollController? _internalVerticalController;
  ScrollController? _internalBodyHorizontalController;
  final ScrollController _headerHorizontalController = ScrollController();
  FocusNode? _internalFocusNode;

  final ValueNotifier<int?> _hoveredVisualRow = ValueNotifier<int?>(null);
  final ValueNotifier<bool> _hasFocusNotifier = ValueNotifier<bool>(false);
  final ValueNotifier<int?> _resizingColNotifier = ValueNotifier<int?>(null);

  late List<DenseColumn> _resolvedColumns;
  late List<double> _baseColumnWidths;

  List<int>? _sortedToOriginal;
  List<int>? _originalToSorted;
  DenseSortState? _cachedSortState;

  List<Object>? _rowIds;
  Map<Object, int>? _idToIndex;

  Set<int> _lastReportedSelection = const <int>{};
  Set<Object> _lastReportedSelectedIds = const <Object>{};
  bool _postFrameSelectionReportScheduled = false;

  bool _isSyncingHorizontal = false;
  double _lastBodyViewportHeight = 240.0;
  double _lastViewportWidth = 0.0;
  _EffectiveColumnLayout? _lastComputedLayout;

  DateTime? _lastTapTimestamp;
  Object? _lastTapIdentity;
  int? _lastTapColumn;

  final TextEditingController _editTextController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode(
    debugLabel: 'DenseTableCellEditor',
  );
  final Object _editTapRegionGroup = Object();
  Object? _activeEditBaselineValue;
  String _activeEditBaselineText = '';
  String _activeEditInitialText = '';
  bool _isCommittingOrCancelingEdit = false;

  DenseTableController get _controller =>
      widget.controller ?? _internalController!;

  ScrollController get _verticalController =>
      widget.verticalScrollController ?? _internalVerticalController!;

  ScrollController get _bodyHorizontalController =>
      widget.horizontalScrollController ?? _internalBodyHorizontalController!;

  FocusNode get _focusNode => widget.focusNode ?? _internalFocusNode!;

  int get _totalRowCount => widget._rowCount ?? widget.data!.length;

  bool get _hasActionsColumn =>
      (widget.tailActions && widget.actions != null) ||
      widget.actions != null ||
      widget._indexedActions != null;

  bool get _showCheckboxes =>
      widget.showCheckboxColumn &&
      widget.selectionMode != DenseSelectionMode.none;

  @override
  void initState() {
    super.initState();
    if (widget.controller == null) {
      _internalController = DenseTableController();
    }
    if (widget.verticalScrollController == null) {
      _internalVerticalController = ScrollController();
    }
    if (widget.horizontalScrollController == null) {
      _internalBodyHorizontalController = ScrollController();
    }
    if (widget.focusNode == null) {
      _internalFocusNode = FocusNode(debugLabel: 'DenseTable');
    }

    _resolveColumnsAndInitialWidths(preserveResized: false);
    _syncRowIdentityIfNeeded(oldWidget: null, forceBind: true);
    _attachController(_controller);
    _attachHorizontalSync();
    _focusNode.addListener(_handleFocusChange);
    _editFocusNode.addListener(_handleFocusChange);
    _rebuildSortIndexIfNeeded(force: true);
  }

  @override
  void didUpdateWidget(covariant DenseTable oldWidget) {
    super.didUpdateWidget(oldWidget);

    final controllerSwapped = oldWidget.controller != widget.controller;
    if (controllerSwapped) {
      (oldWidget.controller ?? _internalController)?.removeListener(
        _handleControllerChanged,
      );
      (oldWidget.controller ?? _internalController)?.detachTableDelegates();
      if (widget.controller == null && _internalController == null) {
        _internalController = DenseTableController();
      } else if (widget.controller != null && _internalController != null) {
        _internalController!.dispose();
        _internalController = null;
      }
      _attachController(_controller);
    }

    if (oldWidget.verticalScrollController != widget.verticalScrollController) {
      if (widget.verticalScrollController == null &&
          _internalVerticalController == null) {
        _internalVerticalController = ScrollController();
      } else if (widget.verticalScrollController != null &&
          _internalVerticalController != null) {
        _internalVerticalController!.dispose();
        _internalVerticalController = null;
      }
    }

    if (oldWidget.horizontalScrollController !=
        widget.horizontalScrollController) {
      (oldWidget.horizontalScrollController ??
              _internalBodyHorizontalController)
          ?.removeListener(_syncFromBodyToHeader);
      if (widget.horizontalScrollController == null &&
          _internalBodyHorizontalController == null) {
        _internalBodyHorizontalController = ScrollController();
      } else if (widget.horizontalScrollController != null &&
          _internalBodyHorizontalController != null) {
        _internalBodyHorizontalController!.dispose();
        _internalBodyHorizontalController = null;
      }
      _bodyHorizontalController.addListener(_syncFromBodyToHeader);
    }

    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _internalFocusNode)?.removeListener(
        _handleFocusChange,
      );
      if (widget.focusNode == null && _internalFocusNode == null) {
        _internalFocusNode = FocusNode(debugLabel: 'DenseTable');
      } else if (widget.focusNode != null && _internalFocusNode != null) {
        _internalFocusNode!.dispose();
        _internalFocusNode = null;
      }
      _focusNode.addListener(_handleFocusChange);
    }

    final oldColCount = _resolvedColumns.length;
    final newColCount =
        widget.columns?.length ?? widget.headers?.length ?? oldColCount;
    final columnCountChanged = oldColCount != newColCount;
    final widthsMapChanged =
        oldWidget.columnWidths.length != widget.columnWidths.length;

    _resolveColumnsAndInitialWidths(
      preserveResized: !columnCountChanged && !widthsMapChanged,
    );
    var columnsReconciled = _controller.clampToColumnCount(
      _resolvedColumns.length,
      notify: false,
    );

    final rowIdsChanged = _syncRowIdentityIfNeeded(
      oldWidget: oldWidget,
      forceBind: controllerSwapped,
    );

    final activeEdit = _controller.editingCell;
    if (activeEdit != null &&
        !_isCellEditable(activeEdit.rowIndex, activeEdit.columnIndex)) {
      _controller.syncEditingSession(
        coord: null,
        rowId: null,
        errorText: null,
        notify: false,
      );
      columnsReconciled = true;
    }
    if (columnsReconciled) {
      _scheduleSelectionReportIfChanged(notifyControllerPostFrame: true);
    }

    final dataChanged = rowIdsChanged ||
        columnCountChanged ||
        !identical(oldWidget.data, widget.data) ||
        oldWidget._rowCount != widget._rowCount ||
        (widget.dataIdentity != null &&
            !identical(oldWidget.dataIdentity, widget.dataIdentity));
    if (dataChanged) {
      _rebuildSortIndexIfNeeded(force: true);
    }
  }

  bool _syncRowIdentityIfNeeded({
    required DenseTable? oldWidget,
    required bool forceBind,
  }) {
    final rowCount = _totalRowCount;
    final idGetter = widget.rowIdBuilder;

    if (idGetter == null) {
      final hadIds = _rowIds != null;
      _rowIds = null;
      _idToIndex = null;
      final controllerChanged = _controller.syncRowIdentity(
        rowIds: null,
        idToIndex: null,
        totalRowCount: rowCount,
        notify: false,
      );
      _scheduleSelectionReportIfChanged(
        notifyControllerPostFrame: oldWidget != null && controllerChanged,
      );
      return hadIds;
    }

    final canSkipScan = !forceBind &&
        oldWidget != null &&
        oldWidget.rowIdBuilder != null &&
        _rowIds != null &&
        _idToIndex != null &&
        _rowIds!.length == rowCount &&
        widget.dataIdentity != null &&
        identical(oldWidget.dataIdentity, widget.dataIdentity) &&
        identical(oldWidget.data, widget.data);

    var idsChanged = false;
    if (!canSkipScan) {
      final existing = _rowIds;
      if (existing == null || existing.length != rowCount) {
        idsChanged = true;
      } else {
        for (var i = 0; i < rowCount; i++) {
          if (existing[i] != idGetter(i)) {
            idsChanged = true;
            break;
          }
        }
      }

      if (idsChanged || _idToIndex == null) {
        final nextIds = List<Object>.generate(
          rowCount,
          idGetter,
          growable: false,
        );
        final nextMap = <Object, int>{};
        for (var i = 0; i < rowCount; i++) {
          nextMap.putIfAbsent(nextIds[i], () => i);
        }
        _rowIds = nextIds;
        _idToIndex = nextMap;
      }
    }

    var controllerChanged = false;
    if (idsChanged || forceBind) {
      controllerChanged = _controller.syncRowIdentity(
        rowIds: _rowIds,
        idToIndex: _idToIndex,
        totalRowCount: rowCount,
        notify: false,
      );
    }
    _scheduleSelectionReportIfChanged(
      notifyControllerPostFrame: oldWidget != null && controllerChanged,
    );
    return idsChanged;
  }

  void _scheduleSelectionReportIfChanged({
    bool notifyControllerPostFrame = false,
  }) {
    final rowsDiff =
        !_setsEqual(_lastReportedSelection, _controller.selectedRows);
    final idsDiff = widget.rowIdBuilder != null &&
        !_setsEqual(_lastReportedSelectedIds, _controller.selectedRowIds);
    if (!rowsDiff && !idsDiff && !notifyControllerPostFrame) {
      return;
    }
    if (_postFrameSelectionReportScheduled) {
      return;
    }
    _postFrameSelectionReportScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _postFrameSelectionReportScheduled = false;
      if (!mounted) {
        return;
      }
      if (notifyControllerPostFrame) {
        _controller.notifyIdentitySynced();
      }
      _reportSelectionCallbacksIfNeeded();
    });
  }

  void _reportSelectionCallbacksIfNeeded() {
    final currentRows = _controller.selectedRows;
    if (!_setsEqual(_lastReportedSelection, currentRows)) {
      _lastReportedSelection = Set<int>.of(currentRows);
      widget.onSelectionChanged?.call(currentRows);
    }
    if (widget.rowIdBuilder != null) {
      final currentIds = _controller.selectedRowIds;
      if (!_setsEqual(_lastReportedSelectedIds, currentIds)) {
        _lastReportedSelectedIds = Set<Object>.of(currentIds);
        widget.onSelectedIdsChanged?.call(currentIds);
      }
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChanged);
    _controller.detachTableDelegates();
    _bodyHorizontalController.removeListener(_syncFromBodyToHeader);
    _headerHorizontalController
      ..removeListener(_syncFromHeaderToBody)
      ..dispose();
    _focusNode.removeListener(_handleFocusChange);
    _editFocusNode
      ..removeListener(_handleFocusChange)
      ..dispose();
    _editTextController.dispose();

    _internalController?.dispose();
    _internalVerticalController?.dispose();
    _internalBodyHorizontalController?.dispose();
    _internalFocusNode?.dispose();

    _hoveredVisualRow.dispose();
    _hasFocusNotifier.dispose();
    _resizingColNotifier.dispose();
    super.dispose();
  }

  void _attachController(DenseTableController controller) {
    controller.attachTableDelegates(
      scrollToVisualRow: _scrollToVisualRow,
      originalToVisualIndex: _originalToVisualIndex,
      startEditing: _startEditingCell,
      commitEditing: ([overrideText]) => _commitEditingCell(
        overrideText: overrideText,
        restoreTableFocus: true,
      ),
      cancelEditing: () => _cancelEditingCell(restoreTableFocus: true),
    );
    for (var i = 0; i < _baseColumnWidths.length; i++) {
      final override = controller.columnWidth(i);
      if (override != null) {
        _baseColumnWidths[i] = _clampColumnWidth(i, override);
      }
    }
    _lastReportedSelection = Set<int>.of(controller.selectedRows);
    _lastReportedSelectedIds = Set<Object>.of(controller.selectedRowIds);
    controller.addListener(_handleControllerChanged);
  }

  void _attachHorizontalSync() {
    _bodyHorizontalController.addListener(_syncFromBodyToHeader);
    _headerHorizontalController.addListener(_syncFromHeaderToBody);
  }

  void _syncFromBodyToHeader() {
    if (_isSyncingHorizontal ||
        !_bodyHorizontalController.hasClients ||
        !_headerHorizontalController.hasClients) {
      return;
    }
    final target = _bodyHorizontalController.offset.clamp(
      0.0,
      _headerHorizontalController.position.maxScrollExtent,
    );
    if ((_headerHorizontalController.offset - target).abs() > 0.01) {
      _isSyncingHorizontal = true;
      _headerHorizontalController.jumpTo(target);
      _isSyncingHorizontal = false;
    }
  }

  void _syncFromHeaderToBody() {
    if (_isSyncingHorizontal ||
        !_headerHorizontalController.hasClients ||
        !_bodyHorizontalController.hasClients) {
      return;
    }
    final target = _headerHorizontalController.offset.clamp(
      0.0,
      _bodyHorizontalController.position.maxScrollExtent,
    );
    if ((_bodyHorizontalController.offset - target).abs() > 0.01) {
      _isSyncingHorizontal = true;
      _bodyHorizontalController.jumpTo(target);
      _isSyncingHorizontal = false;
    }
  }

  void _handleFocusChange() {
    _hasFocusNotifier.value = _focusNode.hasFocus || _editFocusNode.hasFocus;
  }

  void _handleControllerChanged() {
    var needsRebuild = false;

    for (var i = 0; i < _baseColumnWidths.length; i++) {
      final override = _controller.columnWidth(i);
      if (override != null) {
        final clamped = _clampColumnWidth(i, override);
        if (_baseColumnWidths[i] != clamped) {
          _baseColumnWidths[i] = clamped;
          needsRebuild = true;
        }
      }
    }

    if (_cachedSortState != _controller.sortState) {
      _rebuildSortIndexIfNeeded(force: true);
      widget.onSortChanged?.call(_controller.sortState);
      needsRebuild = true;
    }

    _reportSelectionCallbacksIfNeeded();

    if (needsRebuild && mounted) {
      setState(() {});
    }
  }

  bool _setsEqual<T>(Set<T> a, Set<T> b) =>
      a.length == b.length && a.containsAll(b);

  void _resolveColumnsAndInitialWidths({required bool preserveResized}) {
    final explicitColumns = widget.columns;
    if (explicitColumns != null) {
      _resolvedColumns = explicitColumns;
    } else {
      final headers = widget.headers ?? const <String>[];
      _resolvedColumns = List<DenseColumn>.generate(
        headers.length,
        (i) => DenseColumn(
          title: headers[i],
          initialWidth: widget.columnWidths[i] ?? _defaultColWidth,
        ),
        growable: false,
      );
    }

    final nextWidths = List<double>.generate(_resolvedColumns.length, (i) {
      if (preserveResized && i < _baseColumnWidths.length) {
        return _clampColumnWidth(i, _baseColumnWidths[i]);
      }
      final fromController = _controller.columnWidth(i);
      final raw = fromController ??
          widget.columnWidths[i] ??
          _resolvedColumns[i].initialWidth;
      return _clampColumnWidth(i, raw);
    }, growable: false);

    _baseColumnWidths = nextWidths;
  }

  double _clampColumnWidth(int colIndex, double width) {
    final col = _resolvedColumns[colIndex];
    final minW = col.minWidth ?? widget.style.minColumnWidth;
    final maxW = math.max(minW, col.maxWidth ?? widget.style.maxColumnWidth);
    return width.clamp(minW, maxW);
  }

  bool get _hasEditableColumns => _resolvedColumns.any((col) => col.editable);

  bool get _canSortClientSide =>
      widget.data != null || widget._rawCellValue != null;

  Object? _readRawSortValue(int originalRowIndex, int colIndex) {
    if (widget.trackDirtyCells) {
      final staged = _controller.dirtyTextAt(originalRowIndex, colIndex);
      if (staged != null) {
        return num.tryParse(staged) ?? staged;
      }
    }
    final getter = widget._rawCellValue;
    if (getter != null) {
      return getter(originalRowIndex, colIndex);
    }
    final matrix = widget.data;
    if (matrix != null && originalRowIndex < matrix.length) {
      final row = matrix[originalRowIndex];
      if (colIndex < row.length) {
        return row[colIndex];
      }
    }
    return null;
  }

  void _rebuildSortIndexIfNeeded({bool force = false}) {
    final sort = _controller.sortState;
    if (!force && _cachedSortState == sort) {
      return;
    }
    _cachedSortState = sort;

    final rowCount = _totalRowCount;
    if (sort == null ||
        rowCount <= 1 ||
        sort.columnIndex < 0 ||
        sort.columnIndex >= _resolvedColumns.length ||
        !_canSortClientSide) {
      _sortedToOriginal = null;
      _originalToSorted = null;
      return;
    }

    final colIndex = sort.columnIndex;
    final comparator =
        _resolvedColumns[colIndex].comparator ?? compareDenseValues;
    final descending = sort.direction == DenseSortDirection.descending;

    // Schwartzian transform: extract sort keys once in O(N) so O(N log N)
    // comparisons touch only contiguous array slots.
    final keys = List<Object?>.generate(
      rowCount,
      (i) => _readRawSortValue(i, colIndex),
      growable: false,
    );

    final indices = List<int>.generate(rowCount, (i) => i, growable: false)
      ..sort((a, b) {
        final ka = keys[a];
        final kb = keys[b];
        // Keep null values at the bottom regardless of sort direction.
        if (ka == null && kb == null) {
          return a.compareTo(b);
        }
        if (ka == null) {
          return 1;
        }
        if (kb == null) {
          return -1;
        }
        final cmp = comparator(ka, kb);
        if (cmp != 0) {
          return descending ? -cmp : cmp;
        }
        return a.compareTo(b);
      });

    final reverse = List<int>.filled(rowCount, 0);
    for (var visual = 0; visual < rowCount; visual++) {
      reverse[indices[visual]] = visual;
    }

    _sortedToOriginal = indices;
    _originalToSorted = reverse;
  }

  int _visualToOriginalIndex(int visualIndex) {
    final map = _sortedToOriginal;
    return map != null ? map[visualIndex] : visualIndex;
  }

  int? _originalToVisualIndex(int originalIndex) {
    if (originalIndex < 0 || originalIndex >= _totalRowCount) {
      return null;
    }
    final reverse = _originalToSorted;
    return reverse != null ? reverse[originalIndex] : originalIndex;
  }

  void _onResizeColumn(int columnIndex, double delta) {
    if (!widget.enableColumnResize ||
        !_resolvedColumns[columnIndex].resizable) {
      return;
    }
    final next = _clampColumnWidth(
      columnIndex,
      _baseColumnWidths[columnIndex] + delta,
    );
    if (next == _baseColumnWidths[columnIndex]) {
      return;
    }
    setState(() {
      _baseColumnWidths[columnIndex] = next;
    });
    _controller.setColumnWidth(columnIndex, next);
    widget.onColumnResized?.call(columnIndex, next);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _syncFromBodyToHeader();
      }
    });
  }

  void _onResetColumnWidth(int columnIndex) {
    if (!widget.enableColumnResize ||
        !_resolvedColumns[columnIndex].resizable) {
      return;
    }
    final initial = _clampColumnWidth(
      columnIndex,
      widget.columnWidths[columnIndex] ??
          _resolvedColumns[columnIndex].initialWidth,
    );
    if (initial == _baseColumnWidths[columnIndex]) {
      return;
    }
    setState(() {
      _baseColumnWidths[columnIndex] = initial;
    });
    _controller.setColumnWidth(columnIndex, initial);
    widget.onColumnResized?.call(columnIndex, initial);
  }

  void _onHeaderSortTap(int columnIndex) {
    if (_controller.isEditing) {
      if (!_commitEditingCell(restoreTableFocus: false)) {
        return;
      }
    }
    final col = _resolvedColumns[columnIndex];
    if (!widget.enableSorting || !col.sortable) {
      return;
    }
    _controller.toggleSortColumn(
      columnIndex,
      cycle: widget.sortCycle,
      initialDirection: col.initialSortDirection,
    );
  }

  int? _resolveColumnAtDx(double? localDx) {
    final layout = _lastComputedLayout;
    if (localDx == null || layout == null) {
      return null;
    }
    for (var i = 0; i < layout.columnWidths.length; i++) {
      final start = layout.columnOffsets[i];
      final end = start + layout.columnWidths[i];
      if (localDx >= start && localDx < end) {
        return i;
      }
    }
    return null;
  }

  int _resolveEditTargetOriginalRow(int visualIndex, int columnIndex) {
    final spanResolver = widget.rowSpanBuilder;
    if (spanResolver != null && _totalRowCount > 0) {
      final span = spanResolver(visualIndex, columnIndex);
      if (span != null && span.rowSpan > 1) {
        return _visualToOriginalIndex(
          span.startRow.clamp(0, _totalRowCount - 1),
        );
      }
    }
    return _visualToOriginalIndex(visualIndex);
  }

  bool _isCellEditable(int originalRowIndex, int columnIndex) {
    if (originalRowIndex < 0 ||
        originalRowIndex >= _totalRowCount ||
        columnIndex < 0 ||
        columnIndex >= _resolvedColumns.length) {
      return false;
    }
    if (!_resolvedColumns[columnIndex].editable) {
      return false;
    }
    return widget.canEditCell?.call(originalRowIndex, columnIndex) ?? true;
  }

  int? _firstEditableColumnForRow(int originalRowIndex) {
    for (var c = 0; c < _resolvedColumns.length; c++) {
      if (_isCellEditable(originalRowIndex, c)) {
        return c;
      }
    }
    return null;
  }

  Object? _readBaselineCellValue(int originalRowIndex, int columnIndex) {
    if (widget.trackDirtyCells) {
      final existingDirty = _controller.dirtyChangeAt(
        originalRowIndex,
        columnIndex,
      );
      if (existingDirty != null) {
        return existingDirty.previousValue;
      }
    }
    final rawGetter = widget._rawCellValue;
    if (rawGetter != null) {
      return rawGetter(originalRowIndex, columnIndex);
    }
    final matrix = widget.data;
    if (matrix != null && originalRowIndex < matrix.length) {
      final row = matrix[originalRowIndex];
      if (columnIndex < row.length) {
        final val = row[columnIndex];
        return val is Widget ? null : val;
      }
    }
    return widget.editValueGetter?.call(originalRowIndex, columnIndex);
  }

  String _readBaselineEditText(int originalRowIndex, int columnIndex) {
    if (widget.trackDirtyCells) {
      final existingDirty = _controller.dirtyChangeAt(
        originalRowIndex,
        columnIndex,
      );
      if (existingDirty != null) {
        return existingDirty.baselineText ??
            (existingDirty.previousValue?.toString() ?? '');
      }
    }
    final editGetter = widget.editValueGetter;
    if (editGetter != null) {
      return editGetter(originalRowIndex, columnIndex);
    }
    final raw = _readBaselineCellValue(originalRowIndex, columnIndex);
    return raw?.toString() ?? '';
  }

  String _readInitialEditText(int originalRowIndex, int columnIndex) {
    if (widget.trackDirtyCells) {
      final staged = _controller.dirtyTextAt(originalRowIndex, columnIndex);
      if (staged != null) {
        return staged;
      }
    }
    return _readBaselineEditText(originalRowIndex, columnIndex);
  }

  bool _startEditingCell(int originalRowIndex, int columnIndex) {
    if (!_isCellEditable(originalRowIndex, columnIndex)) {
      return false;
    }
    final targetCoord = DenseCellCoord(originalRowIndex, columnIndex);
    final currentEditing = _controller.editingCell;
    if (currentEditing != null) {
      if (currentEditing == targetCoord) {
        final vis = _originalToVisualIndex(originalRowIndex);
        if (vis != null) {
          _ensureVisualRowVisible(vis);
        }
        _ensureColumnVisible(columnIndex);
        if (!_editFocusNode.hasFocus) {
          _editFocusNode.requestFocus();
        }
        return true;
      }
      if (!_commitEditingCell(restoreTableFocus: false)) {
        return false;
      }
    }

    final visualIndex = _originalToVisualIndex(originalRowIndex);
    if (visualIndex == null) {
      return false;
    }

    _ensureVisualRowVisible(visualIndex);
    _ensureColumnVisible(columnIndex);

    final baseline = _readBaselineCellValue(originalRowIndex, columnIndex);
    final baselineText = _readBaselineEditText(originalRowIndex, columnIndex);
    final initialText = _readInitialEditText(originalRowIndex, columnIndex);
    _activeEditBaselineValue = baseline;
    _activeEditBaselineText = baselineText;
    _activeEditInitialText = initialText;
    _editTextController.value = TextEditingValue(
      text: initialText,
      selection: TextSelection(
        baseOffset: 0,
        extentOffset: initialText.length,
      ),
    );

    if (widget.selectionMode != DenseSelectionMode.none &&
        !_controller.isRowSelected(originalRowIndex)) {
      _controller.selectRow(originalRowIndex);
    }
    _controller.setFocusedCell(
      originalRowIndex,
      columnIndex,
      updateAnchor: true,
    );
    _controller.syncEditingSession(
      coord: targetCoord,
      rowId: _controller.rowIdAt(originalRowIndex),
      errorText: null,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _controller.isEditing && !_editFocusNode.hasFocus) {
        _editFocusNode.requestFocus();
      }
    });
    return true;
  }

  bool _commitEditingCell({
    String? overrideText,
    required bool restoreTableFocus,
  }) {
    final coord = _controller.editingCell;
    if (coord == null || _isCommittingOrCancelingEdit) {
      return true;
    }

    final draft = overrideText ?? _editTextController.text;
    final baseline = _activeEditBaselineValue;
    if (coord.columnIndex >= 0 && coord.columnIndex < _resolvedColumns.length) {
      final validator = _resolvedColumns[coord.columnIndex].validator;
      final error = validator?.call(
        coord.rowIndex,
        coord.columnIndex,
        baseline,
        draft,
      );
      if (error != null) {
        _controller.syncEditingSession(
          coord: coord,
          rowId: _controller.editingRowId,
          errorText: error,
        );
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _controller.isEditing && !_editFocusNode.hasFocus) {
            _editFocusNode.requestFocus();
          }
        });
        return false;
      }
    }

    _isCommittingOrCancelingEdit = true;
    try {
      final didModifyText = draft != _activeEditInitialText;
      final change = DenseCellChange(
        coord: coord,
        rowId: _controller.rowIdAt(coord.rowIndex) ?? _controller.editingRowId,
        previousValue: baseline,
        baselineText: _activeEditBaselineText,
        newText: draft,
      );

      _controller.syncEditingSession(
        coord: null,
        rowId: null,
        errorText: null,
        notify: false,
      );

      if (didModifyText && widget.trackDirtyCells) {
        _controller.recordCellChange(change, notify: false);
      }
      _controller.notifyIdentitySynced();

      if (didModifyText) {
        widget.onCellEditCommitted?.call(change);
      }

      if (restoreTableFocus && widget.enableKeyboardNavigation) {
        _focusNode.requestFocus();
      }
      return true;
    } finally {
      _isCommittingOrCancelingEdit = false;
    }
  }

  void _cancelEditingCell({required bool restoreTableFocus}) {
    if (!_controller.isEditing || _isCommittingOrCancelingEdit) {
      return;
    }
    _isCommittingOrCancelingEdit = true;
    try {
      _controller.syncEditingSession(
        coord: null,
        rowId: null,
        errorText: null,
      );
      if (restoreTableFocus && widget.enableKeyboardNavigation) {
        _focusNode.requestFocus();
      }
    } finally {
      _isCommittingOrCancelingEdit = false;
    }
  }

  void _handleEditorTapOutside(PointerDownEvent event) {
    if (!widget.commitOnTapOutside || !_controller.isEditing) {
      return;
    }
    _commitEditingCell(restoreTableFocus: false);
  }

  void _commitAndMoveDown() {
    final coord = _controller.editingCell;
    if (coord == null) {
      return;
    }
    final currentVisual = _originalToVisualIndex(coord.rowIndex);
    if (!_commitEditingCell(restoreTableFocus: true)) {
      return;
    }
    if (currentVisual == null || _totalRowCount <= 0) {
      return;
    }
    final nextVisual = math.min(_totalRowCount - 1, currentVisual + 1);
    final nextOriginal = _visualToOriginalIndex(nextVisual);
    if (widget.selectionMode != DenseSelectionMode.none) {
      _controller.selectRow(nextOriginal);
    }
    _controller.setFocusedCell(
      nextOriginal,
      coord.columnIndex,
      updateAnchor: true,
    );
    _ensureVisualRowVisible(nextVisual);
  }

  DenseCellCoord? _findAdjacentEditableCell({
    required int fromVisualRow,
    required int fromColumn,
    required bool forward,
  }) {
    final rowCount = _totalRowCount;
    final colCount = _resolvedColumns.length;
    if (rowCount <= 0 || colCount <= 0) {
      return null;
    }

    if (forward) {
      for (var v = fromVisualRow; v < rowCount; v++) {
        final orig = _visualToOriginalIndex(v);
        final startCol = v == fromVisualRow ? fromColumn + 1 : 0;
        for (var c = startCol; c < colCount; c++) {
          if (_isCellEditable(orig, c)) {
            return DenseCellCoord(orig, c);
          }
        }
      }
    } else {
      for (var v = fromVisualRow; v >= 0; v--) {
        final orig = _visualToOriginalIndex(v);
        final startCol = v == fromVisualRow ? fromColumn - 1 : colCount - 1;
        for (var c = startCol; c >= 0; c--) {
          if (_isCellEditable(orig, c)) {
            return DenseCellCoord(orig, c);
          }
        }
      }
    }
    return null;
  }

  void _commitAndMoveAdjacentEditable({required bool forward}) {
    final coord = _controller.editingCell;
    if (coord == null) {
      return;
    }
    final currentVisual = _originalToVisualIndex(coord.rowIndex) ?? 0;
    final nextTarget = _findAdjacentEditableCell(
      fromVisualRow: currentVisual,
      fromColumn: coord.columnIndex,
      forward: forward,
    );

    if (!_commitEditingCell(restoreTableFocus: nextTarget == null)) {
      return;
    }
    if (nextTarget != null) {
      _startEditingCell(nextTarget.rowIndex, nextTarget.columnIndex);
    }
  }

  KeyEventResult _handleEditorKeyEvent(FocusNode node, KeyEvent event) {
    if (!_controller.isEditing) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      if (event is KeyDownEvent) {
        _cancelEditingCell(restoreTableFocus: true);
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (event is KeyDownEvent) {
        _commitAndMoveDown();
      }
      return KeyEventResult.handled;
    }
    if (key == LogicalKeyboardKey.tab) {
      _commitAndMoveAdjacentEditable(
        forward: !HardwareKeyboard.instance.isShiftPressed,
      );
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _handleRowPointerTap(
    int visualIndex, {
    required bool fromCheckbox,
    double? localDx,
  }) {
    final originalIndex = _visualToOriginalIndex(visualIndex);
    final clickedCol = fromCheckbox ? null : _resolveColumnAtDx(localDx);

    if (_controller.isEditing) {
      final active = _controller.editingCell!;
      final targetOrig = clickedCol != null
          ? _resolveEditTargetOriginalRow(visualIndex, clickedCol)
          : originalIndex;
      if (active.rowIndex != targetOrig || active.columnIndex != clickedCol) {
        if (!_commitEditingCell(restoreTableFocus: false)) {
          return;
        }
      }
    }

    if (widget.enableKeyboardNavigation &&
        !_controller.isEditing &&
        !_focusNode.hasFocus) {
      _focusNode.requestFocus();
    }

    final tapIdentity = _rowIds != null && originalIndex < _rowIds!.length
        ? _rowIds![originalIndex]
        : originalIndex;
    final now = DateTime.now();
    final isDoubleTap = !fromCheckbox &&
        _lastTapIdentity == tapIdentity &&
        _lastTapTimestamp != null &&
        now.difference(_lastTapTimestamp!) <= _doubleTapWindow;
    final isSameColumnDoubleTap = isDoubleTap && _lastTapColumn == clickedCol;

    _lastTapIdentity = tapIdentity;
    _lastTapColumn = clickedCol;
    _lastTapTimestamp = isDoubleTap ? null : now;

    _applyPointerSelection(
      visualIndex: visualIndex,
      originalIndex: originalIndex,
      fromCheckbox: fromCheckbox,
    );

    if (_hasEditableColumns && clickedCol != null) {
      _controller.setFocusedColumn(clickedCol);
    }

    if (!fromCheckbox) {
      widget.onRowTap?.call(originalIndex);

      if (_hasEditableColumns && clickedCol != null) {
        final editRow = _resolveEditTargetOriginalRow(visualIndex, clickedCol);
        final keyboard = HardwareKeyboard.instance;
        final hasModifier = keyboard.isShiftPressed ||
            keyboard.isMetaPressed ||
            keyboard.isControlPressed;

        if (!hasModifier && _isCellEditable(editRow, clickedCol)) {
          if (widget.editTrigger == DenseEditTrigger.singleTap) {
            _startEditingCell(editRow, clickedCol);
            return;
          }
          if (widget.editTrigger == DenseEditTrigger.doubleTap &&
              isSameColumnDoubleTap) {
            _startEditingCell(editRow, clickedCol);
            return;
          }
        }
      }

      if (isDoubleTap) {
        widget.onRowDoubleTap?.call(originalIndex);
        widget.onRowActivated?.call(originalIndex);
      }
    }
  }

  void _applyPointerSelection({
    required int visualIndex,
    required int originalIndex,
    required bool fromCheckbox,
  }) {
    final mode = widget.selectionMode;
    if (mode == DenseSelectionMode.none) {
      if (widget.enableKeyboardNavigation) {
        _controller.setFocusedRow(originalIndex, updateAnchor: true);
      }
      return;
    }

    final keyboard = HardwareKeyboard.instance;
    final isShift = keyboard.isShiftPressed;
    final isToggleModifier =
        keyboard.isMetaPressed || keyboard.isControlPressed;

    if (mode == DenseSelectionMode.single) {
      if ((fromCheckbox || isToggleModifier) &&
          _controller.isRowSelected(originalIndex)) {
        _controller.clearSelection();
        _controller.setFocusedRow(originalIndex, updateAnchor: true);
      } else {
        _controller.selectRow(originalIndex);
      }
      return;
    }

    // DenseSelectionMode.multi
    if (isShift && _controller.anchorRow != null) {
      final anchorVisual =
          _originalToVisualIndex(_controller.anchorRow!) ?? visualIndex;
      _selectVisualRange(
        fromVisual: anchorVisual,
        toVisual: visualIndex,
        additive: isToggleModifier || fromCheckbox,
      );
      _controller.setFocusedRow(originalIndex);
      return;
    }

    if (fromCheckbox || isToggleModifier) {
      _controller.toggleRow(originalIndex);
    } else {
      _controller.selectRow(originalIndex);
    }
  }

  void _selectVisualRange({
    required int fromVisual,
    required int toVisual,
    required bool additive,
  }) {
    final start = math.max(0, math.min(fromVisual, toVisual));
    final end = math.min(_totalRowCount - 1, math.max(fromVisual, toVisual));
    final next = additive ? Set<int>.of(_controller.selectedRows) : <int>{};
    for (var v = start; v <= end; v++) {
      next.add(_visualToOriginalIndex(v));
    }
    _controller.setSelectedRows(
      next,
      focusedRow: _visualToOriginalIndex(toVisual),
      preserveHiddenSelectedIds: additive,
    );
  }

  void _toggleSelectAllHeader() {
    if (widget.selectionMode != DenseSelectionMode.multi) {
      return;
    }
    if (_totalRowCount == 0) {
      return;
    }
    _controller.toggleSelectAllVisible(_totalRowCount);
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (_controller.isEditing) {
      return KeyEventResult.ignored;
    }
    if (!widget.enableKeyboardNavigation) {
      return KeyEventResult.ignored;
    }
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }

    final rowCount = _totalRowCount;
    if (rowCount <= 0) {
      return KeyEventResult.ignored;
    }

    final key = event.logicalKey;
    final keyboard = HardwareKeyboard.instance;
    final isShift = keyboard.isShiftPressed;
    final isAccel = keyboard.isMetaPressed || keyboard.isControlPressed;

    if (isAccel &&
        key == LogicalKeyboardKey.keyA &&
        widget.selectionMode == DenseSelectionMode.multi) {
      _controller.selectAll(rowCount);
      return KeyEventResult.handled;
    }

    if (key == LogicalKeyboardKey.escape) {
      if (_controller.hasSelection) {
        _controller.clearSelection();
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final currentOriginal = _controller.focusedRow ??
        (_controller.selectedRows.isNotEmpty
            ? _controller.selectedRows.first
            : null);
    final currentVisual = currentOriginal != null
        ? (_originalToVisualIndex(currentOriginal) ?? 0)
        : -1;

    if (_hasEditableColumns && _resolvedColumns.isNotEmpty) {
      if (key == LogicalKeyboardKey.f2 && event is KeyDownEvent) {
        final targetOrig = currentOriginal ?? _visualToOriginalIndex(0);
        final targetCol =
            _controller.focusedColumn ?? _firstEditableColumnForRow(targetOrig);
        if (targetCol != null && _isCellEditable(targetOrig, targetCol)) {
          _startEditingCell(targetOrig, targetCol);
          return KeyEventResult.handled;
        }
      }

      if ((key == LogicalKeyboardKey.arrowLeft ||
              key == LogicalKeyboardKey.arrowRight) &&
          !isAccel) {
        final colCount = _resolvedColumns.length;
        final baseOrig = currentOriginal ?? _visualToOriginalIndex(0);
        final baseCol = _controller.focusedColumn ??
            (_firstEditableColumnForRow(baseOrig) ?? 0);
        final nextCol = key == LogicalKeyboardKey.arrowRight
            ? math.min(colCount - 1, baseCol + 1)
            : math.max(0, baseCol - 1);
        _controller.setFocusedCell(baseOrig, nextCol, updateAnchor: true);
        _ensureColumnVisible(nextCol);
        return KeyEventResult.handled;
      }

      if (key == LogicalKeyboardKey.tab && !isAccel) {
        final baseVis = currentVisual < 0 ? 0 : currentVisual;
        final baseOrig = _visualToOriginalIndex(baseVis);
        final baseCol = _controller.focusedColumn ??
            (_firstEditableColumnForRow(baseOrig) ?? (isShift ? 1 : -1));
        final nextCoord = _findAdjacentEditableCell(
          fromVisualRow: baseVis,
          fromColumn: baseCol,
          forward: !isShift,
        );
        if (nextCoord != null) {
          final nextVis = _originalToVisualIndex(nextCoord.rowIndex) ?? baseVis;
          if (widget.selectionMode != DenseSelectionMode.none) {
            _controller.selectRow(nextCoord.rowIndex);
          }
          _controller.setFocusedCell(
            nextCoord.rowIndex,
            nextCoord.columnIndex,
            updateAnchor: true,
          );
          _ensureVisualRowVisible(nextVis);
          _ensureColumnVisible(nextCoord.columnIndex);
          return KeyEventResult.handled;
        }
      }
    }

    if (key == LogicalKeyboardKey.enter ||
        key == LogicalKeyboardKey.numpadEnter) {
      if (currentOriginal != null) {
        if (_hasEditableColumns && event is KeyDownEvent) {
          final targetCol = _controller.focusedColumn ??
              _firstEditableColumnForRow(currentOriginal);
          if (targetCol != null &&
              _isCellEditable(currentOriginal, targetCol)) {
            _startEditingCell(currentOriginal, targetCol);
            return KeyEventResult.handled;
          }
        }
        widget.onRowActivated?.call(currentOriginal);
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    if (key == LogicalKeyboardKey.space) {
      if (currentOriginal != null &&
          widget.selectionMode != DenseSelectionMode.none) {
        if (widget.selectionMode == DenseSelectionMode.single) {
          if (_controller.isRowSelected(currentOriginal)) {
            _controller.clearSelection();
          } else {
            _controller.selectRow(currentOriginal);
          }
        } else {
          _controller.toggleRow(currentOriginal);
        }
        return KeyEventResult.handled;
      }
      return KeyEventResult.ignored;
    }

    final pageRows = math.max(
      1,
      (_lastBodyViewportHeight / widget.style.rowHeight).floor() - 1,
    );

    int? targetVisual;
    if (key == LogicalKeyboardKey.arrowDown) {
      targetVisual =
          currentVisual < 0 ? 0 : math.min(rowCount - 1, currentVisual + 1);
    } else if (key == LogicalKeyboardKey.arrowUp) {
      targetVisual = currentVisual <= 0 ? 0 : currentVisual - 1;
    } else if (key == LogicalKeyboardKey.pageDown) {
      targetVisual = currentVisual < 0
          ? math.min(rowCount - 1, pageRows)
          : math.min(rowCount - 1, currentVisual + pageRows);
    } else if (key == LogicalKeyboardKey.pageUp) {
      targetVisual =
          currentVisual <= 0 ? 0 : math.max(0, currentVisual - pageRows);
    } else if (key == LogicalKeyboardKey.home) {
      targetVisual = 0;
    } else if (key == LogicalKeyboardKey.end) {
      targetVisual = rowCount - 1;
    }

    if (targetVisual == null) {
      return KeyEventResult.ignored;
    }

    final targetOriginal = _visualToOriginalIndex(targetVisual);
    if (widget.selectionMode == DenseSelectionMode.multi && isShift) {
      final anchorOrig =
          _controller.anchorRow ?? currentOriginal ?? targetOriginal;
      if (_controller.anchorRow == null) {
        _controller.setFocusedRow(anchorOrig, updateAnchor: true);
      }
      final anchorVis = _originalToVisualIndex(anchorOrig) ?? targetVisual;
      _selectVisualRange(
        fromVisual: anchorVis,
        toVisual: targetVisual,
        additive: false,
      );
    } else if (widget.selectionMode != DenseSelectionMode.none && !isAccel) {
      _controller.selectRow(targetOriginal);
    } else {
      _controller.setFocusedRow(targetOriginal, updateAnchor: true);
    }

    _ensureVisualRowVisible(targetVisual);
    return KeyEventResult.handled;
  }

  void _scrollToVisualRow(
    int visualIndex, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    if (!_verticalController.hasClients || _totalRowCount <= 0) {
      return;
    }
    final clampedIndex = visualIndex.clamp(0, _totalRowCount - 1);
    final rawOffset = clampedIndex * widget.style.rowHeight;
    final maxExtent = _verticalController.position.maxScrollExtent;
    final targetOffset = rawOffset.clamp(0.0, maxExtent);
    if (duration != null && duration > Duration.zero) {
      _verticalController.animateTo(
        targetOffset,
        duration: duration,
        curve: curve,
      );
    } else {
      _verticalController.jumpTo(targetOffset);
    }
  }

  void _ensureVisualRowVisible(int visualIndex) {
    if (!_verticalController.hasClients || _totalRowCount <= 0) {
      return;
    }
    final pos = _verticalController.position;
    final rowH = widget.style.rowHeight;
    final rowTop = visualIndex * rowH;
    final rowBottom = rowTop + rowH;
    final viewTop = pos.pixels;
    final viewBottom = viewTop + pos.viewportDimension;

    if (rowTop < viewTop) {
      _verticalController.jumpTo(rowTop.clamp(0.0, pos.maxScrollExtent));
    } else if (rowBottom > viewBottom) {
      _verticalController.jumpTo(
        (rowBottom - pos.viewportDimension).clamp(0.0, pos.maxScrollExtent),
      );
    }
  }

  void _ensureColumnVisible(int columnIndex) {
    final layout = _lastComputedLayout;
    if (!_bodyHorizontalController.hasClients ||
        layout == null ||
        columnIndex < 0 ||
        columnIndex >= layout.columnWidths.length ||
        _lastViewportWidth <= 0) {
      return;
    }
    final pos = _bodyHorizontalController.position;
    final colLeft = layout.columnOffsets[columnIndex];
    final colRight = colLeft + layout.columnWidths[columnIndex];
    final viewLeft = pos.pixels;
    final viewRight = viewLeft + _lastViewportWidth;

    if (colLeft < viewLeft) {
      _bodyHorizontalController.jumpTo(colLeft.clamp(0.0, pos.maxScrollExtent));
    } else if (colRight > viewRight) {
      _bodyHorizontalController.jumpTo(
        (colRight - _lastViewportWidth).clamp(0.0, pos.maxScrollExtent),
      );
    }
  }

  _EffectiveColumnLayout _computeColumnLayout(double availableViewportWidth) {
    final checkboxW = _showCheckboxes ? widget.style.checkboxColumnWidth : 0.0;
    final actionsW = _hasActionsColumn ? widget.actionsWidth : 0.0;
    final colCount = _baseColumnWidths.length;

    var baseDataW = 0.0;
    for (var i = 0; i < colCount; i++) {
      baseDataW += _baseColumnWidths[i];
    }

    final baseTotalW = checkboxW + baseDataW + actionsW;
    final effectiveWidths = List<double>.of(_baseColumnWidths, growable: false);

    if (widget.expandLastColumn &&
        colCount > 0 &&
        availableViewportWidth > baseTotalW) {
      final leftover = availableViewportWidth - baseTotalW;
      var totalFlex = 0.0;
      for (var i = 0; i < colCount; i++) {
        final f = _resolvedColumns[i].flex;
        if (f != null && f > 0) {
          totalFlex += f;
        }
      }
      if (totalFlex > 0) {
        for (var i = 0; i < colCount; i++) {
          final f = _resolvedColumns[i].flex;
          if (f != null && f > 0) {
            effectiveWidths[i] += leftover * (f / totalFlex);
          }
        }
      } else {
        effectiveWidths[colCount - 1] += leftover;
      }
    }

    var effectiveDataW = 0.0;
    for (var i = 0; i < colCount; i++) {
      effectiveDataW += effectiveWidths[i];
    }
    final totalTableW = math.max(
      availableViewportWidth,
      checkboxW + effectiveDataW + actionsW,
    );

    // Precompute column X offsets and vertical divider X coordinates once per
    // layout pass.
    final columnOffsets = List<double>.filled(colCount, 0.0);
    final dividerCount =
        (_showCheckboxes ? 1 : 0) + colCount + (_hasActionsColumn ? 1 : 0);
    final dividerOffsets = List<double>.filled(dividerCount, 0.0);
    var cursor = 0.0;
    var dIdx = 0;
    if (_showCheckboxes) {
      cursor += checkboxW;
      dividerOffsets[dIdx++] = cursor;
    }
    for (var i = 0; i < colCount; i++) {
      columnOffsets[i] = cursor;
      cursor += effectiveWidths[i];
      dividerOffsets[dIdx++] = cursor;
    }
    if (_hasActionsColumn) {
      cursor += actionsW;
      dividerOffsets[dIdx++] = cursor;
    }

    return _EffectiveColumnLayout(
      checkboxWidth: checkboxW,
      actionsWidth: actionsW,
      columnOffsets: columnOffsets,
      columnWidths: effectiveWidths,
      dividerOffsets: dividerOffsets,
      totalWidth: totalTableW,
    );
  }

  @override
  Widget build(BuildContext context) {
    _rebuildSortIndexIfNeeded();

    return LayoutBuilder(
      builder: (context, constraints) {
        const borderThickness = 2.0; // 1px top/bottom and 1px left/right
        final style = widget.style;
        final rowCount = _totalRowCount;

        final rawIntrinsicWidth =
            (_showCheckboxes ? style.checkboxColumnWidth : 0.0) +
                _baseColumnWidths.fold<double>(0.0, (s, w) => s + w) +
                (_hasActionsColumn ? widget.actionsWidth : 0.0);

        final hasBoundedW =
            constraints.hasBoundedWidth && constraints.maxWidth.isFinite;
        final outerWidth = hasBoundedW
            ? constraints.maxWidth
            : rawIntrinsicWidth + borderThickness;
        final viewportWidth = math.max(0.0, outerWidth - borderThickness);

        final layout = _computeColumnLayout(viewportWidth);
        _lastViewportWidth = viewportWidth;
        _lastComputedLayout = layout;

        final contentBodyHeight = rowCount == 0
            ? math.max(style.rowHeight * 3.0, 72.0)
            : rowCount * style.rowHeight;

        final hasBoundedH =
            constraints.hasBoundedHeight && constraints.maxHeight.isFinite;

        double outerHeight;
        if (hasBoundedH) {
          if (widget.shrinkWrap) {
            outerHeight = math.min(
              constraints.maxHeight,
              style.headerHeight + contentBodyHeight + borderThickness,
            );
          } else {
            outerHeight = constraints.maxHeight;
          }
        } else {
          final targetBodyH = widget.shrinkWrap
              ? math.min(contentBodyHeight, widget.maxShrinkWrapHeight)
              : math.min(contentBodyHeight, widget.fallbackHeight);
          outerHeight = style.headerHeight + targetBodyH + borderThickness;
        }

        final innerHeight = math.max(0.0, outerHeight - borderThickness);
        final effectiveHeaderHeight = math.min(style.headerHeight, innerHeight);
        final bodyHeight = math.max(0.0, innerHeight - effectiveHeaderHeight);
        _lastBodyViewportHeight = bodyHeight > 0 ? bodyHeight : style.rowHeight;

        Widget tableContent = SizedBox(
          width: outerWidth,
          height: outerHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: style.backgroundColor,
              border: Border.all(color: style.borderColor),
              borderRadius: style.borderRadius,
            ),
            child: Padding(
              padding: const EdgeInsets.all(1.0),
              child: ClipRect(
                child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    if (effectiveHeaderHeight > 0)
                      SizedBox(
                        width: viewportWidth,
                        height: effectiveHeaderHeight,
                        child: _buildStickyHeader(
                          layout: layout,
                          headerHeight: effectiveHeaderHeight,
                        ),
                      ),
                    if (bodyHeight > 0)
                      SizedBox(
                        width: viewportWidth,
                        height: bodyHeight,
                        child: _buildVirtualizedBody(
                          layout: layout,
                          viewportWidth: viewportWidth,
                          bodyHeight: bodyHeight,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );

        if (style.borderRadius != BorderRadius.zero) {
          tableContent = ClipRRect(
            borderRadius: style.borderRadius,
            child: tableContent,
          );
        }

        Widget result = Focus(
          focusNode: _focusNode,
          autofocus: widget.autofocus,
          onKeyEvent: _handleKeyEvent,
          child: DefaultTextStyle.merge(
            style: style.cellTextStyle,
            child: tableContent,
          ),
        );

        if (MediaQuery.maybeOf(context) == null) {
          result = MediaQuery(
            data: const MediaQueryData(),
            child: result,
          );
        }
        if (Directionality.maybeOf(context) == null) {
          result = Directionality(
            textDirection: TextDirection.ltr,
            child: result,
          );
        }
        return result;
      },
    );
  }

  Widget _buildStickyHeader({
    required _EffectiveColumnLayout layout,
    required double headerHeight,
  }) {
    final style = widget.style;
    final sortState = _controller.sortState;

    return Listener(
      onPointerSignal: (event) {
        if (event is PointerScrollEvent &&
            event.scrollDelta.dx != 0 &&
            _bodyHorizontalController.hasClients) {
          final maxExt = _bodyHorizontalController.position.maxScrollExtent;
          final next = (_bodyHorizontalController.offset + event.scrollDelta.dx)
              .clamp(0.0, maxExt);
          _bodyHorizontalController.jumpTo(next);
        }
      },
      child: SingleChildScrollView(
        controller: _headerHorizontalController,
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        child: SizedBox(
          width: layout.totalWidth,
          height: headerHeight,
          child: CustomPaint(
            painter: _DenseHeaderGridPainter(
              backgroundColor: style.headerBackgroundColor,
              borderColor: style.borderColor,
              dividerOffsets: layout.dividerOffsets,
            ),
            child: Row(
              children: <Widget>[
                if (_showCheckboxes)
                  SizedBox(
                    width: layout.checkboxWidth,
                    height: headerHeight,
                    child: _buildHeaderSelectAllCell(),
                  ),
                for (var i = 0; i < _resolvedColumns.length; i++)
                  _buildHeaderCell(
                    columnIndex: i,
                    width: layout.columnWidths[i],
                    height: headerHeight,
                    sortDirection:
                        sortState != null && sortState.columnIndex == i
                            ? sortState.direction
                            : null,
                  ),
                if (_hasActionsColumn)
                  Container(
                    width: layout.actionsWidth,
                    height: headerHeight,
                    padding: style.cellPadding,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      widget.actionsHeader,
                      style: style.headerTextStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderSelectAllCell() {
    if (widget.selectionMode != DenseSelectionMode.multi) {
      return const SizedBox.shrink();
    }
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final total = _totalRowCount;
        final selected = _controller.selectedCount;
        final state = (total == 0 || selected == 0)
            ? false
            : (selected >= total ? true : null);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleSelectAllHeader,
          child: Center(
            child: _DenseCheckbox(
              value: state,
              style: widget.style,
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeaderCell({
    required int columnIndex,
    required double width,
    required double height,
    required DenseSortDirection? sortDirection,
  }) {
    final style = widget.style;
    final col = _resolvedColumns[columnIndex];
    final canSort = widget.enableSorting && col.sortable;
    final canResize = widget.enableColumnResize && col.resizable;

    Widget labelContent;
    if (col.headerBuilder != null) {
      labelContent = col.headerBuilder!(
        context,
        col,
        columnIndex,
        sortDirection,
      );
    } else {
      final effectiveHeaderStyle =
          (sortDirection != null ? style.activeHeaderTextStyle : null) ??
              style.headerTextStyle;

      labelContent = col.headerChild ??
          Text(
            col.title,
            style: effectiveHeaderStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          );

      final showIndicator =
          canSort && (sortDirection != null || style.showUnsortedSortIcon);
      if (showIndicator) {
        final Widget indicatorWidget;
        if (widget.sortIconBuilder != null) {
          indicatorWidget = widget.sortIconBuilder!(context, sortDirection);
        } else if (sortDirection != null) {
          indicatorWidget = CustomPaint(
            size: const Size(8.0, 8.0),
            painter: _DenseSortArrowPainter(
              direction: sortDirection,
              color: style.activeSortIconColor,
            ),
          );
        } else {
          indicatorWidget = CustomPaint(
            size: const Size(8.0, 10.0),
            painter: _DenseUnsortedIconPainter(
              color: style.sortIconColor,
            ),
          );
        }

        labelContent = Row(
          mainAxisSize:
              style.sortIconInline ? MainAxisSize.min : MainAxisSize.max,
          children: <Widget>[
            Flexible(child: labelContent),
            SizedBox(width: style.sortIconInline ? 3.0 : 4.0),
            indicatorWidget,
          ],
        );
      }
    }

    Widget interactiveLabel = Container(
      key: canSort ? null : col.headerKey,
      padding: style.cellPadding,
      alignment: col.alignment,
      child: labelContent,
    );

    if (canSort) {
      interactiveLabel = MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          key: col.headerKey,
          behavior: HitTestBehavior.opaque,
          onTap: () => _onHeaderSortTap(columnIndex),
          child: interactiveLabel,
        ),
      );
    }

    return SizedBox(
      width: width,
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          interactiveLabel,
          if (canResize)
            Positioned(
              right: 0,
              top: 0,
              bottom: 0,
              width: 8.0,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeColumn,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  dragStartBehavior: DragStartBehavior.down,
                  onDoubleTap: () => _onResetColumnWidth(columnIndex),
                  onHorizontalDragStart: (_) {
                    _resizingColNotifier.value = columnIndex;
                  },
                  onHorizontalDragUpdate: (details) {
                    _onResizeColumn(columnIndex, details.delta.dx);
                  },
                  onHorizontalDragEnd: (_) {
                    _resizingColNotifier.value = null;
                  },
                  onHorizontalDragCancel: () {
                    _resizingColNotifier.value = null;
                  },
                  child: ValueListenableBuilder<int?>(
                    valueListenable: _resizingColNotifier,
                    builder: (context, activeCol, _) {
                      if (activeCol != columnIndex) {
                        return const SizedBox.expand();
                      }
                      return Align(
                        alignment: Alignment.centerRight,
                        child: ColoredBox(
                          color: style.resizeHandleActiveColor,
                          child: const SizedBox(
                            width: 2.0,
                            height: double.infinity,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVirtualizedBody({
    required _EffectiveColumnLayout layout,
    required double viewportWidth,
    required double bodyHeight,
  }) {
    final style = widget.style;
    final rowCount = _totalRowCount;

    if (rowCount == 0) {
      return SingleChildScrollView(
        controller: _bodyHorizontalController,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: layout.totalWidth,
          height: bodyHeight,
          child: Center(
            child: widget.emptyPlaceholder ??
                Text(
                  'No rows to display',
                  style: style.cellTextStyle,
                ),
          ),
        ),
      );
    }

    final rowListenable = Listenable.merge(<Listenable>[
      _controller,
      _hoveredVisualRow,
      _hasFocusNotifier,
    ]);

    return MouseRegion(
      onExit: (_) => _hoveredVisualRow.value = null,
      child: RawScrollbar(
        controller: _verticalController,
        scrollbarOrientation: ScrollbarOrientation.right,
        thumbVisibility: style.scrollbarThumbVisibility,
        thickness: style.scrollbarThickness,
        radius: style.scrollbarRadius,
        thumbColor: style.scrollbarThumbColor,
        notificationPredicate: (notification) =>
            notification.metrics.axis == Axis.vertical,
        child: RawScrollbar(
          controller: _bodyHorizontalController,
          scrollbarOrientation: ScrollbarOrientation.bottom,
          thumbVisibility: style.scrollbarThumbVisibility &&
              layout.totalWidth > viewportWidth + 0.5,
          thickness: style.scrollbarThickness,
          radius: style.scrollbarRadius,
          thumbColor: style.scrollbarThumbColor,
          notificationPredicate: (notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _bodyHorizontalController,
            scrollDirection: Axis.horizontal,
            child: SizedBox(
              width: layout.totalWidth,
              height: bodyHeight,
              child: _buildBodyScrollSurface(
                rowCount: rowCount,
                bodyHeight: bodyHeight,
                layout: layout,
                rowListenable: rowListenable,
              ),
            ),
          ),
        ),
      ),
    );
  }

  static bool _isSpanOverlaid(DenseRowSpan? span) =>
      span != null && (span.rowSpan > 1 || span.backgroundColor != null);

  static TextAlign _textAlignForAlignment(AlignmentGeometry alignment) {
    final resolved = alignment.resolve(TextDirection.ltr);
    if (resolved.x > 0.25) {
      return TextAlign.right;
    }
    if (resolved.x.abs() <= 0.25) {
      return TextAlign.center;
    }
    return TextAlign.left;
  }

  Widget _buildBodyScrollSurface({
    required int rowCount,
    required double bodyHeight,
    required _EffectiveColumnLayout layout,
    required Listenable rowListenable,
  }) {
    final style = widget.style;
    final listView = ListView.builder(
      controller: _verticalController,
      itemCount: rowCount,
      itemExtent: style.rowHeight,
      physics:
          widget.shrinkWrap && rowCount * style.rowHeight <= bodyHeight + 0.5
              ? const NeverScrollableScrollPhysics()
              : const ClampingScrollPhysics(),
      itemBuilder: (context, visualIndex) => _buildVirtualRow(
        context: context,
        visualIndex: visualIndex,
        layout: layout,
        rowListenable: rowListenable,
      ),
    );

    final hasSpans = widget.rowSpanBuilder != null;
    final hasEditors = _hasEditableColumns;
    if (!hasSpans && !hasEditors) {
      return listView;
    }

    final overlayListenable = Listenable.merge(<Listenable>[
      _verticalController,
      _controller,
    ]);

    return ClipRect(
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          listView,
          if (hasSpans)
            IgnorePointer(
              child: AnimatedBuilder(
                animation: overlayListenable,
                builder: (context, _) => _buildMergedCellsOverlay(
                  context: context,
                  rowCount: rowCount,
                  bodyHeight: bodyHeight,
                  layout: layout,
                ),
              ),
            ),
          if (hasEditors)
            AnimatedBuilder(
              animation: overlayListenable,
              builder: (context, _) => _buildActiveEditorOverlay(
                context: context,
                rowCount: rowCount,
                layout: layout,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActiveEditorOverlay({
    required BuildContext context,
    required int rowCount,
    required _EffectiveColumnLayout layout,
  }) {
    final coord = _controller.editingCell;
    if (coord == null ||
        rowCount <= 0 ||
        coord.columnIndex < 0 ||
        coord.columnIndex >= _resolvedColumns.length) {
      return const SizedBox.shrink();
    }

    final visualRow = _originalToVisualIndex(coord.rowIndex);
    if (visualRow == null) {
      return const SizedBox.shrink();
    }

    final style = widget.style;
    final rowH = style.rowHeight;
    final scrollOffset = _verticalController.hasClients
        ? math.max(0.0, _verticalController.offset)
        : 0.0;

    var startRow = visualRow;
    var effectiveRows = 1;
    final spanResolver = widget.rowSpanBuilder;
    if (spanResolver != null) {
      final span = spanResolver(visualRow, coord.columnIndex);
      if (span != null && span.rowSpan > 1) {
        startRow = span.startRow.clamp(0, rowCount - 1);
        final endExcl = span.endRowExclusive.clamp(startRow + 1, rowCount);
        effectiveRows = endExcl - startRow;
      }
    }

    final boxTop = startRow * rowH - scrollOffset;
    final boxHeight = effectiveRows * rowH;
    final colLeft = layout.columnOffsets[coord.columnIndex];
    final colW = layout.columnWidths[coord.columnIndex];
    final col = _resolvedColumns[coord.columnIndex];
    final errorText = _controller.editingError;
    final borderColor = errorText != null
        ? style.editingErrorBorderColor
        : (style.editingCellBorderColor ?? style.activeSortIconColor);
    final bgColor = style.editingCellBackgroundColor ?? style.backgroundColor;

    final Widget editorBody;
    if (col.editorBuilder != null) {
      editorBody = col.editorBuilder!(
        context,
        DenseCellEditContext(
          coord: coord,
          rowId:
              _controller.editingRowId ?? _controller.rowIdAt(coord.rowIndex),
          rawValue: _activeEditBaselineValue,
          initialText: _activeEditInitialText,
          textController: _editTextController,
          focusNode: _editFocusNode,
          textStyle: style.cellTextStyle,
          errorText: errorText,
          tapRegionGroupId: _editTapRegionGroup,
          commit: ([overrideText]) => _commitEditingCell(
            overrideText: overrideText,
            restoreTableFocus: true,
          ),
          cancel: () => _cancelEditingCell(restoreTableFocus: true),
        ),
      );
    } else {
      editorBody = Padding(
        padding: style.cellPadding,
        child: Align(
          alignment: col.alignment,
          child: EditableText(
            key: const ValueKey<String>('_dense_inline_editor'),
            controller: _editTextController,
            focusNode: _editFocusNode,
            autofocus: true,
            style: style.cellTextStyle,
            cursorColor: style.editingCursorColor ?? style.activeSortIconColor,
            backgroundCursorColor: style.gridColor,
            selectionColor: style.editingSelectionColor,
            textAlign: _textAlignForAlignment(col.alignment),
            maxLines: 1,
            onChanged: (_) {
              if (_controller.editingError != null) {
                _controller.clearEditingError();
              }
            },
            onSubmitted: (_) => _commitAndMoveDown(),
          ),
        ),
      );
    }

    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        Positioned(
          key: const ValueKey<String>('_dense_editor_pos'),
          left: colLeft,
          top: boxTop,
          width: colW,
          height: boxHeight,
          child: TapRegion(
            groupId: _editTapRegionGroup,
            onTapOutside:
                widget.commitOnTapOutside ? _handleEditorTapOutside : null,
            child: Focus(
              canRequestFocus: false,
              skipTraversal: true,
              onKeyEvent: _handleEditorKeyEvent,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: bgColor,
                  border: Border.all(color: borderColor, width: 1.5),
                ),
                child: editorBody,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMergedCellsOverlay({
    required BuildContext context,
    required int rowCount,
    required double bodyHeight,
    required _EffectiveColumnLayout layout,
  }) {
    final spanResolver = widget.rowSpanBuilder;
    if (spanResolver == null || rowCount <= 0 || bodyHeight <= 0) {
      return const SizedBox.shrink();
    }

    final style = widget.style;
    final rowH = style.rowHeight;
    final scrollOffset = _verticalController.hasClients
        ? math.max(0.0, _verticalController.offset)
        : 0.0;

    final firstRow = (scrollOffset / rowH).floor().clamp(0, rowCount - 1);
    final lastRow =
        ((scrollOffset + bodyHeight) / rowH).ceil().clamp(0, rowCount - 1);
    final colCount = _resolvedColumns.length;
    final mergedWidgets = <Widget>[];

    for (var colIdx = 0; colIdx < colCount; colIdx++) {
      final colLeft = layout.columnOffsets[colIdx];
      final colW = layout.columnWidths[colIdx];
      final col = _resolvedColumns[colIdx];
      final hasRightDivider = style.showVerticalGridLines &&
          (colIdx < colCount - 1 ||
              _hasActionsColumn ||
              (colLeft + colW < layout.totalWidth - 0.5));

      var vRow = firstRow;
      while (vRow <= lastRow) {
        final span = spanResolver(vRow, colIdx);
        if (!_isSpanOverlaid(span)) {
          vRow++;
          continue;
        }

        final startRow = span!.startRow.clamp(0, rowCount - 1);
        final endExcl = span.endRowExclusive.clamp(startRow + 1, rowCount);
        final effectiveRows = endExcl - startRow;
        final boxTop = startRow * rowH - scrollOffset;
        final boxHeight = effectiveRows * rowH;
        final startOriginal = _visualToOriginalIndex(startRow);
        final isMergedDirty = widget.trackDirtyCells &&
            style.dirtyCellIndicatorSize > 0 &&
            _controller.isCellDirty(startOriginal, colIdx);

        var innerTop = 0.0;
        var innerHeight = boxHeight;
        if (span.stickyViewportAlignment && boxHeight > rowH) {
          final visTop = math.max(0.0, boxTop);
          final visBottom = math.min(bodyHeight, boxTop + boxHeight);
          innerHeight = math.min(
            boxHeight,
            math.max(rowH, visBottom - visTop),
          );
          innerTop = (visTop - boxTop).clamp(0.0, boxHeight - innerHeight);
        }

        final cellChild = Padding(
          padding: style.cellPadding,
          child: Align(
            alignment: col.alignment,
            child: _buildCellContent(
              context: context,
              originalRowIndex: startOriginal,
              columnIndex: colIdx,
              textStyle: style.cellTextStyle,
            ),
          ),
        );

        mergedWidgets.add(
          Positioned(
            key: ValueKey<int>(startRow * colCount + colIdx),
            left: colLeft,
            top: boxTop,
            width: colW,
            height: boxHeight,
            child: CustomPaint(
              painter: _DenseMergedCellPainter(
                backgroundColor: span.backgroundColor ?? style.backgroundColor,
                gridColor: style.gridColor,
                drawRightBorder: hasRightDivider,
                drawBottomBorder: style.showHorizontalGridLines,
                isDirty: isMergedDirty,
                dirtyIndicatorColor: style.dirtyCellIndicatorColor,
                dirtyIndicatorSize: style.dirtyCellIndicatorSize,
              ),
              child: innerTop == 0.0 && innerHeight == boxHeight
                  ? cellChild
                  : Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        Positioned(
                          left: 0.0,
                          right: 0.0,
                          top: innerTop,
                          height: innerHeight,
                          child: cellChild,
                        ),
                      ],
                    ),
            ),
          ),
        );

        vRow = math.max(vRow + 1, endExcl);
      }
    }

    if (mergedWidgets.isEmpty) {
      return const SizedBox.shrink();
    }
    return Stack(
      clipBehavior: Clip.none,
      children: mergedWidgets,
    );
  }

  Widget _buildVirtualRow({
    required BuildContext context,
    required int visualIndex,
    required _EffectiveColumnLayout layout,
    required Listenable rowListenable,
  }) {
    final originalIndex = _visualToOriginalIndex(visualIndex);
    final style = widget.style;
    final hasEditors = _hasEditableColumns;
    final isInteractive = hasEditors ||
        widget.selectionMode != DenseSelectionMode.none ||
        widget.onRowTap != null ||
        widget.onRowDoubleTap != null ||
        widget.onRowActivated != null;

    return MouseRegion(
      cursor: isInteractive ? SystemMouseCursors.click : MouseCursor.defer,
      onEnter: (_) => _hoveredVisualRow.value = visualIndex,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: (details) => _handleRowPointerTap(
          visualIndex,
          fromCheckbox: false,
          localDx: details.localPosition.dx,
        ),
        onSecondaryTapDown: widget.onRowSecondaryTapDown != null
            ? (details) => widget.onRowSecondaryTapDown!(originalIndex, details)
            : null,
        child: AnimatedBuilder(
          animation: rowListenable,
          builder: (context, _) {
            final isSelected = _controller.isRowSelected(originalIndex);
            final isHovered = _hoveredVisualRow.value == visualIndex;
            final isFocused = _hasFocusNotifier.value &&
                _controller.focusedRow == originalIndex;

            Color bgColor;
            if (isSelected && isHovered) {
              bgColor = style.selectedHoveredRowColor;
            } else if (isSelected) {
              bgColor = style.selectedRowColor;
            } else if (isHovered) {
              bgColor = style.hoveredRowColor;
            } else {
              bgColor = visualIndex.isEven
                  ? style.backgroundColor
                  : style.altBackgroundColor;
            }

            final effectiveTextStyle = isSelected
                ? (style.selectedCellTextStyle ?? style.cellTextStyle)
                : style.cellTextStyle;

            final colCount = _resolvedColumns.length;
            final spanResolver = widget.rowSpanBuilder;
            List<bool>? overlaidCols;
            if (spanResolver != null) {
              for (var c = 0; c < colCount; c++) {
                if (_isSpanOverlaid(spanResolver(visualIndex, c))) {
                  overlaidCols ??= List<bool>.filled(colCount, false);
                  overlaidCols[c] = true;
                }
              }
            }

            List<bool>? dirtyCols;
            if (widget.trackDirtyCells &&
                style.dirtyCellIndicatorSize > 0 &&
                _controller.hasDirtyCells) {
              for (var c = 0; c < colCount; c++) {
                if (_controller.isCellDirty(originalIndex, c)) {
                  dirtyCols ??= List<bool>.filled(colCount, false);
                  dirtyCols[c] = true;
                }
              }
            }

            final focusedCol =
                (isFocused && hasEditors && !_controller.isEditing)
                    ? _controller.focusedColumn
                    : null;

            return CustomPaint(
              painter: _DenseRowGridPainter(
                baseBackgroundColor: style.backgroundColor,
                backgroundColor: bgColor,
                gridColor: style.gridColor,
                focusBorderColor:
                    isFocused ? style.focusedRowBorderColor : null,
                focusedColumnIndex: focusedCol,
                focusedCellBorderColor:
                    style.focusedCellBorderColor ?? style.focusedRowBorderColor,
                dirtyColumns: dirtyCols,
                dirtyIndicatorColor: style.dirtyCellIndicatorColor,
                dirtyIndicatorSize: style.dirtyCellIndicatorSize,
                checkboxWidth: layout.checkboxWidth,
                columnOffsets: layout.columnOffsets,
                columnWidths: layout.columnWidths,
                overlaidColumns: overlaidCols,
                dividerOffsets: layout.dividerOffsets,
                showVerticalLines: style.showVerticalGridLines,
                showHorizontalLines: style.showHorizontalGridLines,
              ),
              child: SizedBox(
                width: layout.totalWidth,
                height: style.rowHeight,
                child: Row(
                  children: <Widget>[
                    if (_showCheckboxes)
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: () => _handleRowPointerTap(
                          visualIndex,
                          fromCheckbox: true,
                        ),
                        child: SizedBox(
                          width: layout.checkboxWidth,
                          height: style.rowHeight,
                          child: Center(
                            child: _DenseCheckbox(
                              value: isSelected,
                              style: style,
                            ),
                          ),
                        ),
                      ),
                    for (var colIdx = 0;
                        colIdx < _resolvedColumns.length;
                        colIdx++)
                      if (overlaidCols != null && overlaidCols[colIdx])
                        SizedBox(
                          width: layout.columnWidths[colIdx],
                          height: style.rowHeight,
                        )
                      else
                        SizedBox(
                          width: layout.columnWidths[colIdx],
                          height: style.rowHeight,
                          child: Padding(
                            padding: style.cellPadding,
                            child: Align(
                              alignment: _resolvedColumns[colIdx].alignment,
                              child: _buildCellContent(
                                context: context,
                                originalRowIndex: originalIndex,
                                columnIndex: colIdx,
                                textStyle: effectiveTextStyle,
                              ),
                            ),
                          ),
                        ),
                    if (_hasActionsColumn)
                      SizedBox(
                        width: layout.actionsWidth,
                        height: style.rowHeight,
                        child: Padding(
                          padding: style.cellPadding,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: _buildRowActions(context, originalIndex),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildCellContent({
    required BuildContext context,
    required int originalRowIndex,
    required int columnIndex,
    required TextStyle textStyle,
  }) {
    if (_controller.editingCell ==
        DenseCellCoord(originalRowIndex, columnIndex)) {
      return const SizedBox.shrink();
    }
    if (widget.trackDirtyCells && widget.displayDirtyText) {
      final staged = _controller.dirtyTextAt(originalRowIndex, columnIndex);
      if (staged != null) {
        return Text(
          staged,
          style: textStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      }
    }

    final builder = widget._cellBuilder;
    if (builder != null) {
      return DefaultTextStyle.merge(
        style: textStyle,
        child: builder(context, originalRowIndex, columnIndex),
      );
    }

    final matrix = widget.data!;
    final row = matrix[originalRowIndex];
    final Object? cell = columnIndex < row.length ? row[columnIndex] : '';
    if (cell is Widget) {
      return cell;
    }
    return Text(
      cell?.toString() ?? '',
      style: textStyle,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildRowActions(BuildContext context, int originalRowIndex) {
    final indexed = widget._indexedActions;
    if (indexed != null) {
      return indexed(context, originalRowIndex);
    }
    final matrixActions = widget.actions;
    if (matrixActions != null && widget.data != null) {
      return matrixActions(originalRowIndex, widget.data![originalRowIndex]);
    }
    return const SizedBox.shrink();
  }
}

class _EffectiveColumnLayout {
  const _EffectiveColumnLayout({
    required this.checkboxWidth,
    required this.actionsWidth,
    required this.columnOffsets,
    required this.columnWidths,
    required this.dividerOffsets,
    required this.totalWidth,
  });

  final double checkboxWidth;
  final double actionsWidth;
  final List<double> columnOffsets;
  final List<double> columnWidths;
  final List<double> dividerOffsets;
  final double totalWidth;
}

class _DenseHeaderGridPainter extends CustomPainter {
  const _DenseHeaderGridPainter({
    required this.backgroundColor,
    required this.borderColor,
    required this.dividerOffsets,
  });

  final Color backgroundColor;
  final Color borderColor;
  final List<double> dividerOffsets;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, fillPaint);

    final linePaint = Paint()
      ..color = borderColor
      ..strokeWidth = 1.0;

    for (var i = 0; i < dividerOffsets.length; i++) {
      final x = dividerOffsets[i] - 0.5;
      if (x > 0 && x <= size.width) {
        canvas.drawLine(Offset(x, 0), Offset(x, size.height), linePaint);
      }
    }

    final bottomY = size.height - 0.5;
    canvas.drawLine(Offset(0, bottomY), Offset(size.width, bottomY), linePaint);
  }

  @override
  bool shouldRepaint(covariant _DenseHeaderGridPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.borderColor != borderColor ||
      !_doubleListEquals(oldDelegate.dividerOffsets, dividerOffsets);
}

class _DenseRowGridPainter extends CustomPainter {
  const _DenseRowGridPainter({
    required this.baseBackgroundColor,
    required this.backgroundColor,
    required this.gridColor,
    required this.focusBorderColor,
    required this.focusedColumnIndex,
    required this.focusedCellBorderColor,
    required this.dirtyColumns,
    required this.dirtyIndicatorColor,
    required this.dirtyIndicatorSize,
    required this.checkboxWidth,
    required this.columnOffsets,
    required this.columnWidths,
    required this.overlaidColumns,
    required this.dividerOffsets,
    required this.showVerticalLines,
    required this.showHorizontalLines,
  });

  final Color baseBackgroundColor;
  final Color backgroundColor;
  final Color gridColor;
  final Color? focusBorderColor;
  final int? focusedColumnIndex;
  final Color focusedCellBorderColor;
  final List<bool>? dirtyColumns;
  final Color dirtyIndicatorColor;
  final double dirtyIndicatorSize;
  final double checkboxWidth;
  final List<double> columnOffsets;
  final List<double> columnWidths;
  final List<bool>? overlaidColumns;
  final List<double> dividerOffsets;
  final bool showVerticalLines;
  final bool showHorizontalLines;

  @override
  void paint(Canvas canvas, Size size) {
    final overlaid = overlaidColumns;
    if (overlaid == null) {
      final fillPaint = Paint()..color = backgroundColor;
      canvas.drawRect(Offset.zero & size, fillPaint);

      if (showVerticalLines || showHorizontalLines) {
        final gridPaint = Paint()
          ..color = gridColor
          ..strokeWidth = 1.0;

        if (showVerticalLines) {
          for (var i = 0; i < dividerOffsets.length; i++) {
            final x = dividerOffsets[i] - 0.5;
            if (x > 0 && x <= size.width) {
              canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
            }
          }
        }

        if (showHorizontalLines) {
          final y = size.height - 0.5;
          canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
        }
      }
    } else {
      final basePaint = Paint()..color = baseBackgroundColor;
      canvas.drawRect(Offset.zero & size, basePaint);

      final rowPaint = Paint()..color = backgroundColor;
      final gridPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1.0;
      final bottomY = size.height - 0.5;

      void paintUnmergedSegment(double startX, double endX) {
        if (endX <= startX) {
          return;
        }
        if (backgroundColor != baseBackgroundColor) {
          canvas.drawRect(
            Rect.fromLTRB(startX, 0.0, endX, size.height),
            rowPaint,
          );
        }
        if (showHorizontalLines) {
          canvas.drawLine(
            Offset(startX, bottomY),
            Offset(endX, bottomY),
            gridPaint,
          );
        }
      }

      if (checkboxWidth > 0) {
        paintUnmergedSegment(0.0, checkboxWidth);
      }
      var lastDataEnd = checkboxWidth;
      for (var c = 0; c < columnWidths.length; c++) {
        final colStart = columnOffsets[c];
        final colEnd = colStart + columnWidths[c];
        lastDataEnd = colEnd;
        if (!overlaid[c]) {
          paintUnmergedSegment(colStart, colEnd);
        }
      }
      if (size.width > lastDataEnd) {
        paintUnmergedSegment(lastDataEnd, size.width);
      }

      if (showVerticalLines) {
        for (var i = 0; i < dividerOffsets.length; i++) {
          final x = dividerOffsets[i] - 0.5;
          if (x > 0 && x <= size.width) {
            canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
          }
        }
      }
    }

    final dirty = dirtyColumns;
    if (dirty != null && dirtyIndicatorSize > 0) {
      final dirtyPaint = Paint()
        ..color = dirtyIndicatorColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final tri = dirtyIndicatorSize;
      for (var c = 0; c < dirty.length && c < columnOffsets.length; c++) {
        if (!dirty[c] || (overlaid != null && overlaid[c])) {
          continue;
        }
        final left = columnOffsets[c];
        final path = Path()
          ..moveTo(left, 0.0)
          ..lineTo(left + tri, 0.0)
          ..lineTo(left, tri)
          ..close();
        canvas.drawPath(path, dirtyPaint);
      }
    }

    final focusColor = focusBorderColor;
    if (focusColor != null && size.width > 2 && size.height > 2) {
      final focusPaint = Paint()
        ..color = focusColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.0;
      canvas.drawRect(
        Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
        focusPaint,
      );
    }

    final focusCol = focusedColumnIndex;
    if (focusCol != null &&
        focusCol >= 0 &&
        focusCol < columnWidths.length &&
        (overlaid == null || !overlaid[focusCol]) &&
        size.height > 2) {
      final cellW = columnWidths[focusCol];
      if (cellW > 2) {
        final cellPaint = Paint()
          ..color = focusedCellBorderColor
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5;
        canvas.drawRect(
          Rect.fromLTWH(
            columnOffsets[focusCol] + 0.75,
            0.75,
            cellW - 1.5,
            size.height - 1.5,
          ),
          cellPaint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DenseRowGridPainter oldDelegate) =>
      oldDelegate.baseBackgroundColor != baseBackgroundColor ||
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.focusBorderColor != focusBorderColor ||
      oldDelegate.focusedColumnIndex != focusedColumnIndex ||
      oldDelegate.focusedCellBorderColor != focusedCellBorderColor ||
      oldDelegate.dirtyIndicatorColor != dirtyIndicatorColor ||
      oldDelegate.dirtyIndicatorSize != dirtyIndicatorSize ||
      oldDelegate.checkboxWidth != checkboxWidth ||
      oldDelegate.showVerticalLines != showVerticalLines ||
      oldDelegate.showHorizontalLines != showHorizontalLines ||
      !_boolListEquals(oldDelegate.dirtyColumns, dirtyColumns) ||
      !_boolListEquals(oldDelegate.overlaidColumns, overlaidColumns) ||
      !_doubleListEquals(oldDelegate.columnOffsets, columnOffsets) ||
      !_doubleListEquals(oldDelegate.columnWidths, columnWidths) ||
      !_doubleListEquals(oldDelegate.dividerOffsets, dividerOffsets);
}

class _DenseMergedCellPainter extends CustomPainter {
  const _DenseMergedCellPainter({
    required this.backgroundColor,
    required this.gridColor,
    required this.drawRightBorder,
    required this.drawBottomBorder,
    required this.isDirty,
    required this.dirtyIndicatorColor,
    required this.dirtyIndicatorSize,
  });

  final Color backgroundColor;
  final Color gridColor;
  final bool drawRightBorder;
  final bool drawBottomBorder;
  final bool isDirty;
  final Color dirtyIndicatorColor;
  final double dirtyIndicatorSize;

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, fillPaint);

    if (isDirty && dirtyIndicatorSize > 0) {
      final dirtyPaint = Paint()
        ..color = dirtyIndicatorColor
        ..style = PaintingStyle.fill
        ..isAntiAlias = true;
      final tri = dirtyIndicatorSize;
      final path = Path()
        ..moveTo(0.0, 0.0)
        ..lineTo(tri, 0.0)
        ..lineTo(0.0, tri)
        ..close();
      canvas.drawPath(path, dirtyPaint);
    }

    if (drawRightBorder || drawBottomBorder) {
      final borderPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1.0;
      if (drawRightBorder && size.width >= 1.0) {
        final rx = size.width - 0.5;
        canvas.drawLine(Offset(rx, 0.0), Offset(rx, size.height), borderPaint);
      }
      if (drawBottomBorder && size.height >= 1.0) {
        final by = size.height - 0.5;
        canvas.drawLine(Offset(0.0, by), Offset(size.width, by), borderPaint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DenseMergedCellPainter oldDelegate) =>
      oldDelegate.backgroundColor != backgroundColor ||
      oldDelegate.gridColor != gridColor ||
      oldDelegate.drawRightBorder != drawRightBorder ||
      oldDelegate.drawBottomBorder != drawBottomBorder ||
      oldDelegate.isDirty != isDirty ||
      oldDelegate.dirtyIndicatorColor != dirtyIndicatorColor ||
      oldDelegate.dirtyIndicatorSize != dirtyIndicatorSize;
}

class _DenseUnsortedIconPainter extends CustomPainter {
  const _DenseUnsortedIconPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.36)
      ..lineTo(size.width * 0.5, size.height * 0.12)
      ..lineTo(size.width * 0.8, size.height * 0.36)
      ..moveTo(size.width * 0.2, size.height * 0.64)
      ..lineTo(size.width * 0.5, size.height * 0.88)
      ..lineTo(size.width * 0.8, size.height * 0.64);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DenseUnsortedIconPainter oldDelegate) =>
      oldDelegate.color != color;
}

class _DenseSortArrowPainter extends CustomPainter {
  const _DenseSortArrowPainter({
    required this.direction,
    required this.color,
  });

  final DenseSortDirection direction;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill
      ..isAntiAlias = true;

    final path = Path();
    if (direction == DenseSortDirection.ascending) {
      path
        ..moveTo(size.width * 0.5, size.height * 0.15)
        ..lineTo(size.width * 0.92, size.height * 0.85)
        ..lineTo(size.width * 0.08, size.height * 0.85)
        ..close();
    } else {
      path
        ..moveTo(size.width * 0.08, size.height * 0.15)
        ..lineTo(size.width * 0.92, size.height * 0.15)
        ..lineTo(size.width * 0.5, size.height * 0.85)
        ..close();
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _DenseSortArrowPainter oldDelegate) =>
      oldDelegate.direction != direction || oldDelegate.color != color;
}

class _DenseCheckbox extends StatelessWidget {
  const _DenseCheckbox({
    required this.value,
    required this.style,
  });

  final bool? value; // true = checked, false = unchecked, null = indeterminate
  final DenseStyle style;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(14.0, 14.0),
      painter: _DenseCheckboxPainter(
        value: value,
        activeColor: style.checkboxActiveColor,
        checkColor: style.checkboxCheckColor,
        borderColor: style.checkboxBorderColor,
      ),
    );
  }
}

class _DenseCheckboxPainter extends CustomPainter {
  const _DenseCheckboxPainter({
    required this.value,
    required this.activeColor,
    required this.checkColor,
    required this.borderColor,
  });

  final bool? value;
  final Color activeColor;
  final Color checkColor;
  final Color borderColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0.5, 0.5, size.width - 1.0, size.height - 1.0),
      const Radius.circular(2.5),
    );

    if (value == false) {
      final borderPaint = Paint()
        ..color = borderColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2;
      canvas.drawRRect(rrect, borderPaint);
      return;
    }

    final fillPaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(rrect, fillPaint);

    final glyphPaint = Paint()
      ..color = checkColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    if (value == true) {
      final path = Path()
        ..moveTo(size.width * 0.24, size.height * 0.52)
        ..lineTo(size.width * 0.43, size.height * 0.72)
        ..lineTo(size.width * 0.78, size.height * 0.30);
      canvas.drawPath(path, glyphPaint);
    } else {
      // Indeterminate horizontal bar
      final midY = size.height * 0.5;
      canvas.drawLine(
        Offset(size.width * 0.25, midY),
        Offset(size.width * 0.75, midY),
        glyphPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _DenseCheckboxPainter oldDelegate) =>
      oldDelegate.value != value ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.checkColor != checkColor ||
      oldDelegate.borderColor != borderColor;
}

bool _boolListEquals(List<bool>? a, List<bool>? b) {
  if (identical(a, b)) {
    return true;
  }
  if (a == null || b == null || a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}

bool _doubleListEquals(List<double> a, List<double> b) {
  if (identical(a, b)) {
    return true;
  }
  if (a.length != b.length) {
    return false;
  }
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) {
      return false;
    }
  }
  return true;
}
