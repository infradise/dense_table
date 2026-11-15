# dense_table

[![Pub Version](https://img.shields.io/pub/v/dense_table)](https://pub.dev/packages/dense_table)
[![Dependencies](https://img.shields.io/badge/dependencies-zero-brightgreen)](https://pub.dev/packages/dense_table)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](https://github.com/infradise/dense_table/blob/main/LICENSE)

Zero-dependency, high-density virtualized data table widget for Flutter across **Android**, **iOS**, **Linux**, **macOS**, **Windows**, and **Web / WebAssembly**.

Engineered for desktop IDEs, Kubernetes & cloud consoles, database clients, log viewers, and analytics dashboards that require crisp pixel-level density and smooth **`O(1)` rendering across 100,000+ rows**.

<div align="center">
  <img src="https://download.keyscope.dev/dense_table/screenshot/dense_table.png" width="680" alt="dense_table preview" />
</div>

---

## Why `dense_table`?

Flutter's built-in `DataTable` instantiates every cell eagerly in a single `RenderTable` pass and uses wide touch-oriented spacing—causing severe frame drops past a few hundred rows and out-of-memory freezes at `10,000–100,000` rows. External third-party data grid packages frequently pull in large transitive dependency trees that conflict during Flutter SDK upgrades.

`dense_table` solves both problems with **zero external hosted dependencies** (`dependencies` contains **only** the Flutter SDK):

- **True `O(1)` Fixed-Extent Virtualization (`100,000+` Rows)**: Built on fixed-extent viewport math (`rowHeight`) and lazy `DenseTable.builder` cell construction so only the ~25–50 visible rows are mounted, and scrollbar thumb drags to row `99,999` resolve in `O(1)` arithmetic.
- **Stable Row Identity (`rowIdBuilder`)**: Anchors multi-row selection, keyboard focus, and `Shift`-range extension to stable domain record IDs (e.g., Pod UIDs, container IDs, primary keys) across built-in sorting, external search filtering, and live streaming insertions/deletions.
- **Single-Pass `CustomPaint` Crisp Grid**: Paints row backgrounds (zebra striping, hover, selection, focus ring) and `1px` vertical/horizontal grid lines in a single lightweight `CustomPainter` per visible row instead of allocating nested `BoxDecoration` trees per cell.
- **Interactive Resizable Columns**: Drag any column header divider to resize within `minColumnWidth` / `maxColumnWidth`, or double-click a divider to reset the column to its initial width.
- **Instant Sortable Columns**: Click headers to cycle `ascending -> descending -> unsorted`. Built-in natural sorting handles numbers, `DateTime`, `Duration`, booleans, and numeric strings (`'9.5 ms' < '12.0 ms' < '100.0 ms'`) using a cached Schwartzian index permutation that never re-sorts during scroll, hover, or resize frames.
- **Desktop-Grade Multi-Row Selection & Keyboard Navigation**: Supports `none`, `single`, and `multi` selection (`Click`, `Ctrl`/`Cmd`+`Click`, `Shift`+`Click` contiguous range, `Ctrl`/`Cmd`+`A`, optional checkbox column) plus full keyboard navigation (`ArrowUp`/`Down`, `Shift`+`ArrowUp`/`Down`, `PageUp`/`Down`, `Home`/`End`, `Space`, `Enter`, `Escape`) with table-level off-screen focus retention, `0ms` single-click response, and double-click activation.
- **Bulletproof Layout Constraints**: Automatically adapts inside bounded (`Expanded`, `SizedBox`, split panes) and unbounded (`Column`, `SingleChildScrollView`, `Dialog`) parents—and even renders cleanly without a `MaterialApp` or `Scaffold` ancestor.

---

## Comparison

| Capability | Flutter `DataTable` | `dense_table` `1.1.0` |
| :--- | :--- | :--- |
| **External Dependencies** | Flutter SDK | **Zero (Flutter SDK only)** |
| **100,000+ Row Virtualization** | Eager `O(N)` (freezes / OOM) | **`O(1)` fixed-extent + `.builder`** |
| **Stable Row ID Anchoring** | Manual index bookkeeping | **`rowIdBuilder` across sort, filter & streams** |
| **Sticky Header + 2D Scroll Sync** | Scrolls off-screen by default | **Built-in synced 2D scrollbars** |
| **Interactive Column Resizing** | No | **Drag divider + double-click reset** |
| **Built-in Natural Sorting** | Manual external wiring | **Cached `O(N log N)` index sort** |
| **Multi-Select (`Shift` / `Cmd` / `Ctrl`)** | Basic row callback only | **Single, Multi, Range & `Cmd/Ctrl+A`** |
| **Keyboard Navigation** | Minimal | **Arrows, PageUp/Down, Home/End, Enter** |
| **Unbounded Parent (`Column`) Safety** | Manual scroll wrappers required | **Automatic constraint resolution** |

---

## Installation

```yaml
dependencies:
  dense_table: ^1.1.0
```

---

## Quick Start

### 1. Matrix Data (`DenseTable`)

```dart
import 'package:dense_table/dense_table.dart';
import 'package:flutter/widgets.dart';

Widget buildProcessTable() {
  return DenseTable(
    selectionMode: DenseSelectionMode.multi,
    showCheckboxColumn: true,
    headers: const ['ID', 'File', 'Latency', 'Status'],
    rowIdBuilder: (rowIndex) => rowIndex + 1,
    columnWidths: const {
      0: 64.0,
      1: 220.0,
      2: 110.0,
      3: 100.0,
    },
    data: const [
      [1, 'engine_worker.dart', '9.4 ms', 'Running'],
      [2, 'cluster_sync.dart', '14.2 ms', 'Running'],
      [3, 'snapshot_gc.dart', '102.0 ms', 'Idle'],
    ],
    style: const DenseStyle.dark(
      rowHeight: 24.0,
      minColumnWidth: 40.0,
    ),
  );
}
```

### 2. Lazy 100,000+ Row Virtualization & Stable Row IDs (`DenseTable.builder`)

Use `DenseTable.builder` with `rowIdBuilder` and `DenseTableController` to render 100,000+ domain objects—keeping selection, focus, and `Shift`-range anchors bound to exact records across sorting, filtering, and live stream updates:

```dart
import 'package:dense_table/dense_table.dart';
import 'package:flutter/widgets.dart';

class LargeClusterGrid extends StatefulWidget {
  const LargeClusterGrid({super.key});

  @override
  State<LargeClusterGrid> createState() => _LargeClusterGridState();
}

class _LargeClusterGridState extends State<LargeClusterGrid> {
  final DenseTableController _controller = DenseTableController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _podUid(int row) => 'pod-uid-${row.toString().padLeft(6, '0')}';

  Object _rawCell(int row, int col) => switch (col) {
        0 => row,
        1 => _podUid(row),
        2 => (row * 13) % 500,
        _ => 'Running',
      };

  @override
  Widget build(BuildContext context) {
    return DenseTable.builder(
      controller: _controller,
      autofocus: true,
      selectionMode: DenseSelectionMode.multi,
      showCheckboxColumn: true,
      rowCount: 100000,
      rowIdBuilder: _podUid,
      rawCellValue: _rawCell,
      columns: const [
        DenseColumn(
          title: 'ID',
          initialWidth: 80.0,
          alignment: Alignment.centerRight,
        ),
        DenseColumn(
          title: 'Pod UID',
          initialWidth: 240.0,
          flex: 1.0,
        ),
        DenseColumn(
          title: 'Memory (MiB)',
          initialWidth: 120.0,
          alignment: Alignment.centerRight,
        ),
        DenseColumn(
          title: 'Phase',
          initialWidth: 110.0,
        ),
      ],
      cellBuilder: (context, rowIndex, columnIndex) {
        final value = _rawCell(rowIndex, columnIndex);
        return Text(
          columnIndex == 2 ? '$value MiB' : '$value',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        );
      },
      onSelectedIdsChanged: (selectedIds) {
        debugPrint('Selected Pod UIDs: ${selectedIds.length}');
      },
      onRowActivated: (rowIndex) {
        debugPrint('Activated Pod ${_podUid(rowIndex)}');
      },
    );
  }
}
```

---

## Keyboard & Pointer Shortcuts

| Input | Behavior |
| :--- | :--- |
| **Click Row** | Selects row immediately (`0ms` delay) and anchors `rowId` / index |
| **Double-Click Row** | Fires `onRowDoubleTap` and `onRowActivated` |
| **Right-Click Row** | Fires `onRowSecondaryTapDown` with pointer coordinates |
| **`Ctrl` / `Cmd` + Click** | Toggles individual row selection in `multi` (or `single`) mode |
| **`Shift` + Click** | Extends contiguous visual range from the anchored record |
| **`Ctrl` / `Cmd` + `A`** | Selects all visible rows in `multi` mode |
| **`ArrowUp` / `ArrowDown`** | Moves row focus (hold `Shift` to extend multi-row range) |
| **`PageUp` / `PageDown`** | Jumps one viewport page up or down |
| **`Home` / `End`** | Jumps immediately to first (`0`) or last (`N - 1`) visual row |
| **`Space` / `Enter` / `Esc`** | Toggles focused row / activates row / clears selection |

---

## Themes (`DenseStyle`)

`dense_table` includes two built-in presets—`DenseStyle.dark()` (default) and `DenseStyle.light()`—and every dimension, color, text style, grid toggle, and scrollbar property can be customized via `DenseStyle(...)` or `style.copyWith(...)`.

---

## License

Apache License 2.0 — Copyright 2026 Infradise Inc. See [LICENSE](LICENSE) and [NOTICE](NOTICE).
