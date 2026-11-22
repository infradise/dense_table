import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'dense_column.dart';

/// Programmatic controller for `DenseTable` selection, stable row identity,
/// inline cell editing, dirty cell staging, sorting, column widths, keyboard
/// focus, and viewport scrolling.
///
/// All index-based selection methods operate on **original data row indices**
/// (`0 .. rowCount - 1`), ensuring selection identity remains stable as columns
/// are sorted or unsorted.
///
/// When `DenseTable.rowIdBuilder` is supplied, selection, keyboard focus,
/// inline dirty cell changes, and the Shift-selection anchor additionally bind
/// to **stable row IDs** ([selectedRowIds], [focusedRowId], [anchorRowId]),
/// preserving record identity across external search filtering and live
/// streaming mutations.
class DenseTableController extends ChangeNotifier {
  /// Creates a [DenseTableController] with optional initial selection and sort state.
  DenseTableController({
    Iterable<int>? initialSelectedRows,
    Iterable<Object>? initialSelectedRowIds,
    DenseSortState? initialSortState,
    this.retainHiddenSelectionIds = true,
  }) : _sortState = initialSortState {
    if (initialSelectedRows != null) {
      _selectedRows.addAll(initialSelectedRows.where((index) => index >= 0));
    }
    if (initialSelectedRowIds != null) {
      _selectedRowIds.addAll(initialSelectedRowIds);
    }
  }

  /// Whether selected row IDs that are temporarily absent from an externally
  /// filtered dataset remain preserved in [selectedRowIds] until explicitly
  /// deselected or cleared via [clearSelection].
  final bool retainHiddenSelectionIds;

  final Set<int> _selectedRows = <int>{};
  final Set<Object> _selectedRowIds = <Object>{};
  late final Set<int> _selectedRowsView = _UnmodifiableSetView<int>(
    _selectedRows,
  );
  late final Set<Object> _selectedRowIdsView = _UnmodifiableSetView<Object>(
    _selectedRowIds,
  );
  final Map<int, double> _columnWidths = <int, double>{};
  final Map<DenseCellCoord, DenseCellChange> _dirtyCells =
      <DenseCellCoord, DenseCellChange>{};
  final Map<(Object, int), DenseCellChange> _dirtyCellsByRowId =
      <(Object, int), DenseCellChange>{};
  late final Map<DenseCellCoord, DenseCellChange> _dirtyCellsView =
      UnmodifiableMapView<DenseCellCoord, DenseCellChange>(_dirtyCells);

  List<Object>? _boundRowIds;
  Map<Object, int>? _boundIdToIndex;

  DenseSortState? _sortState;
  int? _focusedOriginalRow;
  int? _focusedColumn;
  int? _anchorOriginalRow;
  Object? _focusedRowId;
  Object? _anchorRowId;

  DenseCellCoord? _editingCell;
  Object? _editingRowId;
  String? _editingError;

  void Function(int visualIndex, {Duration? duration, Curve curve})?
      _scrollToVisualRowDelegate;
  int? Function(int originalIndex)? _originalToVisualIndexDelegate;
  bool Function(int originalRowIndex, int columnIndex)? _startEditingDelegate;
  bool Function([String? overrideText])? _commitEditingDelegate;
  VoidCallback? _cancelEditingDelegate;

  bool get _hasIdBinding => _boundRowIds != null && _boundIdToIndex != null;

  /// Read-only view of currently selected original row indices within the
  /// active dataset (`0 .. rowCount - 1`).
  Set<int> get selectedRows => _selectedRowsView;

  /// Read-only view of currently selected stable row IDs when `rowIdBuilder`
  /// is active (including hidden selections when [retainHiddenSelectionIds] is
  /// `true`).
  Set<Object> get selectedRowIds => _selectedRowIdsView;

  /// Number of selected rows currently present in the active dataset.
  int get selectedCount => _selectedRows.length;

  /// Total number of selected stable row IDs (including records temporarily
  /// hidden by an external filter when [retainHiddenSelectionIds] is `true`).
  int get totalSelectedIdCount =>
      _hasIdBinding ? _selectedRowIds.length : _selectedRows.length;

  /// Whether at least one row in the active dataset (or [selectedRowIds]) is selected.
  bool get hasSelection =>
      _selectedRows.isNotEmpty || _selectedRowIds.isNotEmpty;

  /// Original data index of the keyboard-focused row in the active dataset,
  /// or `null` if none (or if the focused record is currently filtered out).
  int? get focusedRow => _focusedOriginalRow;

  /// Stable row ID of the keyboard-focused record when `rowIdBuilder` is active.
  Object? get focusedRowId => _focusedRowId;

