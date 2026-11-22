## 1.4.0

* **Sort Clear Button for the 2-State Cycle (`DenseTable.showSortClearButton`)**: Added an opt-in `x` button on the actively sorted column header that clears sorting and returns the table to its original row order. This lets `DenseSortCycle.toggle` (strict `ascending <-> descending`, never unsorted) keep its predictable 2-state header clicks while still offering a way back to the source order—for example when the original order carries meaning such as a commit graph, a stream order, or server-side ranking. Painted with a zero-dependency `CustomPainter`, with a `16 x 16` hit area, a click cursor, and an accessible label (`clearSortSemanticLabel`, default `Clear sort`). Not shown for columns that use a custom `DenseColumn.headerBuilder`.
* **`DenseTableController.clearSort()`**: Added a discoverable one-call equivalent of `setSort(null)` for custom headers, toolbars, and keyboard shortcuts. `DenseTable.onSortChanged` receives `null` when sorting is cleared by either path.
* **Docs**: Documented on `DenseSortCycle.toggle` how to restore the unsorted order, refreshed the README comparison table and installation snippet (they still referenced `1.3.0`), and updated the example app to demonstrate `sortCycle: DenseSortCycle.toggle` with `showSortClearButton: true`.

## 1.3.1

* **Dynamic Column Schema Shrink Reconciliation (`clampToColumnCount`)**: Automatically clamps or clears `editingCell`, `focusedColumn`, `sortState`, and `dirtyCells` when a table's `columns` list shrinks dynamically (such as executing a new SQL/NoSQL query with fewer columns while an inline editor is open).
* **Formatted Baseline Revert Alignment (`DenseCellChange.baselineText`)**: Aligned `recordCellChange` baseline revert detection with `editValueGetter` when paired alongside a typed `rawCellValue` (such as numeric sort keys with formatted unit strings), preserving typed `previousValue` while cleanly clearing dirty state when edited back to the initial editable text.
* **Controller Unmount Hygiene**: Cleared stale `editingCell` / `editingError` session state in `detachTableDelegates()` and `cancelEditing()` when an external `DenseTableController` outlives an unmounted `DenseTable`.

## 1.3.0

* **Spreadsheet-Style Inline Cell Editing (`DenseColumn.editable`)**: Added zero-dependency inline cell editing built directly on `flutter/widgets.dart` `EditableText`—supporting `DenseEditTrigger` (`doubleTap`, `f2OrEnter`, `singleTap`), per-cell `canEditCell` guards, `editValueGetter`, `DenseColumn.validator`, custom `DenseColumn.editorBuilder` (`DenseCellEditContext`), `onCellEditCommitted`, and `commitOnTapOutside`.
* **2D Cell Navigation & Off-Screen Edit Retention**: Added `F2` / `Enter` edit activation, `Tab` / `Shift+Tab` cycling across editable columns (with row wrapping and automatic horizontal + vertical viewport scrolling), `Enter` commit-and-advance-down, `Escape` cancel with table-level focus retention, `ArrowLeft` / `ArrowRight` column focus navigation, and viewport-overlay editor mounting so active draft edits survive scrolling across 100,000+ virtualized rows.
* **Dirty Cell Staging & Stable `rowId` Reconciliation (`DenseTableController`)**: Added `dirtyCells`, `allDirtyChanges`, `hasDirtyCells`, `dirtyCellCount`, `totalDirtyCellCount`, `isCellDirty`, `dirtyChangeAt`, `dirtyTextAt`, `recordCellChange` (with automatic baseline revert detection), `clearDirtyCell`, `clearDirtyCells`, `focusedColumn`, `editingCell`, `editingError`, `startEditing`, `commitEditing`, and `cancelEditing`—preserving staged cell edits across sorting and external filtering when `rowIdBuilder` is configured.
* **Editable Grid Visual Tokens (`DenseStyle`)**: Added `focusedCellBorderColor`, `editingCellBackgroundColor`, `editingCellBorderColor`, `editingErrorBorderColor`, `editingCursorColor`, `editingSelectionColor`, `dirtyCellIndicatorColor`, and `dirtyCellIndicatorSize` (single-pass corner dirty marker and focused cell outline in `CustomPainter`).

## 1.2.0

* **Virtualized Vertical Cell Merging (`rowSpanBuilder` & `DenseRowSpan`)**: Added `rowSpanBuilder` (`DenseRowSpanResolver`) and `DenseRowSpan` (`startRow`, `rowSpan`, `backgroundColor`, `stickyViewportAlignment`) to `DenseTable` and `DenseTable.builder`, rendering vertically merged cells in `O(1)` viewport time across 100,000+ rows while keeping labels visible when `startRow` scrolls above the viewport and preserving row click/hover pass-through.
* **Header & Sort Cycle Customization**: Added `DenseSortCycle` (`tristate` vs 2-state `toggle`), `DenseColumn.initialSortDirection`, `DenseColumn.headerKey`, `DenseColumn.headerBuilder`, and `DenseTable.sortIconBuilder`.
* **Header Sort Indicator Styling (`DenseStyle`)**: Added `activeHeaderTextStyle`, `showUnsortedSortIcon`, and `sortIconInline` (with zero-dependency dual-chevron unsorted indicator painting) for compact inline sort headers.

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
