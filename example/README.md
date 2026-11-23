# dense_table_example

Interactive sample application demonstrating `dense_table` `1.5.0` across Desktop, Web (Wasm), and Mobile:

- **`O(1)` Virtualization at 100,000 Rows**: Switch instantaneously between `1,000`, `10,000`, and `100,000` rows, filter workloads by status, or jump directly to the top or bottom row without frame drops.
- **Frozen Leading Columns (`Frozen Cols`)**: Toggle `frozenColumnCount` between `2` and `0` to keep the checkbox column alongside leading `ID` and `Namespace` columns pinned during horizontal scrolling.
- **Pinned Trailing Actions Column (`Pin Actions`)**: Toggle `pinActionsColumn` on a trailing `Actions` column configured with `actionsWidth`, `actionsAlignment`, `actionsCellPadding`, and a compact `Inspect` button.
- **Non-Shifting Column Visibility & Per-Column Padding (`Hide Column` / `Show Column`)**: Toggle `DenseColumn.visible` on the `Region` column live without shifting logical column indices, alongside compact per-column `DenseColumn.cellPadding` on `ID`.
- **Spreadsheet-Style Inline Cell Editing & Dirty Staging**: Double-click or press `F2` / `Enter` to edit cells inline, navigate across editable columns with `Tab` / `Shift+Tab`, validate numeric input, and inspect or discard staged `dirtyCells`.
- **Clipboard TSV Copy (`Cmd`/`Ctrl`+`C`)**: Copy selected rows (or the focused row) as tab-separated values via `enableCopyShortcut` and inspect the copied row/column summary reported by `onCopy` in the status bar.
- **Right-Click Row Selection**: Secondary-tap any row to auto-select it via `selectOnSecondaryTap` and report the target record through `onRowSecondaryTapDown` in the status bar.
- **Resizable & Sortable Columns with Clear Controls**: Drag column dividers (or double-click to reset width), sort 100,000 rows using `DenseSortCycle.toggle`, and restore the original order using either the header `x` button (`showSortClearButton`) or the toolbar `Clear Sort` button (`controller.clearSort()`).
- **Multi-Row Selection & Keyboard Navigation**: Click, `Ctrl`/`Cmd`+Click, `Shift`+Click range selection, `Ctrl`/`Cmd`+`A`, checkboxes, and `ArrowUp`/`Down`, `PageUp`/`Down`, `Home`/`End`, `Enter` keyboard shortcuts.
- **Dark & Light IDE Themes**: Toggle between `DenseStyle.dark()` and `DenseStyle.light()`.

## Run

```bash
cd example
flutter pub get
flutter run
```
