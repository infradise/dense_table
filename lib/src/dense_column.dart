import 'package:flutter/widgets.dart';

/// Row selection behavior for `DenseTable`.
enum DenseSelectionMode {
  /// Rows cannot be selected.
  none,

  /// At most one row can be selected at a time.
  single,

  /// Multiple rows can be selected via click, `Ctrl`/`Cmd`+click,
  /// `Shift`+click range selection, checkboxes, or keyboard navigation.
  multi,
}

/// Sort order for a sortable column in `DenseTable`.
enum DenseSortDirection {
  /// Lowest to highest (`A -> Z`, `0 -> 9`).
  ascending,

  /// Highest to lowest (`Z -> A`, `9 -> 0`).
  descending,
}

/// Header click cycling behavior for sortable columns in `DenseTable`.
enum DenseSortCycle {
  /// Cycles `initialSortDirection -> opposite -> unsorted (null)`.
  tristate,

  /// Toggles strictly between `ascending` and `descending` once sorted,
  /// starting at `DenseColumn.initialSortDirection` when switching columns.
  toggle,
}

/// Pointer/keyboard gesture policy that activates inline cell editing on an
/// editable `DenseColumn`.
enum DenseEditTrigger {
  /// Enters edit mode when double-clicking an editable cell, or when pressing
  /// `F2` / `Enter` while focused on an editable cell.
  doubleTap,

  /// Enters edit mode only via keyboard (`F2` or `Enter`) or programmatic
  /// controller calls, preserving pointer double-clicks for row activation.
  f2OrEnter,

  /// Enters edit mode immediately on a primary single click of an editable
  /// cell (as well as `F2` or `Enter`).
  singleTap,
}

/// Immutable `(rowIndex, columnIndex)` coordinate identifying a data cell by
/// its original data row index and zero-based column index.
@immutable
class DenseCellCoord {
  /// Creates a [DenseCellCoord] for [rowIndex] and [columnIndex].
  const DenseCellCoord(this.rowIndex, this.columnIndex);

  /// Zero-based original data row index (`0 .. rowCount - 1`).
  final int rowIndex;

  /// Zero-based data column index (`0 .. columnCount - 1`).
  final int columnIndex;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DenseCellCoord &&
        other.rowIndex == rowIndex &&
        other.columnIndex == columnIndex;
  }

  @override
  int get hashCode => Object.hash(rowIndex, columnIndex);

  @override
  String toString() => 'DenseCellCoord($rowIndex, $columnIndex)';
}

/// Immutable record describing a committed inline cell edit.
@immutable
class DenseCellChange {
  /// Creates a [DenseCellChange] for [coord] from [previousValue] to [newText].
  const DenseCellChange({
    required this.coord,
    required this.previousValue,
    required this.newText,
    this.rowId,
    this.baselineText,
  });

  /// Cell coordinate (`rowIndex`, `columnIndex`) in the current dataset.
  final DenseCellCoord coord;

  /// Optional stable record identifier resolved from `rowIdBuilder` when bound.
  final Object? rowId;

  /// Original baseline value prior to uncommitted inline edits.
  final Object? previousValue;

  /// Optional formatted baseline edit string (for example from `editValueGetter`)
  /// used to detect when subsequent edits revert a cell back to its initial
  /// editable text while keeping a typed [previousValue] (such as a [num]).
  final String? baselineText;

  /// Committed text produced by the inline cell editor.
  final String newText;

  /// Returns a copy of this [DenseCellChange] with specified fields replaced.
  DenseCellChange copyWith({
    DenseCellCoord? coord,
    Object? rowId,
    Object? previousValue,
    String? baselineText,
    String? newText,
  }) {
    return DenseCellChange(
      coord: coord ?? this.coord,
      rowId: rowId ?? this.rowId,
      previousValue: previousValue ?? this.previousValue,
      baselineText: baselineText ?? this.baselineText,
      newText: newText ?? this.newText,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DenseCellChange &&
        other.coord == coord &&
        other.rowId == rowId &&
        other.previousValue == previousValue &&
        other.newText == newText;
  }

  @override
  int get hashCode => Object.hash(coord, rowId, previousValue, newText);

  @override
  String toString() =>
      'DenseCellChange(coord: $coord, rowId: $rowId, previousValue: $previousValue, newText: $newText)';
}

/// Context passed to a custom [DenseCellEditorBuilder] for rendering bespoke
/// inline cell editors (such as enum pickers, toggles, or formatted inputs).
@immutable
class DenseCellEditContext {
  /// Creates a [DenseCellEditContext] for the active cell editing session.
  const DenseCellEditContext({
    required this.coord,
    required this.rowId,
    required this.rawValue,
    required this.initialText,
    required this.textController,
    required this.focusNode,
    required this.textStyle,
    required this.errorText,
    required this.tapRegionGroupId,
    required this.commit,
    required this.cancel,
  });

