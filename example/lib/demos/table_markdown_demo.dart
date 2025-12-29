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
| Authentication<br>refactor | Taylor | 🟢 Done       |        5 |
| Crash reporting setup     | Casey  | 🟡 In progress |        3 |
| Offline sync prototype    | Drew   | 🔴 Blocked    |        8 |

Totals and targets

| Metric                   | Current | Target |
| ------------------------ | ------: | -----: |
| Velocity (points)<br>14d |      36 |     40 |
| Bugs outstanding         |      12 |      5 |
| Coverage                 |     86% |    90% |

Line breaks also work outside of tables:<br>Use `<br>` anywhere inline for a forced newline.

Inline HTML tags also render: H<sub>2</sub>O, E = mc<sup>2</sup>, and <u>underlined text</u>.

Action items

| Owner  | Follow-up                                                                 |
| :----- | :------------------------------------------------------------------------ |
| Taylor | <ul><li>Finalize release notes</li><li>Prep sprint review</li></ul>        |
| Casey  | <ul><li>Draft outage postmortem</li><li>Update monitoring dashboard</li></ul> |
| Drew   | <ol><li>Sync with infra team</li><li>Schedule design review</li></ol>      |


|   fewsf |  |
| --- | --- |
|   **Class**  Narcotic analgesic   |   **EMS Indications**  <br><ul><li><b>Consult TP</b> to discuss use in RSIP</li><li>Analgesia prior to intubation in conjunction with midazolam</li></ul> |
|   **Dosage**  <br>  **Repeat**   |   2 mcg/kg rapid IV/IO ideal body weight  <br>  Do not repeat dose   |
|   **EMS Contraindications**   | <br><ul><li>Hypersensitivity</li><li>Monoamine oxidase inhibitor therapy within last 14 days</li><li>Systolic BP less than 100 mmHg</li></ul> |
|   **Notes**   | <br><ul><li>Use with caution in myasthenia gravis</li><li>Even when used appropriately, can induce post airway intervention hypotension</li></ul> |