  /// Zero-based index of the currently focused data column, or `null` if unset.
  int? get focusedColumn => _focusedColumn;

  /// Original data index of the Shift-selection range anchor row in the active
  /// dataset, or `null` if none (or if the anchor record is currently filtered out).
  int? get anchorRow => _anchorOriginalRow;

  /// Stable row ID of the Shift-selection range anchor record when
  /// `rowIdBuilder` is active.
  Object? get anchorRowId => _anchorRowId;

  /// Active sort state, or `null` when rows are in their natural order.
  DenseSortState? get sortState => _sortState;

  /// Coordinate of the cell currently open for inline editing, or `null` when
  /// no cell is being edited.
  DenseCellCoord? get editingCell => _editingCell;

  /// Stable row ID of the record currently being edited when `rowIdBuilder` is
  /// active, or `null` otherwise.
  Object? get editingRowId => _editingRowId;

  /// Whether an inline cell editing session is currently active.
  bool get isEditing => _editingCell != null;

  /// Active validation error message from `DenseColumn.validator` on
  /// [editingCell], or `null` when valid.
  String? get editingError => _editingError;

  /// Read-only map of uncommitted dirty cell changes present in the active
  /// dataset (`DenseCellCoord -> DenseCellChange`).
  Map<DenseCellCoord, DenseCellChange> get dirtyCells => _dirtyCellsView;

  /// Unmodifiable snapshot of all uncommitted [DenseCellChange] entries,
  /// including edits on records temporarily hidden by an external filter when
  /// `rowIdBuilder` is active.
  List<DenseCellChange> get allDirtyChanges =>
      List<DenseCellChange>.unmodifiable(
        _hasIdBinding ? _dirtyCellsByRowId.values : _dirtyCells.values,
      );

  /// Whether at least one uncommitted dirty cell edit is staged.
  bool get hasDirtyCells =>
      _dirtyCells.isNotEmpty || _dirtyCellsByRowId.isNotEmpty;

  /// Number of uncommitted dirty cells currently visible in the active dataset.
  int get dirtyCellCount => _dirtyCells.length;

  /// Total number of uncommitted dirty cells (including records temporarily
  /// hidden by an external filter when `rowIdBuilder` is active).
  int get totalDirtyCellCount =>
      _hasIdBinding ? _dirtyCellsByRowId.length : _dirtyCells.length;

  /// Returns `true` if `(rowIndex, columnIndex)` currently holds an uncommitted
  /// dirty edit.
  bool isCellDirty(int rowIndex, int columnIndex) =>
      _dirtyCells.containsKey(DenseCellCoord(rowIndex, columnIndex));

  /// Returns the staged [DenseCellChange] at `(rowIndex, columnIndex)`, or
  /// `null` if the cell has not been modified.
  DenseCellChange? dirtyChangeAt(int rowIndex, int columnIndex) =>
      _dirtyCells[DenseCellCoord(rowIndex, columnIndex)];

  /// Returns the staged text at `(rowIndex, columnIndex)`, or `null` if the
  /// cell has not been modified.
  String? dirtyTextAt(int rowIndex, int columnIndex) =>
      _dirtyCells[DenseCellCoord(rowIndex, columnIndex)]?.newText;

  /// Returns `true` if [rowIndex] (original data index) is currently selected.
  bool isRowSelected(int rowIndex) => _selectedRows.contains(rowIndex);

  /// Returns `true` if [rowId] is currently in [selectedRowIds].
  bool isRowIdSelected(Object rowId) => _selectedRowIds.contains(rowId);

  /// Resolves the current original data index for [rowId], or `null` if
  /// `rowIdBuilder` is not active or [rowId] is not in the current dataset.
  int? indexOfRowId(Object rowId) => _boundIdToIndex?[rowId];

  /// Returns the bound stable row ID at [rowIndex], or `null` if unavailable.
  Object? rowIdAt(int rowIndex) {
    final ids = _boundRowIds;
    if (ids == null || rowIndex < 0 || rowIndex >= ids.length) {
      return null;
    }
    return ids[rowIndex];
  }