  /// Coordinate of the cell currently being edited.
  final DenseCellCoord coord;

  /// Optional stable record ID resolved via `rowIdBuilder` for [coord].
  final Object? rowId;

  /// Underlying baseline cell value before inline editing started.
  final Object? rawValue;

  /// Initial string loaded into [textController] when editing began.
  final String initialText;

  /// Managed [TextEditingController] holding the current draft string.
  final TextEditingController textController;

  /// Managed [FocusNode] assigned to the active cell editor.
  final FocusNode focusNode;

  /// Effective cell [TextStyle] matching the surrounding `DenseTable`.
  final TextStyle textStyle;

  /// Validation error message from [DenseColumn.validator], or `null` if valid.
  final String? errorText;

  /// Group identifier for `TapRegion` so custom overlay popups can share the
  /// active editor's outside-tap boundary.
  final Object tapRegionGroupId;

  /// Validates and commits [textController] (or `overrideText` if supplied),
  /// returning `true` when validation succeeds.
  final bool Function([String? overrideText]) commit;

  /// Discards draft changes and closes the active inline editor.
  final VoidCallback cancel;
}

/// Signature for validating draft inline cell text before committing.
///
/// Return `null` when [draftText] is valid, or a non-null human-readable error
/// string to block commit and highlight the active cell with an error border.
typedef DenseCellValidator = String? Function(
  int rowIndex,
  int columnIndex,
  Object? previousValue,
  String draftText,
);

/// Signature for dynamically enabling or disabling inline editing per cell
/// (for example, locking primary-key cells or read-only system rows).
typedef DenseCellEditablePredicate = bool Function(
  int rowIndex,
  int columnIndex,
);

/// Signature for extracting the initial editable string for `(rowIndex, columnIndex)`.
typedef DenseCellEditValueGetter = String Function(
  int rowIndex,
  int columnIndex,
);

/// Signature for building a custom inline editor widget inside an editable cell.
typedef DenseCellEditorBuilder = Widget Function(
  BuildContext context,
  DenseCellEditContext editContext,
);

/// Signature invoked whenever a modified cell edit passes validation and commits.
typedef DenseCellEditCommittedCallback = void Function(DenseCellChange change);

/// Immutable representation of the active sort column and direction.
@immutable
class DenseSortState {
  /// Creates a [DenseSortState] for [columnIndex] and [direction].
  const DenseSortState({
    required this.columnIndex,
    required this.direction,
  });

  /// Zero-based index of the sorted data column.
  final int columnIndex;

  /// Active sort direction.
  final DenseSortDirection direction;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DenseSortState &&
        other.columnIndex == columnIndex &&
        other.direction == direction;
  }

  @override
  int get hashCode => Object.hash(columnIndex, direction);

  @override
  String toString() =>
      'DenseSortState(columnIndex: $columnIndex, direction: $direction)';
}

/// Signature for comparing two cell values during column sorting.
typedef DenseCellComparator = int Function(Object? a, Object? b);

/// Signature for lazily building a cell widget for a visible `(rowIndex, columnIndex)`.
///
/// [rowIndex] is always the original data row index (`0 <= rowIndex < rowCount`),
/// regardless of the current sort order.
typedef DenseCellBuilder = Widget Function(
  BuildContext context,
  int rowIndex,
  int columnIndex,
);

/// Signature for extracting a raw comparable value for `(rowIndex, columnIndex)`
/// when using `DenseTable.builder` with built-in client-side sorting.
typedef DenseRawValueGetter = Object? Function(int rowIndex, int columnIndex);

/// Signature returning a stable record identifier (such as a UID, primary key,
/// or object path) for [rowIndex] (`0 <= rowIndex < rowCount`).
///
/// When supplied to `DenseTable` (`rowIdBuilder`), row selection, keyboard
/// focus, and the Shift-selection range anchor remain bound to the underlying
/// record across external search filtering, pagination, and live streaming
/// insertions or deletions.
typedef DenseRowIdGetter = Object Function(int rowIndex);

/// Signature for building custom header content for [column] with awareness
/// of its current [sortDirection] (`null` when unsorted).
typedef DenseHeaderCellBuilder = Widget Function(
  BuildContext context,
  DenseColumn column,
  int columnIndex,
  DenseSortDirection? sortDirection,
);

