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

import 'package:dense_table_example/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('DenseTable example app smoke test', (WidgetTester tester) async {
    // 1. Build our app and trigger a frame.
    await tester.pumpWidget(const MaterialApp(home: MyApp()));

    // 2. Wait for all animations and scheduled frames to complete.
    await tester.pumpAndSettle();

    // 3. Verify that the app title is displayed.
    expect(find.text('DenseTable Example'), findsOneWidget);

    // 4. Verify that the table header is present.
    expect(find.text('Process Log (1,000 rows)'), findsOneWidget);
  });
}
