import 'package:dense_table/dense_table.dart';
import 'package:flutter/widgets.dart';

void main() {
  runApp(const DenseTableDemoApp());
}

/// Zero-dependency 100,000-row showcase built strictly on `flutter/widgets.dart`.
class DenseTableDemoApp extends StatefulWidget {
  const DenseTableDemoApp({super.key});

  @override
  State<DenseTableDemoApp> createState() => _DenseTableDemoAppState();
}

class _DenseTableDemoAppState extends State<DenseTableDemoApp> {
  final DenseTableController _controller = DenseTableController();

  int _baseRowCount = 100000;
  String? _statusFilter;
  bool _darkMode = true;
  bool _freezeLeading = true;
  bool _pinActions = true;
  bool _showRegionColumn = true;
  Object? _lastActivatedPodId;
  Object? _lastInspectedPodId;
  Object? _lastSecondaryTappedPodId;
  int? _lastCopiedRowCount;
  int? _lastCopiedColumnCount;

  late List<int> _filteredSourceIndices = _computeFilteredIndices();

  static const List<String> _namespaces = <String>[
    'prod-core',
    'data-cache',
    'edge-gateway',
    'telemetry',
    'auth-system',
  ];

  static const List<String> _regions = <String>[
    'us-east-1',
    'us-west-2',
    'eu-central-1',
    'ap-northeast-1',
  ];

  static const List<String> _statuses = <String>[
    'Running',
    'Running',
    'Running',
    'Pending',
    'Degraded',
  ];

  static const List<String> _nodes = <String>[
    'node-pool-01',
    'node-pool-02',
    'node-pool-03',
    'node-pool-04',
    'node-pool-05',
    'node-pool-06',
  ];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<int> _computeFilteredIndices() {
    if (_statusFilter == null) {
      return List<int>.generate(_baseRowCount, (i) => i, growable: false);
    }
    final matches = <int>[];
    for (var i = 0; i < _baseRowCount; i++) {
      if (_statuses[i % _statuses.length] == _statusFilter) {
        matches.add(i);
      }
    }
    return matches;
  }

  void _updateDataset({int? baseCount, Object? statusFilter = _unchanged}) {
    setState(() {
      if (baseCount != null) {
        _baseRowCount = baseCount;
      }
      if (!identical(statusFilter, _unchanged)) {
        _statusFilter = statusFilter as String?;
      }
      _filteredSourceIndices = _computeFilteredIndices();
    });
  }

  static const Object _unchanged = Object();

  String _podIdForSource(int sourceRow) =>
      'pod-worker-${sourceRow.toString().padLeft(6, '0')}';

  Object _rowId(int row) => _podIdForSource(_filteredSourceIndices[row]);

  Object _rawValue(int row, int col) {
    final sourceRow = _filteredSourceIndices[row];
    switch (col) {
      case 0:
        return sourceRow;
      case 1:
        return _namespaces[sourceRow % _namespaces.length];
      case 2:
        return _podIdForSource(sourceRow);
      case 3:
        return _regions[sourceRow % _regions.length];
      case 4:
        return _statuses[sourceRow % _statuses.length];
      case 5:
        return ((sourceRow * 17) % 950) / 10.0;
      case 6:
        return 64 + ((sourceRow * 31) % 2048);
      case 7:
        return _nodes[sourceRow % _nodes.length];
      default:
        return '';
    }
  }

  String _buildStatusLine(int visibleCount) {
    final sort = _controller.sortState;
    final sortLabel = sort == null
        ? 'Unsorted'
        : 'Col #${sort.columnIndex} (${sort.direction.name})';
    final anchorLabel = _controller.anchorRowId ?? 'None';
    final segments = <String>[
      'Dataset: $visibleCount rows',
      'Selected: ${_controller.selectedCount} '
          '(IDs: ${_controller.totalSelectedIdCount})',
      'Edited: ${_controller.totalDirtyCellCount}',
      'Anchor: $anchorLabel',
      'Sort: $sortLabel',
      'Frozen: ${_freezeLeading ? 2 : 0}',
      'Actions: ${_pinActions ? 'Pinned' : 'Scrollable'}',
      'Region Col: ${_showRegionColumn ? 'Visible' : 'Hidden'}',
    ];
    if (_lastCopiedRowCount != null && _lastCopiedColumnCount != null) {
      final rowWord = _lastCopiedRowCount == 1 ? 'row' : 'rows';
      segments.add(
        'Copied: $_lastCopiedRowCount $rowWord ($_lastCopiedColumnCount cols)',
      );
    }
    if (_lastSecondaryTappedPodId != null) {
      segments.add('Right-click: $_lastSecondaryTappedPodId');
    }
    if (_lastInspectedPodId != null) {
      segments.add('Inspected: $_lastInspectedPodId');
    }
    if (_lastActivatedPodId != null) {
      segments.add('Activated: $_lastActivatedPodId');
    }
    return segments.join(' | ');
  }