| Dose in mcg/kg/min | 0.5 kg | 1 kg | 1.5 kg | 2 kg | 2.5 kg | 3 kg | 3.5 kg | 4 kg | 4.5 kg | 5 kg | 5.5 kg | 6 kg | 6.5 kg | 7 kg | 7.5 kg | 8 kg | 8.5 kg | 9 kg | 9.5 kg | 10 kg |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **0.05** | 0.1 | 0.2 | 0.3 | 0.4 | 0.5 | 0.6 | 0.7 | 0.8 | 0.8 | 0.9 | 1.0 | 1.1 | 1.2 | 1.3 | 1.4 | 2 | 1.6 | 1.7 | 1.8 | 1.9 |
| **0.1** | 0.2 | 0.4 | 0.6 | 0.8 | 0.9 | 1.1 | 1.3 | 1.5 | 1.7 | 1.9 | 2.1 | 2.3 | 2.4 | 2.6 | 2.8 | 3 | 3.2 | 3.4 | 3.6 | 3.8 |
| **0.15** | 0.3 | 0.6 | 0.8 | 1.1 | 1.4 | 1.7 | 2 | 2.3 | 2.5 | 2.8 | 3.1 | 3.4 | 3.7 | 3.9 | 4.2 | 4.5 | 4.8 | 5.1 | 5.3 | 5.6 |
| **0.2** | 0.4 | 0.8 | 1.1 | 1.5 | 1.9 | 2.3 | 2.6 | 3 | 3.4 | 3.8 | 4.1 | 4.5 | 4.9 | 5.3 | 5.6 | 6.0 | 6.4 | 6.8 | 7.1 | 7.5 |
| **0.25** | 0.5 | 0.9 | 1.4 | 1.9 | 2.3 | 2.8 | 3.3 | 3.8 | 4.2 | 4.7 | 5.2 | 5.6 | 6.1 | 6.6 | 7 | 7.5 | 8 | 8.4 | 8.9 | 9.4 |
| **0.3** | 0.6 | 1.1 | 1.7 | 2.3 | 2.8 | 3.4 | 3.9 | 4.5 | 5.1 | 5.6 | 6.2 | 6.8 | 7.3 | 7.9 | 8.4 | 9 | 9.6 | 10.1 | 10.7 | 11.3 |
| **0.35** | 0.7 | 1.3 | 2 | 2.6 | 3.3 | 3.9 | 4.6 | 5.3 | 5.9 | 6.6 | 7.2 | 7.9 | 8.5 | 9.2 | 9.8 | 10.5 | 11.2 | 11.8 | 12.5 | 13.1 |
| **0.4** | 0.8 | 1.5 | 2.3 | 3 | 3.8 | 4.5 | 5.3 | 6 | 6.8 | 7.5 | 8.3 | 9 | 9.8 | 10.5 | 11.3 | 12 | 12.8 | 13.5 | 14.3 | 15 |
| **0.45** | 0.8 | 1.7 | 2.5 | 3.4 | 4.2 | 5.1 | 5.9 | 6.8 | 7.6 | 8.4 | 9.3 | 10.1 | 11 | 11.8 | 12.7 | 13.5 | 14.3 | 15.2 | 16 | 16.9 |
| **0.5** | 0.9 | 1.9 | 2.8 | 3.8 | 4.7 | 5.6 | 6.6 | 7.5 | 8.4 | 9.4 | 10.3 | 11.3 | 12.2 | 13.1 | 14.1 | 15 | 15.9 | 16.9 | 17.8 | 18.8 |
| **0.55** | 1 | 2.1 | 3.1 | 4.1 | 5.2 | 6.2 | 7.2 | 8.3 | 9.3 | 10.3 | 11.3 | 12.4 | 13.4 | 14.4 | 15.5 | 16.5 | 17.5 | 18.6 | 19.6 | 20.6 |
| **0.6** | 1.1 | 2.3 | 3.4 | 4.5 | 5.6 | 6.8 | 7.9 | 9 | 10.1 | 11.3 | 12.4 | 13.5 | 14.6 | 15.8 | 16.9 | 18 | 19.1 | 20.3 | 21.4 | 22.5 |
| **0.65** | 1.2 | 2.4 | 3.7 | 4.9 | 6.1 | 7.3 | 8.5 | 9.8 | 11 | 12.2 | 13.4 | 14.6 | 15.8 | 17.1 | 18.3 | 19.5 | 20.7 | 21.9 | 23.2 | 24.4 |
| **0.7** | 1.3 | 2.6 | 3.9 | 5.3 | 6.6 | 7.9 | 9.2 | 10.5 | 11.8 | 13.1 | 14.4 | 15.8 | 17.1 | 18.4 | 19.7 | 21 | 22.3 | 23.6 | 24.9 | 26.3 |
| **0.75** | 1.4 | 2.8 | 4.2 | 5.6 | 7 | 8.4 | 9.8 | 11.3 | 12.7 | 14.1 | 15.5 | 16.9 | 18.3 | 19.7 | 21.1 | 22.5 | 23.9 | 25.3 | 26.7 | 28.1 |
| **0.8** | 1.5 | 3 | 4.5 | 6 | 7.5 | 9 | 10.5 | 12 | 13.5 | 15 | 16.5 | 18 | 19.5 | 21 | 22.5 | 24 | 25.5 | 27 | 28.5 | 30 |
| **0.85** | 1.6 | 3.2 | 4.8 | 6.4 | 8 | 9.6 | 11.2 | 12.8 | 14.3 | 15.9 | 17.5 | 19.1 | 20.7 | 22.3 | 23.9 | 25.5 | 27.1 | 28.7 | 30.3 | 31.9 |
| **0.9** | 1.7 | 3.4 | 5.1 | 6.8 | 8.4 | 10.1 | 11.8 | 13.5 | 15.2 | 16.9 | 18.6 | 20.3 | 21.9 | 23.6 | 25.3 | 27 | 28.7 | 30.4 | 32.1 | 33.8 |
| **0.95** | 1.8 | 3.6 | 5.3 | 7.1 | 8.9 | 10.7 | 12.5 | 14.3 | 16 | 17.8 | 19.6 | 21.4 | 23.2 | 24.9 | 26.7 | 28.5 | 30.3 | 32.1 | 33.8 | 35.6 |
| **1** | 1.9 | 3.8 | 5.6 | 7.5 | 9.4 | 11.3 | 13.1 | 15 | 16.9 | 18.8 | 20.6 | 22.5 | 24.4 | 26.3 | 28.1 | 30 | 31.9 | 33.8 | 35.6 | 37.5 |

''';

const String _notes = '''
# Table Markdown Demo
---

## Overview

This demo highlights GitHub-flavored Markdown table support in flutter_markdown_plus. The table
syntax is enabled by default when using the GitHub extension set, which is also the package
default. The example also shows how raw HTML `<br>` tags render as hard line breaks inside
tables and regular paragraphs.

## Tips

- Use a colon on the left, right, or both sides of the separator row to set column alignment.
- Styling such as borders and cell padding can be customized with a `MarkdownStyleSheet`.
- A blank line before and after a table keeps the document easy to read.
- Raw HTML lists (`<ul>`/`<ol>`) nested in table cells now render with proper bullets.
- Inline HTML tags like `<sub>`, `<sup>`, and `<u>` render as subscript, superscript, and underline.
- Tap any table to open an expanded view with sticky headers, a pinned first column, and pinch-to-zoom support.
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
