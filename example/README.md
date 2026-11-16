# dense_table_example

Interactive sample application demonstrating `dense_table` `1.3.1` across Desktop, Web (Wasm), and Mobile:

- **`O(1)` Virtualization at 100,000 Rows**: Switch instantaneously between `1,000`, `10,000`, and `100,000` rows or jump straight to the bottom row without frame drops.
- **Spreadsheet-Style Inline Cell Editing & Dirty Staging**: Double-click or press `F2` / `Enter` to edit cells inline, navigate across editable columns with `Tab` / `Shift+Tab`, validate input, and inspect staged `dirtyCells`.
- **Virtualized Vertical Cell Merging (`DenseRowSpan`)**: Render multi-row merged cells in `O(1)` viewport time while keeping merged labels sticky when scrolled partially off-screen.
- **Resizable & Sortable Columns**: Drag column dividers (or double-click to reset width) and click headers to sort 100,000 rows ascending/descending.
- **Multi-Row Selection & Keyboard Navigation**: Click, `Ctrl`/`Cmd`+Click, `Shift`+Click range selection, `Ctrl`/`Cmd`+`A`, checkboxes, and `ArrowUp`/`Down`, `PageUp`/`Down`, `Home`/`End`, `Enter` keyboard shortcuts.
- **Dark & Light IDE Themes**: Toggle between `DenseStyle.dark()` and `DenseStyle.light()`.

## Run

```bash
cd example
flutter pub get
flutter run
```
