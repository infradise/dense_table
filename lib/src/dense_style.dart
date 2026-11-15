import 'package:flutter/widgets.dart';

/// Visual styling and dimension tokens for `DenseTable`.
///
/// Default values provide a compact, pixel-sharp dark IDE aesthetic suitable
/// for dense enterprise consoles and developer tools. Use [DenseStyle.light]
/// for light-mode workspaces or customize individual tokens via [copyWith].
@immutable
class DenseStyle {
  /// Creates a [DenseStyle] with compact dark IDE defaults.
  const DenseStyle({
    this.rowHeight = 24.0,
    this.headerHeight = 28.0,
    this.minColumnWidth = 40.0,
    this.maxColumnWidth = 1200.0,
    this.checkboxColumnWidth = 34.0,
    this.backgroundColor = const Color(0xFF1E1F22),
    this.altBackgroundColor = const Color(0xFF2B2D30),
    this.headerBackgroundColor = const Color(0xFF3C3F41),
    this.hoveredRowColor = const Color(0xFF32363C),
    this.selectedRowColor = const Color(0xFF214283),
    this.selectedHoveredRowColor = const Color(0xFF28509E),
    this.focusedRowBorderColor = const Color(0xFF4C8BF5),
    this.borderColor = const Color(0xFF4E5155),
    this.gridColor = const Color(0xFF383A3D),
    this.sortIconColor = const Color(0xFF8C919A),
    this.activeSortIconColor = const Color(0xFF56A8F5),
    this.resizeHandleActiveColor = const Color(0xFF56A8F5),
    this.checkboxActiveColor = const Color(0xFF3574F0),
    this.checkboxCheckColor = const Color(0xFFFFFFFF),
    this.checkboxBorderColor = const Color(0xFF6E7278),
    this.scrollbarThumbColor = const Color(0x669AA0A6),
    this.scrollbarThickness = 8.0,
    this.scrollbarThumbVisibility = true,
    this.scrollbarRadius = Radius.zero,
    this.borderRadius = BorderRadius.zero,
    this.showVerticalGridLines = true,
    this.showHorizontalGridLines = true,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.cellTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
    ),
    this.selectedCellTextStyle,
    this.headerTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
    ),
    this.activeHeaderTextStyle,
    this.showUnsortedSortIcon = false,
    this.sortIconInline = false,
    this.focusedCellBorderColor,
    this.editingCellBackgroundColor,
    this.editingCellBorderColor,
    this.editingErrorBorderColor = const Color(0xFFE5534B),
    this.editingCursorColor,
    this.editingSelectionColor = const Color(0x663574F0),
    this.dirtyCellIndicatorColor = const Color(0xFFE5A50A),
    this.dirtyCellIndicatorSize = 5.0,
  })  : assert(rowHeight > 0, 'rowHeight must be strictly positive.'),
        assert(headerHeight > 0, 'headerHeight must be strictly positive.'),
        assert(minColumnWidth >= 16.0, 'minColumnWidth must be >= 16.0.'),
        assert(
          maxColumnWidth >= minColumnWidth,
          'maxColumnWidth must be >= minColumnWidth.',
        ),
        assert(
          dirtyCellIndicatorSize >= 0.0,
          'dirtyCellIndicatorSize must be non-negative.',
        );

  /// Creates the default dark IDE [DenseStyle] with optional overrides.
  const DenseStyle.dark({
    this.rowHeight = 24.0,
    this.headerHeight = 28.0,
    this.minColumnWidth = 40.0,
    this.maxColumnWidth = 1200.0,
    this.checkboxColumnWidth = 34.0,
    this.backgroundColor = const Color(0xFF1E1F22),
    this.altBackgroundColor = const Color(0xFF2B2D30),
    this.headerBackgroundColor = const Color(0xFF3C3F41),
    this.hoveredRowColor = const Color(0xFF32363C),
    this.selectedRowColor = const Color(0xFF214283),
    this.selectedHoveredRowColor = const Color(0xFF28509E),
    this.focusedRowBorderColor = const Color(0xFF4C8BF5),
    this.borderColor = const Color(0xFF4E5155),
    this.gridColor = const Color(0xFF383A3D),
    this.sortIconColor = const Color(0xFF8C919A),
    this.activeSortIconColor = const Color(0xFF56A8F5),
    this.resizeHandleActiveColor = const Color(0xFF56A8F5),
    this.checkboxActiveColor = const Color(0xFF3574F0),
    this.checkboxCheckColor = const Color(0xFFFFFFFF),
    this.checkboxBorderColor = const Color(0xFF6E7278),
    this.scrollbarThumbColor = const Color(0x669AA0A6),
    this.scrollbarThickness = 8.0,
    this.scrollbarThumbVisibility = true,
    this.scrollbarRadius = Radius.zero,
    this.borderRadius = BorderRadius.zero,
    this.showVerticalGridLines = true,
    this.showHorizontalGridLines = true,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.cellTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
    ),
    this.selectedCellTextStyle,
    this.headerTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
    ),
    this.activeHeaderTextStyle,
    this.showUnsortedSortIcon = false,
    this.sortIconInline = false,
    this.focusedCellBorderColor,
    this.editingCellBackgroundColor,
    this.editingCellBorderColor,
    this.editingErrorBorderColor = const Color(0xFFE5534B),
    this.editingCursorColor,
    this.editingSelectionColor = const Color(0x663574F0),
    this.dirtyCellIndicatorColor = const Color(0xFFE5A50A),
    this.dirtyCellIndicatorSize = 5.0,
  })  : assert(rowHeight > 0, 'rowHeight must be strictly positive.'),
        assert(headerHeight > 0, 'headerHeight must be strictly positive.'),
        assert(minColumnWidth >= 16.0, 'minColumnWidth must be >= 16.0.'),
        assert(
          maxColumnWidth >= minColumnWidth,
          'maxColumnWidth must be >= minColumnWidth.',
        ),
        assert(
          dirtyCellIndicatorSize >= 0.0,
          'dirtyCellIndicatorSize must be non-negative.',
        );

  /// Creates a crisp light-theme [DenseStyle] for bright desktop and web UIs.
  const DenseStyle.light({
    this.rowHeight = 24.0,
    this.headerHeight = 28.0,
    this.minColumnWidth = 40.0,
    this.maxColumnWidth = 1200.0,
    this.checkboxColumnWidth = 34.0,
    this.backgroundColor = const Color(0xFFFFFFFF),
    this.altBackgroundColor = const Color(0xFFF7F8FA),
    this.headerBackgroundColor = const Color(0xFFEBECF0),
    this.hoveredRowColor = const Color(0xFFEEF2F8),
    this.selectedRowColor = const Color(0xFFD4E2FF),
    this.selectedHoveredRowColor = const Color(0xFFC2D6FF),
    this.focusedRowBorderColor = const Color(0xFF2563EB),
    this.borderColor = const Color(0xFFD0D5DD),
    this.gridColor = const Color(0xFFE4E7EC),
    this.sortIconColor = const Color(0xFF667085),
    this.activeSortIconColor = const Color(0xFF2563EB),
    this.resizeHandleActiveColor = const Color(0xFF2563EB),
    this.checkboxActiveColor = const Color(0xFF2563EB),
    this.checkboxCheckColor = const Color(0xFFFFFFFF),
    this.checkboxBorderColor = const Color(0xFF98A2B3),
    this.scrollbarThumbColor = const Color(0x66667085),
    this.scrollbarThickness = 8.0,
    this.scrollbarThumbVisibility = true,
    this.scrollbarRadius = Radius.zero,
    this.borderRadius = BorderRadius.zero,
    this.showVerticalGridLines = true,
    this.showHorizontalGridLines = true,
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.cellTextStyle = const TextStyle(
      color: Color(0xFF1F2328),
      fontSize: 13.0,
    ),
    this.selectedCellTextStyle,
    this.headerTextStyle = const TextStyle(
      color: Color(0xFF1F2328),
      fontSize: 13.0,
      fontWeight: FontWeight.w600,
    ),
    this.activeHeaderTextStyle,
    this.showUnsortedSortIcon = false,
    this.sortIconInline = false,
    this.focusedCellBorderColor,
    this.editingCellBackgroundColor,
    this.editingCellBorderColor,
    this.editingErrorBorderColor = const Color(0xFFD92D20),
    this.editingCursorColor,
    this.editingSelectionColor = const Color(0x4D2563EB),
    this.dirtyCellIndicatorColor = const Color(0xFFD97706),
    this.dirtyCellIndicatorSize = 5.0,
  })  : assert(rowHeight > 0, 'rowHeight must be strictly positive.'),
        assert(headerHeight > 0, 'headerHeight must be strictly positive.'),
        assert(minColumnWidth >= 16.0, 'minColumnWidth must be >= 16.0.'),
        assert(
          maxColumnWidth >= minColumnWidth,
          'maxColumnWidth must be >= minColumnWidth.',
        ),
        assert(
          dirtyCellIndicatorSize >= 0.0,
          'dirtyCellIndicatorSize must be non-negative.',
        );

  /// Fixed height in logical pixels for every data row (`O(1)` extent).
  final double rowHeight;

  /// Fixed height in logical pixels for the sticky header row.
  final double headerHeight;

  /// Default minimum width constraint when resizing columns interactively.
  final double minColumnWidth;

  /// Default maximum width constraint when resizing columns interactively.
  final double maxColumnWidth;

  /// Width of the leading selection checkbox column when enabled.
  final double checkboxColumnWidth;

  /// Background fill color for even-indexed visual rows.
  final Color backgroundColor;

  /// Alternating (zebra-stripe) fill color for odd-indexed visual rows.
  final Color altBackgroundColor;

  /// Background fill color for the sticky header bar.
  final Color headerBackgroundColor;

  /// Background fill color when the pointer hovers over an unselected row.
  final Color hoveredRowColor;

  /// Background fill color for selected rows.
  final Color selectedRowColor;

  /// Background fill color when the pointer hovers over a selected row.
  final Color selectedHoveredRowColor;

  /// Outline color drawn inside the currently keyboard-focused row.
  final Color focusedRowBorderColor;

  /// Outer table frame and header divider color.
  final Color borderColor;

  /// Cell vertical/horizontal grid line color in the table body.
  final Color gridColor;

  /// Color of inactive/subtle sort indicators.
  final Color sortIconColor;

  /// Color of the active column sort indicator arrow.
  final Color activeSortIconColor;

  /// Highlight color shown on a column's right edge while resizing.
  final Color resizeHandleActiveColor;

  /// Fill color of checked/indeterminate selection checkboxes.
  final Color checkboxActiveColor;

  /// Stroke color of the checkmark or dash inside selection checkboxes.
  final Color checkboxCheckColor;

  /// Border stroke color of unchecked selection checkboxes.
  final Color checkboxBorderColor;

  /// Thumb color for vertical and horizontal desktop scrollbars.
  final Color scrollbarThumbColor;

  /// Thickness in logical pixels for vertical and horizontal scrollbars.
  final double scrollbarThickness;

  /// Whether scrollbars keep their thumbs persistently visible when scrollable.
  final bool scrollbarThumbVisibility;

  /// Corner radius for scrollbar thumbs.
  final Radius scrollbarRadius;

  /// Outer corner radius for the table frame.
  final BorderRadius borderRadius;

  /// Whether vertical column divider lines are painted in data rows.
  final bool showVerticalGridLines;

  /// Whether horizontal row divider lines are painted in data rows.
  final bool showHorizontalGridLines;

  /// Inner padding applied inside header and data cells.
  final EdgeInsetsGeometry cellPadding;

  /// Default text style for string/primitive data cells.
  final TextStyle cellTextStyle;

  /// Optional override text style applied when a row is selected.
  final TextStyle? selectedCellTextStyle;

  /// Default text style for column header titles.
  final TextStyle headerTextStyle;

  /// Optional override text style applied to a sortable column header title
  /// when that column is actively sorted (`sortDirection != null`).
  final TextStyle? activeHeaderTextStyle;

  /// Whether sortable columns display a subtle dual-direction indicator even
  /// when currently unsorted (`sortDirection == null`).
  final bool showUnsortedSortIcon;

  /// Whether the sort indicator sits immediately inline next to the header
  /// title (`3px` gap) instead of expanding toward the column's trailing edge.
  final bool sortIconInline;

  /// Optional outline color drawn around the currently focused cell when at
  /// least one column in the table is editable (defaults to [focusedRowBorderColor]).
  final Color? focusedCellBorderColor;

  /// Optional fill color painted inside the active inline cell editor
  /// (defaults to [backgroundColor]).
  final Color? editingCellBackgroundColor;

  /// Optional outline color painted around the active inline cell editor
  /// (defaults to [activeSortIconColor]).
  final Color? editingCellBorderColor;

  /// Outline color painted around the active inline cell editor when
  /// validation fails.
  final Color editingErrorBorderColor;

  /// Optional text cursor color inside the default inline `EditableText`
  /// (defaults to [activeSortIconColor]).
  final Color? editingCursorColor;

  /// Text selection highlight fill inside the default inline `EditableText`.
  final Color editingSelectionColor;

  /// Fill color of the top-left corner indicator triangle painted on cells with
  /// uncommitted edits in `DenseTableController.dirtyCells`.
  final Color dirtyCellIndicatorColor;

  /// Side length in logical pixels of the top-left dirty cell corner triangle
  /// (`0.0` hides the indicator).
  final double dirtyCellIndicatorSize;

  /// Returns a copy of this [DenseStyle] with the specified fields replaced.
  DenseStyle copyWith({
    double? rowHeight,
    double? headerHeight,
    double? minColumnWidth,
    double? maxColumnWidth,
    double? checkboxColumnWidth,
    Color? backgroundColor,
    Color? altBackgroundColor,
    Color? headerBackgroundColor,
    Color? hoveredRowColor,
    Color? selectedRowColor,
    Color? selectedHoveredRowColor,
    Color? focusedRowBorderColor,
    Color? borderColor,
    Color? gridColor,
    Color? sortIconColor,
    Color? activeSortIconColor,
    Color? resizeHandleActiveColor,
    Color? checkboxActiveColor,
    Color? checkboxCheckColor,
    Color? checkboxBorderColor,
    Color? scrollbarThumbColor,
    double? scrollbarThickness,
    bool? scrollbarThumbVisibility,
    Radius? scrollbarRadius,
    BorderRadius? borderRadius,
    bool? showVerticalGridLines,
    bool? showHorizontalGridLines,
    EdgeInsetsGeometry? cellPadding,
    TextStyle? cellTextStyle,
    TextStyle? selectedCellTextStyle,
    TextStyle? headerTextStyle,
    TextStyle? activeHeaderTextStyle,
    bool? showUnsortedSortIcon,
    bool? sortIconInline,
    Color? focusedCellBorderColor,
    Color? editingCellBackgroundColor,
    Color? editingCellBorderColor,
    Color? editingErrorBorderColor,
    Color? editingCursorColor,
    Color? editingSelectionColor,
    Color? dirtyCellIndicatorColor,
    double? dirtyCellIndicatorSize,
  }) {
    return DenseStyle(
      rowHeight: rowHeight ?? this.rowHeight,
      headerHeight: headerHeight ?? this.headerHeight,
      minColumnWidth: minColumnWidth ?? this.minColumnWidth,
      maxColumnWidth: maxColumnWidth ?? this.maxColumnWidth,
      checkboxColumnWidth: checkboxColumnWidth ?? this.checkboxColumnWidth,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      altBackgroundColor: altBackgroundColor ?? this.altBackgroundColor,
      headerBackgroundColor:
          headerBackgroundColor ?? this.headerBackgroundColor,
      hoveredRowColor: hoveredRowColor ?? this.hoveredRowColor,
      selectedRowColor: selectedRowColor ?? this.selectedRowColor,
      selectedHoveredRowColor:
          selectedHoveredRowColor ?? this.selectedHoveredRowColor,
      focusedRowBorderColor:
          focusedRowBorderColor ?? this.focusedRowBorderColor,
      borderColor: borderColor ?? this.borderColor,
      gridColor: gridColor ?? this.gridColor,
      sortIconColor: sortIconColor ?? this.sortIconColor,
      activeSortIconColor: activeSortIconColor ?? this.activeSortIconColor,
      resizeHandleActiveColor:
          resizeHandleActiveColor ?? this.resizeHandleActiveColor,
      checkboxActiveColor: checkboxActiveColor ?? this.checkboxActiveColor,
      checkboxCheckColor: checkboxCheckColor ?? this.checkboxCheckColor,
      checkboxBorderColor: checkboxBorderColor ?? this.checkboxBorderColor,
      scrollbarThumbColor: scrollbarThumbColor ?? this.scrollbarThumbColor,
      scrollbarThickness: scrollbarThickness ?? this.scrollbarThickness,
      scrollbarThumbVisibility:
          scrollbarThumbVisibility ?? this.scrollbarThumbVisibility,
      scrollbarRadius: scrollbarRadius ?? this.scrollbarRadius,
      borderRadius: borderRadius ?? this.borderRadius,
      showVerticalGridLines:
          showVerticalGridLines ?? this.showVerticalGridLines,
      showHorizontalGridLines:
          showHorizontalGridLines ?? this.showHorizontalGridLines,
      cellPadding: cellPadding ?? this.cellPadding,
      cellTextStyle: cellTextStyle ?? this.cellTextStyle,
      selectedCellTextStyle:
          selectedCellTextStyle ?? this.selectedCellTextStyle,
      headerTextStyle: headerTextStyle ?? this.headerTextStyle,
      activeHeaderTextStyle:
          activeHeaderTextStyle ?? this.activeHeaderTextStyle,
      showUnsortedSortIcon: showUnsortedSortIcon ?? this.showUnsortedSortIcon,
      sortIconInline: sortIconInline ?? this.sortIconInline,
      focusedCellBorderColor:
          focusedCellBorderColor ?? this.focusedCellBorderColor,
      editingCellBackgroundColor:
          editingCellBackgroundColor ?? this.editingCellBackgroundColor,
      editingCellBorderColor:
          editingCellBorderColor ?? this.editingCellBorderColor,
      editingErrorBorderColor:
          editingErrorBorderColor ?? this.editingErrorBorderColor,
      editingCursorColor: editingCursorColor ?? this.editingCursorColor,
      editingSelectionColor:
          editingSelectionColor ?? this.editingSelectionColor,
      dirtyCellIndicatorColor:
          dirtyCellIndicatorColor ?? this.dirtyCellIndicatorColor,
      dirtyCellIndicatorSize:
          dirtyCellIndicatorSize ?? this.dirtyCellIndicatorSize,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is DenseStyle &&
        other.rowHeight == rowHeight &&
        other.headerHeight == headerHeight &&
        other.minColumnWidth == minColumnWidth &&
        other.maxColumnWidth == maxColumnWidth &&
        other.checkboxColumnWidth == checkboxColumnWidth &&
        other.backgroundColor == backgroundColor &&
        other.altBackgroundColor == altBackgroundColor &&
        other.headerBackgroundColor == headerBackgroundColor &&
        other.hoveredRowColor == hoveredRowColor &&
        other.selectedRowColor == selectedRowColor &&
        other.selectedHoveredRowColor == selectedHoveredRowColor &&
        other.focusedRowBorderColor == focusedRowBorderColor &&
        other.borderColor == borderColor &&
        other.gridColor == gridColor &&
        other.sortIconColor == sortIconColor &&
        other.activeSortIconColor == activeSortIconColor &&
        other.resizeHandleActiveColor == resizeHandleActiveColor &&
        other.checkboxActiveColor == checkboxActiveColor &&
        other.checkboxCheckColor == checkboxCheckColor &&
        other.checkboxBorderColor == checkboxBorderColor &&
        other.scrollbarThumbColor == scrollbarThumbColor &&
        other.scrollbarThickness == scrollbarThickness &&
        other.scrollbarThumbVisibility == scrollbarThumbVisibility &&
        other.scrollbarRadius == scrollbarRadius &&
        other.borderRadius == borderRadius &&
        other.showVerticalGridLines == showVerticalGridLines &&
        other.showHorizontalGridLines == showHorizontalGridLines &&
        other.cellPadding == cellPadding &&
        other.cellTextStyle == cellTextStyle &&
        other.selectedCellTextStyle == selectedCellTextStyle &&
        other.headerTextStyle == headerTextStyle &&
        other.activeHeaderTextStyle == activeHeaderTextStyle &&
        other.showUnsortedSortIcon == showUnsortedSortIcon &&
        other.sortIconInline == sortIconInline &&
        other.focusedCellBorderColor == focusedCellBorderColor &&
        other.editingCellBackgroundColor == editingCellBackgroundColor &&
        other.editingCellBorderColor == editingCellBorderColor &&
        other.editingErrorBorderColor == editingErrorBorderColor &&
        other.editingCursorColor == editingCursorColor &&
        other.editingSelectionColor == editingSelectionColor &&
        other.dirtyCellIndicatorColor == dirtyCellIndicatorColor &&
        other.dirtyCellIndicatorSize == dirtyCellIndicatorSize;
  }

  @override
  int get hashCode => Object.hashAll(<Object?>[
        rowHeight,
        headerHeight,
        minColumnWidth,
        maxColumnWidth,
        checkboxColumnWidth,
        backgroundColor,
        altBackgroundColor,
        headerBackgroundColor,
        hoveredRowColor,
        selectedRowColor,
        selectedHoveredRowColor,
        focusedRowBorderColor,
        borderColor,
        gridColor,
        sortIconColor,
        activeSortIconColor,
        resizeHandleActiveColor,
        checkboxActiveColor,
        checkboxCheckColor,
        checkboxBorderColor,
        scrollbarThumbColor,
        scrollbarThickness,
        scrollbarThumbVisibility,
        scrollbarRadius,
        borderRadius,
        showVerticalGridLines,
        showHorizontalGridLines,
        cellPadding,
        cellTextStyle,
        selectedCellTextStyle,
        headerTextStyle,
        activeHeaderTextStyle,
        showUnsortedSortIcon,
        sortIconInline,
        focusedCellBorderColor,
        editingCellBackgroundColor,
        editingCellBorderColor,
        editingErrorBorderColor,
        editingCursorColor,
        editingSelectionColor,
        dirtyCellIndicatorColor,
        dirtyCellIndicatorSize,
      ]);
}
