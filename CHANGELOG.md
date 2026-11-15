## 1.1.0

* **Stable Row Identity (`rowIdBuilder`)**: Added `rowIdBuilder` (`DenseRowIdGetter`), `dataIdentity`, and `onSelectedIdsChanged` to `DenseTable` and `DenseTable.builder` so selection, keyboard focus, and the `Shift`-range anchor track stable domain record IDs across external search filtering, pagination, and live streaming insertions/deletions.
* **Controller Stable ID APIs**: Extended `DenseTableController` with `initialSelectedRowIds`, `retainHiddenSelectionIds` (retains hidden selections across filter queries while scoping header `Select All` toggle to visible rows via `toggleSelectAllVisible`), `selectedRowIds`, `totalSelectedIdCount`, `focusedRowId`, `anchorRowId`, `isRowIdSelected`, `indexOfRowId`, `rowIdAt`, `selectRowId`, `toggleRowId`, `setSelectedRowIds`, `setFocusedRowId`, and `scrollToRowId`.
* **Double-Tap Record Identity**: Bound `300ms` double-click detection to stable row identity when `rowIdBuilder` is configured so live row insertions between clicks never misfire on an adjacent record.

## 1.0.0

* **Zero-Dependency Architecture**: Removed all external runtime and development package dependencies (`dependencies` uses only the Flutter SDK; Wasm-ready across Android, iOS, Linux, macOS, Windows, and Web).
* **True `100,000+` Row Virtualization & `DenseTable.builder`**: Added lazy cell builder constructor (`DenseTable.builder`), `DenseColumn` definitions, `DenseTableController`, and single-pass `CustomPainter` row/header grid rendering.
* **Adaptive Layout Constraint Resolution**: Fixed unbounded vertical (`Column` / `SingleChildScrollView` / `Dialog`) and narrow horizontal split-pane layout issues without relying on window `MediaQuery` dimensions or requiring a `Material` ancestor.
* **Resizable Columns & 2D Scroll Sync**: Added interactive column drag-resizing (`minColumnWidth` / `maxColumnWidth`), double-click width reset, and bidirectional horizontal scroll synchronization between sticky headers and the virtualized body.
* **Sortable Columns**: Added clickable column sorting (`ascending -> descending -> unsorted`) with natural numeric/string comparison (`compareDenseValues`), custom comparators, and cached index permutation.
* **Row Selection & Keyboard Navigation**: Added `DenseSelectionMode` (`none`, `single`, `multi`), optional compact tristate checkbox column, `Ctrl`/`Cmd`+Click, `Shift`+Click range selection, `Ctrl`/`Cmd`+`A`, instant `0ms` single-click + `300ms` double-click detection, and `ArrowUp`/`Down`, `PageUp`/`Down`, `Home`/`End`, `Space`, `Enter`, `Escape` keyboard navigation.
* **Built-in Dark & Light Presets**: Added `DenseStyle.dark()`, `DenseStyle.light()`, and `DenseStyle.copyWith()`.

## 0.1.0

* Initial release with fixed-extent `ListView.builder` virtualization and dark IDE `DenseStyle` styling.
