// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

import '../shared/markdown_demo_widget.dart';
import '../shared/markdown_extensions.dart';

// ignore_for_file: public_member_api_docs

const String _data = '''
# Table Layout Demo
---
Tables make it easy to compare related values. Alignment markers keep columns readable.

| Backlog Item              | Owner  | Status        | Estimate |
| :------------------------ | :----- | :-----------: | -------: |
| Authentication<br> refactor   | Taylor | 🟢 Done       |        5 |
| Crash reporting setup     | Casey  | 🟡 In progress |        3 |
| Offline sync prototype    | Drew   | 🔴 Blocked    |        8 |

Totals and targets

| Metric             | Current | Target |
| ------------------ | ------: | -----: |
| Velocity (points)  |      36 |     40 |
| Bugs outstanding   |      12 |      5 |
| Coverage           |     86% |    90% |
''';

const String _notes = '''
# Table Markdown Demo
---

## Overview

This demo highlights GitHub-flavored Markdown table support in flutter_markdown_plus. The table
syntax is enabled by default when using the GitHub extension set, which is also the package
default.

## Tips

- Use a colon on the left, right, or both sides of the separator row to set column alignment.
- Styling such as borders and cell padding can be customized with a `MarkdownStyleSheet`.
- A blank line before and after a table keeps the document easy to read.
''';

class TableMarkdownDemo extends StatelessWidget implements MarkdownDemoWidget {
  const TableMarkdownDemo({super.key});

  static const String _title = 'Table Markdown Demo';

  @override
  String get title => _title;

  @override
  String get description =>
      'Demonstrates Markdown tables with column alignment and custom styling.';

  @override
  Future<String> get data => Future<String>.value(_data);

  @override
  Future<String> get notes => Future<String>.value(_notes);

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final TableBorder border = TableBorder.symmetric(
      inside: BorderSide(color: theme.colorScheme.outlineVariant, width: 0.5),
      outside: BorderSide(color: theme.colorScheme.outline),
    );

    return Markdown(
      data: _data,
      extensionSet: MarkdownExtensionSet.githubFlavored.value,
      shrinkWrap: true,
      styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
        tableBorder: border,
        tableCellsPadding:
            const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tableHead: theme.textTheme.titleSmall,
      ),
    );
  }
}