/// Signature for building a custom sort indicator widget for [direction]
/// (`null` when the sortable column is currently unsorted).
typedef DenseSortIconBuilder = Widget Function(
  BuildContext context,
  DenseSortDirection? direction,
);

/// Describes a vertically merged cell spanning [rowSpan] consecutive visual
/// rows starting at [startRow].
@immutable
class DenseRowSpan {
  /// Creates a [DenseRowSpan] starting at [startRow] and covering [rowSpan]
  /// consecutive visual rows (`startRow .. startRow + rowSpan - 1`).
  const DenseRowSpan({
    required this.startRow,
    required this.rowSpan,
    this.backgroundColor,
    this.stickyViewportAlignment = true,
  })  : assert(startRow >= 0, 'startRow must be non-negative.'),
        assert(rowSpan >= 1, 'rowSpan must be at least 1.');

  /// Zero-based visual row index where this merged cell begins.
  final int startRow;

  /// Number of consecutive visual rows covered by this merged cell.
  final int rowSpan;

  /// Optional semantic background fill color painted inside this merged cell.
  final Color? backgroundColor;

  /// Whether cell content stays aligned within the visible viewport slice of
  /// tall multi-row spans when partially scrolled off-screen.
  final bool stickyViewportAlignment;

  /// Exclusive ending visual row index (`startRow + rowSpan`).
  int get endRowExclusive => startRow + rowSpan;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DenseRowSpan &&
        other.startRow == startRow &&
        other.rowSpan == rowSpan &&
        other.backgroundColor == backgroundColor &&
        other.stickyViewportAlignment == stickyViewportAlignment;
  }

  @override
  int get hashCode => Object.hash(
        startRow,
        rowSpan,
        backgroundColor,
        stickyViewportAlignment,
      );

  @override
  String toString() => 'DenseRowSpan(startRow: $startRow, rowSpan: $rowSpan)';
}

/// Signature resolving an optional [DenseRowSpan] covering
/// `(visualRowIndex, columnIndex)`.
///
/// Return `null` when `(visualRowIndex, columnIndex)` is a standard single-row
/// cell. When a cell spans multiple rows (`rowSpan > 1`), every visual row in
/// `startRow .. startRow + rowSpan - 1` must return the covering [DenseRowSpan]
/// so the virtualized viewport keeps the merged cell visible even after
/// [DenseRowSpan.startRow] scrolls above the top of the viewport.
typedef DenseRowSpanResolver = DenseRowSpan? Function(
  int visualRowIndex,
  int columnIndex,
);

/// Rich configuration for a single column in `DenseTable`.
@immutable
class DenseColumn {
  /// Creates a [DenseColumn] definition.
  const DenseColumn({
    required this.title,
    this.initialWidth = 120.0,
    this.minWidth,
    this.maxWidth,
    this.flex,
    this.resizable = true,
    this.sortable = true,
    this.editable = false,
    this.initialSortDirection = DenseSortDirection.ascending,
    this.alignment = Alignment.centerLeft,
    this.comparator,
    this.validator,
    this.editorBuilder,
    this.headerKey,
    this.headerChild,
    this.headerBuilder,
  }) : assert(initialWidth > 0, 'initialWidth must be strictly positive.');

  /// Display title shown in the column header when [headerChild] and
  /// [headerBuilder] are null.
  final String title;

  /// Initial width of this column in logical pixels.
  final double initialWidth;

  /// Optional per-column minimum resize width (overrides `DenseStyle.minColumnWidth`).
  final double? minWidth;

  /// Optional per-column maximum resize width (overrides `DenseStyle.maxColumnWidth`).
  final double? maxWidth;

  /// Optional proportional flex weight used to distribute leftover horizontal
  /// viewport space when total column widths are narrower than the table.
  final double? flex;

  /// Whether the user can drag this column's right border to resize it.
  final bool resizable;

  /// Whether clicking this column header sorts the table (when sorting is enabled).
  final bool sortable;

  /// Whether cells in this column support spreadsheet-style inline editing.
  final bool editable;

  /// Initial [DenseSortDirection] applied when this column is first clicked.
  final DenseSortDirection initialSortDirection;

  /// Alignment applied to cells and header content within this column.
  final AlignmentGeometry alignment;

  /// Optional custom comparator used when sorting by this column.
  final DenseCellComparator? comparator;

  /// Optional validator run before committing inline edits in this column.
  final DenseCellValidator? validator;