  @override
  Widget build(BuildContext context) {
    final style = _darkMode
        ? const DenseStyle.dark(minColumnWidth: 48.0)
        : const DenseStyle.light(minColumnWidth: 48.0);
    final pageBg =
        _darkMode ? const Color(0xFF16171A) : const Color(0xFFF2F4F7);
    final barBg = _darkMode ? const Color(0xFF25272B) : const Color(0xFFFFFFFF);
    final fgColor =
        _darkMode ? const Color(0xFFE4E6EB) : const Color(0xFF1F2328);
    final borderColor =
        _darkMode ? const Color(0xFF383A3D) : const Color(0xFFD0D5DD);
    final visibleCount = _filteredSourceIndices.length;

    return WidgetsApp(
      title: 'DenseTable 1.5.0 Showcase',
      color: const Color(0xFF2563EB),
      debugShowCheckedModeBanner: false,
      pageRouteBuilder: <T>(RouteSettings settings, WidgetBuilder builder) {
        return PageRouteBuilder<T>(
          settings: settings,
          pageBuilder: (BuildContext context, _, __) => builder(context),
        );
      },
      home: ColoredBox(
        color: pageBg,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16.0,
                vertical: 10.0,
              ),
              decoration: BoxDecoration(
                color: barBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: Wrap(
                spacing: 6.0,
                runSpacing: 8.0,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    'DenseTable 1.5.0 Showcase',
                    style: TextStyle(
                      color: fgColor,
                      fontSize: 15.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Wrap(
                    spacing: 6.0,
                    runSpacing: 6.0,
                    children: <Widget>[
                      _ToolbarButton(
                        label: '1K Rows',
                        active: _baseRowCount == 1000,
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(baseCount: 1000),
                      ),
                      _ToolbarButton(
                        label: '10K Rows',
                        active: _baseRowCount == 10000,
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(baseCount: 10000),
                      ),
                      _ToolbarButton(
                        label: '100K Rows',
                        active: _baseRowCount == 100000,
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(baseCount: 100000),
                      ),
                      _ToolbarButton(
                        label: 'Filter: All',
                        active: _statusFilter == null,
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(statusFilter: null),
                      ),
                      _ToolbarButton(
                        label: 'Filter: Running',
                        active: _statusFilter == 'Running',
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(statusFilter: 'Running'),
                      ),
                      _ToolbarButton(
                        label: 'Filter: Pending',
                        active: _statusFilter == 'Pending',
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(statusFilter: 'Pending'),
                      ),
                      _ToolbarButton(
                        label: 'Filter: Degraded',
                        active: _statusFilter == 'Degraded',
                        darkMode: _darkMode,
                        onTap: () => _updateDataset(statusFilter: 'Degraded'),
                      ),
                      _ToolbarButton(
                        label: 'Frozen Cols',
                        active: _freezeLeading,
                        darkMode: _darkMode,
                        onTap: () =>
                            setState(() => _freezeLeading = !_freezeLeading),
                      ),
                      _ToolbarButton(
                        label: 'Pin Actions',
                        active: _pinActions,
                        darkMode: _darkMode,
                        onTap: () => setState(() => _pinActions = !_pinActions),
                      ),
                      _ToolbarButton(
                        label:
                            _showRegionColumn ? 'Hide Column' : 'Show Column',
                        active: !_showRegionColumn,
                        darkMode: _darkMode,
                        onTap: () => setState(
                          () => _showRegionColumn = !_showRegionColumn,
                        ),
                      ),
                      _ToolbarButton(
                        label: 'Clear Sort',
                        darkMode: _darkMode,
                        onTap: _controller.clearSort,
                      ),
                      _ToolbarButton(
                        label: 'Jump Bottom',
                        darkMode: _darkMode,
                        onTap: () {
                          if (visibleCount > 0) {
                            _controller.scrollToVisualRow(visibleCount - 1);
                          }
                        },
                      ),
                      _ToolbarButton(
                        label: 'Jump Top',
                        darkMode: _darkMode,
                        onTap: () => _controller.scrollToVisualRow(0),
                      ),
                      _ToolbarButton(
                        label: 'Discard Edits',
                        darkMode: _darkMode,
                        onTap: _controller.clearDirtyCells,
                      ),
                      _ToolbarButton(
                        label: _darkMode ? 'Light Theme' : 'Dark Theme',
                        darkMode: _darkMode,
                        onTap: () => setState(() => _darkMode = !_darkMode),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    AnimatedBuilder(
                      animation: _controller,
                      builder: (context, _) {
                        return Text(
                          _buildStatusLine(visibleCount),
                          style: TextStyle(
                            color: fgColor,
                            fontSize: 13.0,
                            fontWeight: FontWeight.w600,
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 10.0),
                    Expanded(
                      child: DenseTable.builder(
                        controller: _controller,
                        autofocus: true,
                        selectionMode: DenseSelectionMode.multi,
                        showCheckboxColumn: true,
                        sortCycle: DenseSortCycle.toggle,
                        showSortClearButton: true,
                        frozenColumnCount: _freezeLeading ? 2 : 0,
                        pinActionsColumn: _pinActions,
                        actionsHeader: 'Actions',
                        actionsWidth: 96.0,
                        actionsAlignment: Alignment.centerRight,
                        actionsCellPadding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                        ),
                        rowActionsBuilder: (context, rowIndex) {
                          return _RowActionButton(
                            label: 'Inspect',
                            darkMode: _darkMode,
                            onTap: () {
                              setState(
                                () => _lastInspectedPodId = _rowId(rowIndex),
                              );
                            },
                          );
                        },
                        enableCopyShortcut: true,
                        onCopy: (event) {
                          setState(() {
                            _lastCopiedRowCount = event.rowIndices.length;
                            _lastCopiedColumnCount = event.columnIndices.length;
                          });
                        },
                        selectOnSecondaryTap: true,
                        onRowSecondaryTapDown: (rowIndex, _) {
                          setState(
                            () => _lastSecondaryTappedPodId = _rowId(rowIndex),
                          );
                        },
                        style: style,
                        rowCount: visibleCount,
                        rowIdBuilder: _rowId,
                        dataIdentity: _filteredSourceIndices,
                        rawCellValue: _rawValue,
                        onRowActivated: (rowIndex) {
                          setState(
                            () => _lastActivatedPodId = _rowId(rowIndex),
                          );
                        },
                        columns: <DenseColumn>[
                          const DenseColumn(
                            title: 'ID',
                            initialWidth: 72.0,
                            alignment: Alignment.centerRight,
                            cellPadding: EdgeInsets.symmetric(horizontal: 6.0),
                          ),
                          const DenseColumn(
                            title: 'Namespace',
                            initialWidth: 130.0,
                            editable: true,
                          ),
                          const DenseColumn(
                            title: 'Workload Name',
                            initialWidth: 210.0,
                            flex: 1.0,
                            editable: true,
                          ),
                          DenseColumn(
                            title: 'Region',
                            initialWidth: 120.0,
                            visible: _showRegionColumn,
                            editable: true,
                          ),
                          const DenseColumn(
                            title: 'Status',
                            initialWidth: 110.0,
                            editable: true,
                          ),
                          DenseColumn(
                            title: 'Latency (ms)',
                            initialWidth: 120.0,
                            alignment: Alignment.centerRight,
                            editable: true,
                            validator: (_, __, ___, draft) {
                              final parsed = double.tryParse(draft);
                              if (parsed == null || parsed < 0) {
                                return 'Enter a non-negative number';
                              }
                              return null;
                            },
                          ),
                          DenseColumn(
                            title: 'Memory (MiB)',
                            initialWidth: 120.0,
                            alignment: Alignment.centerRight,
                            editable: true,
                            validator: (_, __, ___, draft) {
                              final parsed = int.tryParse(draft);
                              if (parsed == null || parsed <= 0) {
                                return 'Enter a positive integer';
                              }
                              return null;
                            },
                          ),
                          const DenseColumn(
                            title: 'Node',
                            initialWidth: 140.0,
                          ),
                        ],
                        cellBuilder: (context, row, col) {
                          final val = _rawValue(row, col);
                          if (col == 5) {
                            return Text(
                              '${(val as double).toStringAsFixed(1)} ms',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          if (col == 6) {
                            return Text(
                              '$val MiB',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          }
                          return Text(
                            val.toString(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.darkMode,
    required this.onTap,
    this.active = false,
  });

  final String label;
  final bool darkMode;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = active
        ? const Color(0xFF2563EB)
        : (darkMode ? const Color(0xFF32353B) : const Color(0xFFE4E7EC));
    final fg = active
        ? const Color(0xFFFFFFFF)
        : (darkMode ? const Color(0xFFE4E6EB) : const Color(0xFF1F2328));

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10.0, vertical: 5.0),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: const BorderRadius.all(Radius.circular(4.0)),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: fg,
              fontSize: 12.0,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _RowActionButton extends StatelessWidget {
  const _RowActionButton({
    required this.label,
    required this.darkMode,
    required this.onTap,
  });

  final String label;
  final bool darkMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final bg = darkMode ? const Color(0xFF32353B) : const Color(0xFFE4E7EC);
    final border = darkMode ? const Color(0xFF4E5155) : const Color(0xFFD0D5DD);
    final fg = darkMode ? const Color(0xFFE4E6EB) : const Color(0xFF1F2328);

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 2.0),
          decoration: BoxDecoration(
            color: bg,
            border: Border.all(color: border),
            borderRadius: const BorderRadius.all(Radius.circular(3.0)),
          ),
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: fg,
              fontSize: 11.0,
              fontWeight: FontWeight.w600,
              height: 1.2,
            ),
          ),
        ),
      ),
    );
  }
}
