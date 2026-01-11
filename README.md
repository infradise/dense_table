[![pub package](https://img.shields.io/pub/v/dense_table.svg)](https://pub.dev/packages/dense_table)

# dense_table ⚡

A high-density data table widget for Flutter, designed for professional desktop and web applications.

It prioritizes information density, rendering performance, and keyboard-centric control, making it ideal for complex data tools.

![Screenshot](https://download.keyscope.dev/dense_table/screenshot/dense_table.png)  

## Features

- **High Density Layout**: Minimized padding and spacing to display more data on the screen.
- **Performance First**: Built on `ListView.builder` with fixed item extents, ensuring smooth scrolling even with 100,000+ rows.
- **Pixel-Perfect Grid**: Sharp, consistent borders without the blurriness of standard dividers.
- **Professional Look**: Clean, pixel-perfect grid lines with a default dark theme suitable for enterprise tools and long-term usage.
- **Customizable**: Full control over row height, colors, fonts, and borders via `DenseStyle`.

## Installation

Add this to your package's `pubspec.yaml` file:

```yaml
dependencies:
  dense_table: ^0.1.0
```

## Usage

```dart
import 'package:dense_table/dense_table.dart';

DenseTable(
  headers: ['ID', 'Name', 'Status'],
  columnWidths: {
    0: 50.0,
    1: 200.0,
    2: 100.0,
  },
  data: [
    [1, 'File_A.dart', 'Modified'],
    [2, 'File_B.dart', 'Added'],
  ],
  // Optional: Customize the look
  style: DenseStyle(
    rowHeight: 24.0, // Compact height
    backgroundColor: Color(0xFF1E1F22),
    // cellTextStyle: TextStyle(fontSize: 13),
  ),
)
```

## Comparison

| Feature | Standard DataTable | dense_table |
|---------|-------------------|-------------|
| **Density** | Low (Touch-optimized) | **High (Mouse-optimized)** |
| **Performance** | Good for < 100 rows | **Excellent for 100k+ rows** |
| **Look** | Material Design | **Professional Tool Style** |
| **Scroll** | Single Widget | **Virtualization** |

## Roadmap

- [x] v0.1.0: Initial release with virtualization and basic styling.
- [ ] v0.2.0: Resizable columns.
- [ ] v0.3.0: Row selection (Single/Multi) and keyboard navigation.
- [ ] v0.4.0: Sortable columns.