  /// Optional custom inline editor builder overriding the default zero-dependency
  /// `EditableText` cell editor for this column.
  final DenseCellEditorBuilder? editorBuilder;

  /// Optional key attached to the interactive header cell container.
  final Key? headerKey;

  /// Optional custom widget rendered in place of [title] inside the header cell.
  final Widget? headerChild;

  /// Optional sort-aware builder for full header cell content customization
  /// (such as icon-only headers with corner sort badges).
  final DenseHeaderCellBuilder? headerBuilder;
}

/// Default zero-dependency smart comparator for `DenseTable` cell values.
///
/// Handles `null` values (always placed after non-null values in ascending
/// order), [num], [bool], [DateTime], [Duration], and natural numeric-aware
/// strings (so `'9.5 ms' < '12.0 ms' < '100.0 ms'` and `'Row #2' < 'Row #10'`).
int compareDenseValues(Object? a, Object? b) {
  if (identical(a, b)) {
    return 0;
  }
  if (a == null) {
    return 1;
  }
  if (b == null) {
    return -1;
  }
  if (a is num && b is num) {
    return a.compareTo(b);
  }
  if (a is DateTime && b is DateTime) {
    return a.compareTo(b);
  }
  if (a is Duration && b is Duration) {
    return a.compareTo(b);
  }
  if (a is bool && b is bool) {
    if (a == b) {
      return 0;
    }
    return a ? 1 : -1;
  }
  return _compareNaturalStrings(a.toString(), b.toString());
}

int _compareNaturalStrings(String a, String b) {
  final lenA = a.length;
  final lenB = b.length;
  var i = 0;
  var j = 0;

  while (i < lenA && j < lenB) {
    final ca = a.codeUnitAt(i);
    final cb = b.codeUnitAt(j);

    if (_isAsciiDigit(ca) && _isAsciiDigit(cb)) {
      final numStartA = i;
      final numStartB = j;

      while (i < lenA && _isAsciiDigit(a.codeUnitAt(i))) {
        i++;
      }
      while (j < lenB && _isAsciiDigit(b.codeUnitAt(j))) {
        j++;
      }

      // Include a single decimal fractional part when present on either side.
      var hasDecimalA = false;
      var hasDecimalB = false;
      if (i + 1 < lenA &&
          a.codeUnitAt(i) == 0x2E &&
          _isAsciiDigit(a.codeUnitAt(i + 1))) {
        hasDecimalA = true;
        i++;
        while (i < lenA && _isAsciiDigit(a.codeUnitAt(i))) {
          i++;
        }
      }
      if (j + 1 < lenB &&
          b.codeUnitAt(j) == 0x2E &&
          _isAsciiDigit(b.codeUnitAt(j + 1))) {
        hasDecimalB = true;
        j++;
        while (j < lenB && _isAsciiDigit(b.codeUnitAt(j))) {
          j++;
        }
      }

      if (hasDecimalA || hasDecimalB) {
        final da = double.tryParse(a.substring(numStartA, i));
        final db = double.tryParse(b.substring(numStartB, j));
        if (da != null && db != null && da != db) {
          return da.compareTo(db);
        }
      } else {
        // Compare integer chunks without overflowing 64-bit integers.
        var trimA = numStartA;
        while (trimA < i - 1 && a.codeUnitAt(trimA) == 0x30) {
          trimA++;
        }
        var trimB = numStartB;
        while (trimB < j - 1 && b.codeUnitAt(trimB) == 0x30) {
          trimB++;
        }
        final digitsA = i - trimA;
        final digitsB = j - trimB;
        if (digitsA != digitsB) {
          return digitsA.compareTo(digitsB);
        }
        for (var k = 0; k < digitsA; k++) {
          final diff = a.codeUnitAt(trimA + k) - b.codeUnitAt(trimB + k);
          if (diff != 0) {
            return diff;
          }
        }
      }
      continue;
    }

    final lowerA = _toLowerAscii(ca);
    final lowerB = _toLowerAscii(cb);
    if (lowerA != lowerB) {
      return lowerA - lowerB;
    }
    i++;
    j++;
  }

  if (lenA != lenB) {
    return lenA.compareTo(lenB);
  }
  return a.compareTo(b);
}

bool _isAsciiDigit(int codeUnit) => codeUnit >= 0x30 && codeUnit <= 0x39;

int _toLowerAscii(int codeUnit) =>
    (codeUnit >= 0x41 && codeUnit <= 0x5A) ? codeUnit + 0x20 : codeUnit;
