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
import 'package:dense_table/dense_table.dart';

void main() {
  runApp(const MaterialApp(home: MyApp()));
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 1. Generate dummy data for demonstration (1,000 rows)
    final data = List.generate(
        1000,
        (index) => [
              index,
              'Event #$index',
              'ActionType.${index % 2 == 0 ? 'CLICK' : 'HOVER'}',
              '${(index * 1.5).toStringAsFixed(1)} ms',
              index % 3 == 0 ? 'ERROR' : 'OK',
            ]);

    return Scaffold(
      backgroundColor: const Color(0xFF1E1F22), // Professional dark background
      appBar: AppBar(
        title: const Text('DenseTable Example'),
        backgroundColor: const Color(0xFF3C3F41),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Process Log (1,000 rows)',
              style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                  fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),
            Expanded(
              // 2. Usage of DenseTable
              child: DenseTable(
                headers: const [
                  'ID',
                  'Event Name',
                  'Type',
                  'Duration',
                  'Status'
                ],
                columnWidths: const {
                  0: 60.0, // ID
                  1: 200.0, // Event Name
                  2: 150.0, // Type
                  3: 100.0, // Duration
                  4: 80.0, // Status
                },
                data: data,
                // Optional: Customize style here.
                // Default is a professional dark theme.
                style: const DenseStyle(
                  rowHeight: 24.0,
                  cellTextStyle:
                      TextStyle(fontSize: 13, color: Color(0xFFBCBEC4)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