  /// Replaces the selection with a single [rowIndex] (or adds it when [additive] is `true`).
  void selectRow(
    int rowIndex, {
    bool additive = false,
    bool updateAnchor = true,
  }) {
    if (rowIndex < 0) {
      return;
    }
    if (_hasIdBinding) {
      final id = rowIdAt(rowIndex);
      if (id == null) {
        return;
      }
      selectRowId(id, additive: additive, updateAnchor: updateAnchor);
      return;
    }

    var changed = false;
    if (!additive) {
      if (_selectedRows.length != 1 || !_selectedRows.contains(rowIndex)) {
        _selectedRows
          ..clear()
          ..add(rowIndex);
        changed = true;
      }
    } else if (_selectedRows.add(rowIndex)) {
      changed = true;
    }

    if (_focusedOriginalRow != rowIndex) {
      _focusedOriginalRow = rowIndex;
      changed = true;
    }
    if (updateAnchor && _anchorOriginalRow != rowIndex) {
      _anchorOriginalRow = rowIndex;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Replaces the selection with a single stable [rowId] (or adds it when
  /// [additive] is `true`).
  void selectRowId(
    Object rowId, {
    bool additive = false,
    bool updateAnchor = true,
  }) {
    var changed = false;
    final mappedIndex = _boundIdToIndex?[rowId];

    if (!additive) {
      if (_selectedRowIds.length != 1 || !_selectedRowIds.contains(rowId)) {
        _selectedRowIds
          ..clear()
          ..add(rowId);
        changed = true;
      }
      if (mappedIndex != null) {
        if (_selectedRows.length != 1 || !_selectedRows.contains(mappedIndex)) {
          _selectedRows
            ..clear()
            ..add(mappedIndex);
          changed = true;
        }
      } else if (_selectedRows.isNotEmpty) {
        _selectedRows.clear();
        changed = true;
      }
    } else {
      if (_selectedRowIds.add(rowId)) {
        changed = true;
      }
      if (mappedIndex != null && _selectedRows.add(mappedIndex)) {
        changed = true;
      }
    }

    if (_focusedRowId != rowId || _focusedOriginalRow != mappedIndex) {
      _focusedRowId = rowId;
      _focusedOriginalRow = mappedIndex;
      changed = true;
    }
    if (updateAnchor &&
        (_anchorRowId != rowId || _anchorOriginalRow != mappedIndex)) {
      _anchorRowId = rowId;
      _anchorOriginalRow = mappedIndex;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Toggles the selection state of [rowIndex] (original data index).
  void toggleRow(int rowIndex, {bool updateAnchor = true}) {
    if (rowIndex < 0) {
      return;
    }
    if (_hasIdBinding) {
      final id = rowIdAt(rowIndex);
      if (id == null) {
        return;
      }
      toggleRowId(id, updateAnchor: updateAnchor);
      return;
    }

    if (!_selectedRows.remove(rowIndex)) {
      _selectedRows.add(rowIndex);
    }
    _focusedOriginalRow = rowIndex;
    if (updateAnchor) {
      _anchorOriginalRow = rowIndex;
    }
    notifyListeners();
  }

  /// Toggles the selection state of stable [rowId].
  void toggleRowId(Object rowId, {bool updateAnchor = true}) {
    final mappedIndex = _boundIdToIndex?[rowId];
    if (_selectedRowIds.remove(rowId)) {
      if (mappedIndex != null) {
        _selectedRows.remove(mappedIndex);
      }
    } else {
      _selectedRowIds.add(rowId);
      if (mappedIndex != null) {
        _selectedRows.add(mappedIndex);
      }
    }
    _focusedRowId = rowId;
    _focusedOriginalRow = mappedIndex;
    if (updateAnchor) {
      _anchorRowId = rowId;
      _anchorOriginalRow = mappedIndex;
    }
    notifyListeners();
  }

  /// Replaces the visible selection with [rowIndices] (original data indices).
  ///
  /// When [preserveHiddenSelectedIds] is `true` and `rowIdBuilder` is active,
  /// selected IDs not present in the current dataset remain preserved.
  void setSelectedRows(
    Iterable<int> rowIndices, {
    int? focusedRow,
    bool preserveHiddenSelectedIds = false,
  }) {
    _selectedRows
      ..clear()
      ..addAll(rowIndices.where((index) => index >= 0));

    if (_hasIdBinding) {
      final idMap = _boundIdToIndex!;
      if (preserveHiddenSelectedIds && retainHiddenSelectionIds) {
        _selectedRowIds.removeWhere(idMap.containsKey);
      } else {
        _selectedRowIds.clear();
      }
      for (final index in _selectedRows) {
        final id = rowIdAt(index);
        if (id != null) {
          _selectedRowIds.add(id);
        }
      }
    }

    if (focusedRow != null) {
      _focusedOriginalRow = focusedRow;
      if (_hasIdBinding) {
        _focusedRowId = rowIdAt(focusedRow);
      }
    }
    notifyListeners();
  }

  /// Replaces the entire stable ID selection with [rowIds].
  void setSelectedRowIds(Iterable<Object> rowIds, {Object? focusedRowId}) {
    _selectedRowIds
      ..clear()
      ..addAll(rowIds);

    _selectedRows.clear();
    final idMap = _boundIdToIndex;
    if (idMap != null) {
      for (final id in _selectedRowIds) {
        final idx = idMap[id];
        if (idx != null) {
          _selectedRows.add(idx);
        }
      }
    }

    if (focusedRowId != null) {
      _focusedRowId = focusedRowId;
      _focusedOriginalRow = idMap?[focusedRowId];
    }
    notifyListeners();
  }

  /// Selects all rows in the current dataset (`0 .. totalRowCount - 1`).
  void selectAll(int totalRowCount) {
    if (totalRowCount <= 0) {
      if (!_hasIdBinding || !retainHiddenSelectionIds) {
        clearSelection();
      }
      return;
    }
    if (_selectedRows.length == totalRowCount) {
      return;
    }
    _selectedRows.clear();
    for (var i = 0; i < totalRowCount; i++) {
      _selectedRows.add(i);
    }
    if (_hasIdBinding) {
      _selectedRowIds.addAll(_boundRowIds!);
    }
    notifyListeners();
  }

  /// Toggles selection across all currently visible rows (`0 .. totalRowCount - 1`).
  ///
  /// When [retainHiddenSelectionIds] is `true` and `rowIdBuilder` is active,
  /// deselecting all visible rows only removes the currently visible rows' IDs
  /// without wiping selections hidden by an active search filter.
  void toggleSelectAllVisible(int totalRowCount) {
    if (totalRowCount <= 0) {
      return;
    }
    if (_selectedRows.length >= totalRowCount) {
      _selectedRows.clear();
      if (_hasIdBinding) {
        if (retainHiddenSelectionIds) {
          _selectedRowIds.removeAll(_boundRowIds!);
        } else {
          _selectedRowIds.clear();
        }
      }
      notifyListeners();
    } else {
      selectAll(totalRowCount);
    }
  }

  /// Clears all selected rows (including any hidden [selectedRowIds]).
  void clearSelection({bool clearFocus = false}) {
    var changed = _selectedRows.isNotEmpty || _selectedRowIds.isNotEmpty;
    _selectedRows.clear();
    _selectedRowIds.clear();
    if (clearFocus &&
        (_focusedOriginalRow != null ||
            _focusedRowId != null ||
            _anchorOriginalRow != null ||
            _anchorRowId != null)) {
      _focusedOriginalRow = null;
      _anchorOriginalRow = null;
      _focusedRowId = null;
      _anchorRowId = null;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates the focused row by original index without modifying selection.
  void setFocusedRow(int? originalRowIndex, {bool updateAnchor = false}) {
    var changed = false;
    final mappedId =
        originalRowIndex != null ? rowIdAt(originalRowIndex) : null;

    if (_focusedOriginalRow != originalRowIndex) {
      _focusedOriginalRow = originalRowIndex;
      changed = true;
    }
    if (_hasIdBinding && _focusedRowId != mappedId) {
      _focusedRowId = mappedId;
      changed = true;
    }
    if (updateAnchor) {
      if (_anchorOriginalRow != originalRowIndex) {
        _anchorOriginalRow = originalRowIndex;
        changed = true;
      }
      if (_hasIdBinding && _anchorRowId != mappedId) {
        _anchorRowId = mappedId;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates the focused record by stable [rowId] without modifying selection.
  void setFocusedRowId(Object? rowId, {bool updateAnchor = false}) {
    var changed = false;
    final idMap = _boundIdToIndex;
    final mappedIndex = rowId != null && idMap != null ? idMap[rowId] : null;

    if (_focusedRowId != rowId || _focusedOriginalRow != mappedIndex) {
      _focusedRowId = rowId;
      _focusedOriginalRow = mappedIndex;
      changed = true;
    }
    if (updateAnchor &&
        (_anchorRowId != rowId || _anchorOriginalRow != mappedIndex)) {
      _anchorRowId = rowId;
      _anchorOriginalRow = mappedIndex;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates the focused column index without modifying row selection.
  void setFocusedColumn(int? columnIndex) {
    if (_focusedColumn == columnIndex) {
      return;
    }
    _focusedColumn = columnIndex;
    notifyListeners();
  }

  /// Updates both [focusedRow] and [focusedColumn] in a single notification.
  void setFocusedCell(
    int? originalRowIndex,
    int? columnIndex, {
    bool updateAnchor = false,
  }) {
    var changed = false;
    final mappedId =
        originalRowIndex != null ? rowIdAt(originalRowIndex) : null;

    if (_focusedOriginalRow != originalRowIndex) {
      _focusedOriginalRow = originalRowIndex;
      changed = true;
    }
    if (_focusedColumn != columnIndex) {
      _focusedColumn = columnIndex;
      changed = true;
    }
    if (_hasIdBinding && _focusedRowId != mappedId) {
      _focusedRowId = mappedId;
      changed = true;
    }
    if (updateAnchor) {
      if (_anchorOriginalRow != originalRowIndex) {
        _anchorOriginalRow = originalRowIndex;
        changed = true;
      }
      if (_hasIdBinding && _anchorRowId != mappedId) {
        _anchorRowId = mappedId;
        changed = true;
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Starts an inline cell editing session at `(originalRowIndex, columnIndex)`
  /// on the attached `DenseTable`, returning `true` if the cell is editable.
  bool startEditing(int originalRowIndex, int columnIndex) =>
      _startEditingDelegate?.call(originalRowIndex, columnIndex) ?? false;

  /// Validates and commits the active inline cell edit (optionally substituting
  /// [overrideText]), returning `true` when validation succeeds or no edit is
  /// active.
  bool commitEditing([String? overrideText]) =>
      _commitEditingDelegate?.call(overrideText) ?? true;

  /// Discards any draft text and closes the active inline cell editor.
  void cancelEditing() {
    final delegate = _cancelEditingDelegate;
    if (delegate != null) {
      delegate();
      return;
    }
    if (_editingCell != null ||
        _editingRowId != null ||
        _editingError != null) {
      _editingCell = null;
      _editingRowId = null;
      _editingError = null;
      notifyListeners();
    }
  }

  /// Records or updates a committed [DenseCellChange] in [dirtyCells].
  ///
  /// Preserves the original baseline `previousValue` across consecutive edits
  /// to the same cell. When [revertIfUnchanged] is `true` and `change.newText`
  /// reverts back to the baseline value string, the cell is automatically
  /// removed from [dirtyCells].
  void recordCellChange(
    DenseCellChange change, {
    bool revertIfUnchanged = true,
    bool notify = true,
  }) {
    final coord = change.coord;
    final effectiveRowId = change.rowId ?? rowIdAt(coord.rowIndex);
    final existing = (_hasIdBinding && effectiveRowId != null)
        ? _dirtyCellsByRowId[(effectiveRowId, coord.columnIndex)]
        : _dirtyCells[coord];
    final baseline =
        existing != null ? existing.previousValue : change.previousValue;
    final baselineString =
        (existing != null ? existing.baselineText : change.baselineText) ??
            (baseline?.toString() ?? '');

    if (revertIfUnchanged && change.newText == baselineString) {
      final removedVisible = _dirtyCells.remove(coord) != null;
      var removedById = false;
      if (effectiveRowId != null) {
        removedById =
            _dirtyCellsByRowId.remove((effectiveRowId, coord.columnIndex)) !=
                null;
      }
      if ((removedVisible || removedById) && notify) {
        notifyListeners();
      }
      return;
    }

    final normalized = DenseCellChange(
      coord: coord,
      rowId: effectiveRowId,
      previousValue: baseline,
      baselineText: baselineString,
      newText: change.newText,
    );
    if (existing == normalized && _dirtyCells[coord] == normalized) {
      return;
    }

    _dirtyCells[coord] = normalized;
    if (_hasIdBinding && effectiveRowId != null) {
      _dirtyCellsByRowId[(effectiveRowId, coord.columnIndex)] = normalized;
    }
    if (notify) {
      notifyListeners();
    }
  }

  /// Removes any uncommitted dirty state at `(originalRowIndex, columnIndex)`.
  void clearDirtyCell(int originalRowIndex, int columnIndex) {
    final coord = DenseCellCoord(originalRowIndex, columnIndex);
    final removed = _dirtyCells.remove(coord);
    var removedById = false;
    final id = removed?.rowId ?? rowIdAt(originalRowIndex);
    if (id != null) {
      removedById = _dirtyCellsByRowId.remove((id, columnIndex)) != null;
    }
    if (removed != null || removedById) {
      notifyListeners();
    }
  }

  /// Clears all uncommitted dirty cell edits across both visible and hidden
  /// records (typically called after committing changes to a database or API).
  void clearDirtyCells() {
    if (_dirtyCells.isEmpty && _dirtyCellsByRowId.isEmpty) {
      return;
    }
    _dirtyCells.clear();
    _dirtyCellsByRowId.clear();
    notifyListeners();
  }

  /// Synchronizes the active inline editing session state from `DenseTable`.
  void syncEditingSession({
    required DenseCellCoord? coord,
    Object? rowId,
    String? errorText,
    bool notify = true,
  }) {
    if (_editingCell == coord &&
        _editingRowId == rowId &&
        _editingError == errorText) {
      return;
    }
    _editingCell = coord;
    _editingRowId = rowId;
    _editingError = errorText;
    if (notify) {
      notifyListeners();
    }
  }

  /// Clears [editingError] while keeping [editingCell] open for editing.
  void clearEditingError() {
    if (_editingError == null) {
      return;
    }
    _editingError = null;
    notifyListeners();
  }

  /// Sets the active [DenseSortState] (pass `null` to clear sorting).
  void setSort(DenseSortState? sortState) {
    if (_sortState == sortState) {
      return;
    }
    _sortState = sortState;
    notifyListeners();
  }

  /// Clears sorting so rows return to their original order.
  ///
  /// Equivalent to `setSort(null)`; pairs with [DenseSortCycle.toggle], whose
  /// header clicks never leave the sorted state.
  void clearSort() => setSort(null);

  /// Cycles sorting on [columnIndex] according to [cycle] and
  /// [initialDirection].
  ///
  /// - [DenseSortCycle.tristate] (default):
  ///   `initialDirection -> opposite -> null` (unsorted).
  /// - [DenseSortCycle.toggle]:
  ///   `initialDirection -> opposite -> initialDirection` (2-state toggle).
  void toggleSortColumn(
    int columnIndex, {
    DenseSortCycle cycle = DenseSortCycle.tristate,
    DenseSortDirection initialDirection = DenseSortDirection.ascending,
  }) {
    final current = _sortState;
    if (current == null || current.columnIndex != columnIndex) {
      setSort(
        DenseSortState(
          columnIndex: columnIndex,
          direction: initialDirection,
        ),
      );
      return;
    }

    if (cycle == DenseSortCycle.toggle) {
      final nextDir = current.direction == DenseSortDirection.ascending
          ? DenseSortDirection.descending
          : DenseSortDirection.ascending;
      setSort(
        DenseSortState(
          columnIndex: columnIndex,
          direction: nextDir,
        ),
      );
      return;
    }

    final opposite = initialDirection == DenseSortDirection.ascending
        ? DenseSortDirection.descending
        : DenseSortDirection.ascending;
    if (current.direction == initialDirection) {
      setSort(
        DenseSortState(
          columnIndex: columnIndex,
          direction: opposite,
        ),
      );
    } else {
      setSort(null);
    }
  }

  /// Returns the current width override for [columnIndex], or `null` if unset.
  double? columnWidth(int columnIndex) => _columnWidths[columnIndex];

  /// Sets the width of [columnIndex] in logical pixels.
  void setColumnWidth(int columnIndex, double width) {
    if (_columnWidths[columnIndex] == width) {
      return;
    }
    _columnWidths[columnIndex] = width;
    notifyListeners();
  }

  /// Scrolls the attached `DenseTable` viewport to reveal [originalRowIndex].
  void scrollToRow(
    int originalRowIndex, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    final toVisual = _originalToVisualIndexDelegate;
    final scrollDelegate = _scrollToVisualRowDelegate;
    if (toVisual == null || scrollDelegate == null) {
      return;
    }
    final visualIndex = toVisual(originalRowIndex);
    if (visualIndex != null) {
      scrollDelegate(visualIndex, duration: duration, curve: curve);
    }
  }

  /// Scrolls the attached `DenseTable` viewport to reveal stable [rowId] if
  /// present in the current dataset.
  void scrollToRowId(
    Object rowId, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    final idx = _boundIdToIndex?[rowId];
    if (idx != null) {
      scrollToRow(idx, duration: duration, curve: curve);
    }
  }

  /// Scrolls the attached `DenseTable` viewport directly to [visualRowIndex].
  void scrollToVisualRow(
    int visualRowIndex, {
    Duration? duration,
    Curve curve = Curves.easeOutCubic,
  }) {
    _scrollToVisualRowDelegate?.call(
      visualRowIndex,
      duration: duration,
      curve: curve,
    );
  }

  /// Synchronizes bound row ID maps from `DenseTable` and reconciles
  /// [selectedRows], [focusedRow], and [anchorRow] against the new dataset.
  ///
  /// Returns `true` if any resolved index or selection set changed.
  bool syncRowIdentity({
    required List<Object>? rowIds,
    required Map<Object, int>? idToIndex,
    required int totalRowCount,
    bool notify = true,
  }) {
    if (rowIds == null || idToIndex == null) {
      final wasBound = _hasIdBinding;
      _boundRowIds = null;
      _boundIdToIndex = null;
      final clamped = _clampIndicesInternal(totalRowCount);
      if ((wasBound || clamped) && notify) {
        notifyListeners();
      }
      return wasBound || clamped;
    }

    final wasUnbound = !_hasIdBinding;
    _boundRowIds = rowIds;
    _boundIdToIndex = idToIndex;

    var changed = false;

    // Seed initial IDs from initialSelectedRows on first bind if no IDs exist yet.
    if (wasUnbound && _selectedRowIds.isEmpty && _selectedRows.isNotEmpty) {
      for (final idx in _selectedRows) {
        if (idx >= 0 && idx < rowIds.length) {
          _selectedRowIds.add(rowIds[idx]);
        }
      }
    }
    if (wasUnbound &&
        _focusedRowId == null &&
        _focusedOriginalRow != null &&
        _focusedOriginalRow! >= 0 &&
        _focusedOriginalRow! < rowIds.length) {
      _focusedRowId = rowIds[_focusedOriginalRow!];
    }
    if (wasUnbound &&
        _anchorRowId == null &&
        _anchorOriginalRow != null &&
        _anchorOriginalRow! >= 0 &&
        _anchorOriginalRow! < rowIds.length) {
      _anchorRowId = rowIds[_anchorOriginalRow!];
    }

    if (!retainHiddenSelectionIds && _selectedRowIds.isNotEmpty) {
      final beforeIds = _selectedRowIds.length;
      _selectedRowIds.removeWhere((id) => !idToIndex.containsKey(id));
      if (_selectedRowIds.length != beforeIds) {
        changed = true;
      }
    }

    final nextSelectedIndices = <int>{};
    for (final id in _selectedRowIds) {
      final idx = idToIndex[id];
      if (idx != null) {
        nextSelectedIndices.add(idx);
      }
    }
    if (_selectedRows.length != nextSelectedIndices.length ||
        !_selectedRows.containsAll(nextSelectedIndices)) {
      _selectedRows
        ..clear()
        ..addAll(nextSelectedIndices);
      changed = true;
    }

    final nextFocused =
        _focusedRowId != null ? idToIndex[_focusedRowId!] : null;
    if (_focusedOriginalRow != nextFocused) {
      _focusedOriginalRow = nextFocused;
      changed = true;
    }

    final nextAnchor = _anchorRowId != null ? idToIndex[_anchorRowId!] : null;
    if (_anchorOriginalRow != nextAnchor) {
      _anchorOriginalRow = nextAnchor;
      changed = true;
    }

    if (wasUnbound && _dirtyCellsByRowId.isEmpty && _dirtyCells.isNotEmpty) {
      for (final entry in _dirtyCells.entries) {
        final idx = entry.key.rowIndex;
        if (idx >= 0 && idx < rowIds.length) {
          final id = rowIds[idx];
          _dirtyCellsByRowId[(id, entry.key.columnIndex)] =
              entry.value.copyWith(rowId: id);
        }
      }
    }

    if (_dirtyCellsByRowId.isNotEmpty || _dirtyCells.isNotEmpty) {
      final remappedDirty = <DenseCellCoord, DenseCellChange>{};
      for (final entry in _dirtyCellsByRowId.entries) {
        final mappedIdx = idToIndex[entry.key.$1];
        if (mappedIdx != null) {
          final nextCoord = DenseCellCoord(mappedIdx, entry.key.$2);
          final updated = entry.value.coord == nextCoord
              ? entry.value
              : entry.value.copyWith(coord: nextCoord);
          remappedDirty[nextCoord] = updated;
        }
      }
      if (!mapEquals(_dirtyCells, remappedDirty)) {
        _dirtyCells
          ..clear()
          ..addAll(remappedDirty);
        changed = true;
      }
    }

    if (_editingCell != null && _editingRowId != null) {
      final nextEditIdx = idToIndex[_editingRowId!];
      if (nextEditIdx == null) {
        _editingCell = null;
        _editingRowId = null;
        _editingError = null;
        changed = true;
      } else if (nextEditIdx != _editingCell!.rowIndex) {
        _editingCell = DenseCellCoord(nextEditIdx, _editingCell!.columnIndex);
        changed = true;
      }
    }

    if (changed && notify) {
      notifyListeners();
    }
    return changed;
  }

  /// Emits a deferred notification after a frame-scheduled dataset identity sync.
  void notifyIdentitySynced() {
    notifyListeners();
  }

  /// Prunes any selected or focused indices `>= rowCount` when operating in
  /// index-only mode (`rowIdBuilder == null`).
  void clampToRowCount(int rowCount) {
    if (_hasIdBinding) {
      return;
    }
    if (_clampIndicesInternal(rowCount)) {
      notifyListeners();
    }
  }

  bool _clampIndicesInternal(int rowCount) {
    var changed = false;
    if (_selectedRows.isNotEmpty) {
      final before = _selectedRows.length;
      _selectedRows.removeWhere((idx) => idx < 0 || idx >= rowCount);
      if (_selectedRows.length != before) {
        changed = true;
      }
    }
    if (_focusedOriginalRow != null &&
        (_focusedOriginalRow! < 0 || _focusedOriginalRow! >= rowCount)) {
      _focusedOriginalRow = rowCount > 0 ? rowCount - 1 : null;
      changed = true;
    }
    if (_anchorOriginalRow != null &&
        (_anchorOriginalRow! < 0 || _anchorOriginalRow! >= rowCount)) {
      _anchorOriginalRow = _focusedOriginalRow;
      changed = true;
    }
    if (_dirtyCells.isNotEmpty) {
      final beforeDirty = _dirtyCells.length;
      _dirtyCells.removeWhere(
        (coord, _) => coord.rowIndex < 0 || coord.rowIndex >= rowCount,
      );
      if (_dirtyCells.length != beforeDirty) {
        changed = true;
      }
    }
    if (_editingCell != null &&
        (_editingCell!.rowIndex < 0 || _editingCell!.rowIndex >= rowCount)) {
      _editingCell = null;
      _editingRowId = null;
      _editingError = null;
      changed = true;
    }
    return changed;
  }

  /// Prunes any focused/editing/sorted/dirty column indices `>= columnCount`
  /// when the table's column schema shrinks dynamically.
  bool clampToColumnCount(int columnCount, {bool notify = true}) {
    var changed = false;
    if (_focusedColumn != null &&
        (_focusedColumn! < 0 || _focusedColumn! >= columnCount)) {
      _focusedColumn = columnCount > 0 ? columnCount - 1 : null;
      changed = true;
    }
    if (_editingCell != null &&
        (_editingCell!.columnIndex < 0 ||
            _editingCell!.columnIndex >= columnCount)) {
      _editingCell = null;
      _editingRowId = null;
      _editingError = null;
      changed = true;
    }
    if (_sortState != null &&
        (_sortState!.columnIndex < 0 ||
            _sortState!.columnIndex >= columnCount)) {
      _sortState = null;
      changed = true;
    }
    if (_dirtyCells.isNotEmpty) {
      final beforeDirty = _dirtyCells.length;
      _dirtyCells.removeWhere(
        (coord, _) => coord.columnIndex < 0 || coord.columnIndex >= columnCount,
      );
      if (_dirtyCells.length != beforeDirty) {
        changed = true;
      }
    }
    if (_dirtyCellsByRowId.isNotEmpty) {
      final beforeById = _dirtyCellsByRowId.length;
      _dirtyCellsByRowId.removeWhere(
        (key, _) => key.$2 < 0 || key.$2 >= columnCount,
      );
      if (_dirtyCellsByRowId.length != beforeById) {
        changed = true;
      }
    }
    if (changed && notify) {
      notifyListeners();
    }
    return changed;
  }

  /// Attaches viewport and inline-editing delegates from the mounted
  /// `DenseTable` state.
  void attachTableDelegates({
    required void Function(int visualIndex, {Duration? duration, Curve curve})
        scrollToVisualRow,
    required int? Function(int originalIndex) originalToVisualIndex,
    bool Function(int originalRowIndex, int columnIndex)? startEditing,
    bool Function([String? overrideText])? commitEditing,
    VoidCallback? cancelEditing,
  }) {
    _scrollToVisualRowDelegate = scrollToVisualRow;
    _originalToVisualIndexDelegate = originalToVisualIndex;
    _startEditingDelegate = startEditing;
    _commitEditingDelegate = commitEditing;
    _cancelEditingDelegate = cancelEditing;
  }

  /// Detaches viewport delegates when `DenseTable` unmounts or swaps controllers.
  void detachTableDelegates() {
    _scrollToVisualRowDelegate = null;
    _originalToVisualIndexDelegate = null;
    _startEditingDelegate = null;
    _commitEditingDelegate = null;
    _cancelEditingDelegate = null;
    _boundRowIds = null;
    _boundIdToIndex = null;
    _editingCell = null;
    _editingRowId = null;
    _editingError = null;
  }
}

class _UnmodifiableSetView<E> extends SetBase<E> {
  const _UnmodifiableSetView(this._source);

  final Set<E> _source;

  @override
  bool add(E value) =>
      throw UnsupportedError('Cannot modify unmodifiable selection set.');

  @override
  bool contains(Object? element) => _source.contains(element);

  @override
  Iterator<E> get iterator => _source.iterator;

  @override
  int get length => _source.length;

  @override
  E? lookup(Object? element) => _source.lookup(element);

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Cannot modify unmodifiable selection set.');

  @override
  Set<E> toSet() => Set<E>.of(_source);
}
