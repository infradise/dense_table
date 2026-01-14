/*
 * Copyright 2026 Infradise Inc.
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *      http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */

import 'package:flutter/material.dart';

/// A high-density data table widget designed for professional desktop and web
/// applications.
///
/// [DenseTable] is designed to display a large amount of data in a compact
/// layout.
///
/// It prioritizes information density and rendering performance.
/// It uses virtualization to handle large datasets efficiently (for
/// performance) and allows precise control over styling via [DenseStyle].

class DenseTable extends StatefulWidget {
  /// The list of column headers.
  final List<String> headers;

  /// The raw data to be displayed in the table rows.
  final List<List<dynamic>> data;

  /// Configuration for the table's appearance (colors, dimensions,
  /// text styles).
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
  State<DenseTable> createState() => _DenseTableState();
}

class _DenseTableState extends State<DenseTable> {
  // Explicit ScrollControllers are required for desktop Scrollbars to work
  // correctly.
  final ScrollController _verticalController = ScrollController();
  final ScrollController _horizontalController = ScrollController();

  @override
  void dispose() {
    _verticalController.dispose();
    _horizontalController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        decoration: BoxDecoration(
          border: Border.all(color: widget.style.borderColor),
          color: widget.style.backgroundColor,
        ),
        child: Column(
          children: [
            // 1. Header Row (Horizontal Scroll Sync might be needed in v0.2.0)
            _buildHeaderRow(),

            // 2. Data Area with Virtualization (scroll)
            Expanded(
              child: Scrollbar(
                // Connect the controller to the Scrollbar
                controller: _verticalController,
                thumbVisibility: true,
                thickness: 8.0,
                radius: Radius.zero, // Squared scrollbar for professional feel
                child: ListView.builder(
                  // Connect the SAME controller to the ListView
                  controller: _verticalController,
                  itemCount: widget.data.length,
                  // Critical for performance: fixed height allows O(1) layout
                  // calculation
                  itemExtent: widget.style.rowHeight,
                  itemBuilder: (context, index) =>
                      _buildDataRow(widget.data[index], index),
                ),
              ),
            ),
          ],
        ),
      );

  Widget _buildHeaderRow() => Container(
        height: widget.style.headerHeight,
        decoration: BoxDecoration(
          color: widget.style.headerBackgroundColor,
          border: Border(bottom: BorderSide(color: widget.style.borderColor)),
        ),
        child: Row(
          children: List.generate(
            widget.headers.length,
            (index) => Container(
              width: widget.columnWidths[index],
              decoration: BoxDecoration(
                border: Border(
                  right: BorderSide(
                      color: widget.style.borderColor), // Vertical separator
                ),
              ),
              padding: widget.style.cellPadding,
              alignment: Alignment.centerLeft,
              child: Text(
                widget.headers[index],
                style: widget.style.headerTextStyle,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
      );

  Widget _buildDataRow(List<dynamic> rowData, int rowIndex) {
    // Zebra striping for better readability - even/odd row background processing
    final bgColor = rowIndex.isEven
        ? widget.style.backgroundColor
        : widget.style.altBackgroundColor;

    return Container(
      height: widget.style.rowHeight,
      color: bgColor,
      child: Row(
        children: List.generate(
          rowData.length,
          (colIndex) => Container(
            width: widget.columnWidths[colIndex],
            decoration: BoxDecoration(
              border: Border(
                right:
                    BorderSide(color: widget.style.gridColor), // vertical grid
                bottom: BorderSide(
                    color: widget.style.gridColor), // horizontal grid
              ),
            ),
            padding: widget.style.cellPadding,
            alignment: Alignment.centerLeft,
            child: Text(
              rowData[colIndex].toString(),
              style: widget.style.cellTextStyle,
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
