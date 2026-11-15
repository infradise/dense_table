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
    this.alignment = Alignment.centerLeft,
    this.comparator,
    this.headerChild,
  }) : assert(initialWidth > 0, 'initialWidth must be strictly positive.');

  /// Display title shown in the column header when [headerChild] is null.
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

  /// Alignment applied to cells and header content within this column.
  final AlignmentGeometry alignment;

  /// Optional custom comparator used when sorting by this column.
  final DenseCellComparator? comparator;

  /// Optional custom widget rendered in place of [title] inside the header cell.
  final Widget? headerChild;
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
