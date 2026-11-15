import 'dart:collection';

import 'package:flutter/animation.dart';
import 'package:flutter/foundation.dart';

import 'dense_column.dart';

/// Programmatic controller for `DenseTable` selection, sorting, column widths,
/// keyboard focus, and viewport scrolling.
///
/// All selection methods operate on **original data row indices** (`0 .. rowCount - 1`),
/// ensuring selection identity remains stable even as columns are sorted or
/// unsorted.
class DenseTableController extends ChangeNotifier {
  /// Creates a [DenseTableController] with optional initial selection and sort state.
  DenseTableController({
    Iterable<int>? initialSelectedRows,
    DenseSortState? initialSortState,
  }) : _sortState = initialSortState {
    if (initialSelectedRows != null) {
      _selectedRows.addAll(initialSelectedRows);
    }
  }

  final Set<int> _selectedRows = <int>{};
  late final Set<int> _selectedRowsView = _UnmodifiableIntSet(_selectedRows);
  final Map<int, double> _columnWidths = <int, double>{};

  DenseSortState? _sortState;
  int? _focusedOriginalRow;
  int? _anchorOriginalRow;

  void Function(int visualIndex, {Duration? duration, Curve curve})?
      _scrollToVisualRowDelegate;
  int? Function(int originalIndex)? _originalToVisualIndexDelegate;

  /// Read-only view of currently selected original row indices.
  Set<int> get selectedRows => _selectedRowsView;

  /// Number of currently selected rows.
  int get selectedCount => _selectedRows.length;

  /// Whether at least one row is currently selected.
  bool get hasSelection => _selectedRows.isNotEmpty;

  /// Original data index of the keyboard-focused row, if any.
  int? get focusedRow => _focusedOriginalRow;

  /// Original data index of the range-selection anchor row, if any.
  int? get anchorRow => _anchorOriginalRow;

  /// Active sort state, or `null` when rows are in their natural order.
  DenseSortState? get sortState => _sortState;

  /// Returns `true` if [rowIndex] (original data index) is currently selected.
  bool isRowSelected(int rowIndex) => _selectedRows.contains(rowIndex);

  /// Replaces the selection with a single [rowIndex] (or adds it when [additive] is `true`).
  void selectRow(
    int rowIndex, {
    bool additive = false,
    bool updateAnchor = true,
  }) {
    if (rowIndex < 0) {
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

  /// Toggles the selection state of [rowIndex] (original data index).
  void toggleRow(int rowIndex, {bool updateAnchor = true}) {
    if (rowIndex < 0) {
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

  /// Replaces the entire selection with [rowIndices] (original data indices).
  void setSelectedRows(Iterable<int> rowIndices, {int? focusedRow}) {
    _selectedRows
      ..clear()
      ..addAll(rowIndices.where((index) => index >= 0));
    if (focusedRow != null) {
      _focusedOriginalRow = focusedRow;
    }
    notifyListeners();
  }

  /// Selects all rows from `0` up to `totalRowCount - 1`.
  void selectAll(int totalRowCount) {
    if (totalRowCount <= 0) {
      clearSelection();
      return;
    }
    if (_selectedRows.length == totalRowCount) {
      return;
    }
    _selectedRows.clear();
    for (var i = 0; i < totalRowCount; i++) {
      _selectedRows.add(i);
    }
    notifyListeners();
  }

  /// Clears all selected rows.
  void clearSelection({bool clearFocus = false}) {
    var changed = _selectedRows.isNotEmpty;
    _selectedRows.clear();
    if (clearFocus && _focusedOriginalRow != null) {
      _focusedOriginalRow = null;
      _anchorOriginalRow = null;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Updates the focused row without modifying selection.
  void setFocusedRow(int? originalRowIndex, {bool updateAnchor = false}) {
    var changed = false;
    if (_focusedOriginalRow != originalRowIndex) {
      _focusedOriginalRow = originalRowIndex;
      changed = true;
    }
    if (updateAnchor && _anchorOriginalRow != originalRowIndex) {
      _anchorOriginalRow = originalRowIndex;
      changed = true;
    }
    if (changed) {
      notifyListeners();
    }
  }

  /// Sets the active [DenseSortState] (pass `null` to clear sorting).
  void setSort(DenseSortState? sortState) {
    if (_sortState == sortState) {
      return;
    }
    _sortState = sortState;
    notifyListeners();
  }

  /// Cycles sorting on [columnIndex]: `ascending -> descending -> null`.
  void toggleSortColumn(int columnIndex) {
    final current = _sortState;
    if (current == null || current.columnIndex != columnIndex) {
      setSort(
        DenseSortState(
          columnIndex: columnIndex,
          direction: DenseSortDirection.ascending,
        ),
      );
    } else if (current.direction == DenseSortDirection.ascending) {
      setSort(
        DenseSortState(
          columnIndex: columnIndex,
          direction: DenseSortDirection.descending,
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

  /// Prunes any selected or focused indices `>= rowCount` when data shrinks.
  void clampToRowCount(int rowCount) {
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
    if (changed) {
      notifyListeners();
    }
  }

  /// Attaches viewport delegates from the mounted `DenseTable` state.
  void attachTableDelegates({
    required void Function(int visualIndex, {Duration? duration, Curve curve})
        scrollToVisualRow,
    required int? Function(int originalIndex) originalToVisualIndex,
  }) {
    _scrollToVisualRowDelegate = scrollToVisualRow;
    _originalToVisualIndexDelegate = originalToVisualIndex;
  }

  /// Detaches viewport delegates when `DenseTable` unmounts or swaps controllers.
  void detachTableDelegates() {
    _scrollToVisualRowDelegate = null;
    _originalToVisualIndexDelegate = null;
  }
}

class _UnmodifiableIntSet extends SetBase<int> {
  const _UnmodifiableIntSet(this._source);

  final Set<int> _source;

  @override
  bool add(int value) =>
      throw UnsupportedError('Cannot modify unmodifiable selectedRows set.');

  @override
  bool contains(Object? element) => _source.contains(element);

  @override
  Iterator<int> get iterator => _source.iterator;

  @override
  int get length => _source.length;

  @override
  int? lookup(Object? element) => _source.lookup(element);

  @override
  bool remove(Object? value) =>
      throw UnsupportedError('Cannot modify unmodifiable selectedRows set.');

  @override
  Set<int> toSet() => Set<int>.of(_source);
}
