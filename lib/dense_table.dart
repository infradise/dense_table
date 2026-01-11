import 'package:flutter/material.dart';

/// A high-density data table widget designed for professional desktop and web applications.
///
/// [DenseTable] is designed to display a large amount of data in a compact layout.
/// It prioritizes information density and rendering performance.
/// It supports virtualization for performance (handles large datasets efficiently)
/// and allows precise control over styling via [DenseStyle].
class DenseTable extends StatelessWidget {
  /// The list of column headers.
  final List<String> headers;

  /// The raw data to be displayed in the table rows.
  final List<List<dynamic>> data;

  /// Configuration for the table's appearance (colors, dimensions, text styles).
  final DenseStyle style;

  /// A map defining the width of each column (index -> width).
  final Map<int, double> columnWidths;

  const DenseTable({
    super.key,
    required this.headers,
    required this.data,
    this.style = const DenseStyle(),
    required this.columnWidths,
  });

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: style.borderColor),
          color: style.backgroundColor,
        ),
        child: Column(
          children: [
            // Header area
            _buildHeaderRow(),
            // Data area (virualization scroll)
            Expanded(
              child: Scrollbar(
                thumbVisibility: true,
                thickness: 8.0,
                radius: Radius.zero, // Squared scrollbar for professional feel
                child: ListView.builder(
                  itemCount: data.length,
                  // Critical for performance: fixed height allows O(1) layout calculation
                  itemExtent: style.rowHeight,
                  itemBuilder: (context, index) {
                    final rowData = data[index];
                    return _buildDataRow(rowData, index);
                  },
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeaderRow() => Container(
        height: style.headerHeight,
        decoration: BoxDecoration(
          color: style.headerBackgroundColor,
          border: Border(bottom: BorderSide(color: style.borderColor)),
        ),
        child: Row(
          children: List.generate(
            headers.length,
            (index) => Container(
              width: columnWidths[index],
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                      color: style.borderColor), // Vertical separator
                ),
              ),
              padding: style.cellPadding,
              alignment: Alignment.centerLeft,
              child: Text(
                headers[index],
                style: style.headerTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );

  Widget _buildDataRow(List<dynamic> rowData, int rowIndex) {
    // Zebra striping for better readability - even/odd row background processing
    final bgColor =
        rowIndex % 2 == 0 ? style.backgroundColor : style.altBackgroundColor;

    return Container(
      height: style.rowHeight,
      color: bgColor,
      child: Row(
        children: List.generate(
          rowData.length,
          (colIndex) => Container(
            width: columnWidths[colIndex],
            decoration: BoxDecoration(
              border: Border(
                right: BorderSide(color: style.gridColor), // vertical grid
                bottom: BorderSide(color: style.gridColor), // horizontal grid
              ),
            ),
            padding: style.cellPadding,
            alignment: Alignment.centerLeft,
            child: Text(
              rowData[colIndex].toString(),
              style: style.cellTextStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis, // text wrap
            ),
          ),
        ),
      ),
    );
  }
}

/// Defines the visual style of the [DenseTable].
///
/// Default values are optimized for a dark, professional IDE-like theme.
class DenseStyle {
  final double rowHeight;
  final double headerHeight;
  final Color backgroundColor;
  final Color altBackgroundColor;
  final Color headerBackgroundColor;
  final Color borderColor;
  final Color gridColor;
  final TextStyle cellTextStyle;
  final TextStyle headerTextStyle;
  final EdgeInsetsGeometry cellPadding;

  const DenseStyle({
    this.rowHeight = 24.0,
    this.headerHeight = 28.0,
    this.backgroundColor = const Color(0xFF1E1F22), // Dark theme background
    this.altBackgroundColor =
        const Color(0xFF2B2D30), // Zebra stripe background
    this.headerBackgroundColor = const Color(0xFF3C3F41),
    this.borderColor = const Color(0xFF4E5155),
    this.gridColor = const Color(0xFF383A3D),
    this.cellPadding = const EdgeInsets.symmetric(horizontal: 8.0),
    this.cellTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
      fontFamily: 'Roboto', // or JetBrains Mono
    ),
    this.headerTextStyle = const TextStyle(
      color: Color(0xFFBCBEC4),
      fontSize: 13.0,
      fontWeight: FontWeight.bold,
    ),
  });
}
