// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_markdown_plus/src/interactive_table.dart';
import 'package:flutter_markdown_plus/src/sticky_table.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:leak_tracker_flutter_testing/leak_tracker_flutter_testing.dart';
import 'package:markdown/markdown.dart' as md;

import 'utils.dart';

void main() => defineTests();

void defineTests() {
  group('Table', () {
    testWidgets(
      'should show properly',
      (WidgetTester tester) async {
        const String data = '|Header 1|Header 2|\n|-----|-----|\n|Col 1|Col 2|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<Widget> widgets = tester.allWidgets;
        expectTextStrings(
            widgets, <String>['Header 1', 'Header 2', 'Col 1', 'Col 2']);
      },
    );

    testWidgets(
      'work without the outer pipes',
      (WidgetTester tester) async {
        const String data = 'Header 1|Header 2\n-----|-----\nCol 1|Col 2';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<Widget> widgets = tester.allWidgets;
        expectTextStrings(
            widgets, <String>['Header 1', 'Header 2', 'Col 1', 'Col 2']);
      },
    );

    testWidgets(
      'render HTML line breaks inside cells',
      (WidgetTester tester) async {
        const String data = '|Header|\n|-----|\n|Line 1<br>Line 2|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<RichText> cells =
            tester.widgetList<RichText>(find.byType(RichText));
        expect(
          cells.map((RichText text) => text.text.toPlainText()),
          contains('Line 1\nLine 2'),
        );
      },
    );

    testWidgets(
      'render HTML unordered list inside cells',
      (WidgetTester tester) async {
        const String data =
            '|Header|\n|-----|\n|<ul><li>First</li><li>Second</li></ul>|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });

        final Iterable<RichText> cells =
            tester.widgetList<RichText>(find.byType(RichText));
        final String combined =
            cells.map((RichText text) => text.text.toPlainText()).join('\n');
        expect(combined.contains('• First'), isTrue);
        expect(combined.contains('• Second'), isTrue);
      },
    );

    testWidgets(
      'render HTML ordered list inside cells',
      (WidgetTester tester) async {
        const String data =
            '|Header|\n|-----|\n|<ol><li>First</li><li>Second</li></ol>|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        addTearDown(() async {
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });

        final Iterable<RichText> cells =
            tester.widgetList<RichText>(find.byType(RichText));
        final String combined =
            cells.map((RichText text) => text.text.toPlainText()).join('\n');
        expect(combined.contains('1.'), isTrue);
        expect(combined.contains('First'), isTrue);
        expect(combined.contains('2.'), isTrue);
        expect(combined.contains('Second'), isTrue);
      },
    );

    testWidgets(
      'render complex markdown table with inline html',
      (WidgetTester tester) async {
        const String data = '''
|   ![](content/_inline_images/9e5147061d547da0764a8c420c699420.png)  ![](content/_inline_images/e7b4920fd9858296cc843c2c51485b60.png)   |  |
| --- | --- |
|   **Class**  Narcotic analgesic   |   **EMS Indications**  <br><ul><li><b>Consult TP</b> to discuss use in RSIP</li><li>Analgesia prior to intubation in conjunction with midazolam</li></ul> |
|   **Dosage**  <br>  **Repeat**   |   2 mcg/kg rapid IV/IO ideal body weight  <br>  Do not repeat dose   |
|   **EMS Contraindications**   | <br><ul><li>Hypersensitivity</li><li>Monoamine oxidase inhibitor therapy within last 14 days</li><li>Systolic BP less than 100 mmHg</li></ul> |
|   **Notes**   | <br><ul><li>Use with caution in myasthenia gravis</li><li>Even when used appropriately, can induce post airway intervention hypotension</li></ul> |
''';

        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final List<ImageProvider<Object>> providers = tester
            .widgetList(find.byType(Image))
            .cast<Image>()
            .map((Image image) => image.image)
            .toList();

        addTearDown(() async {
          for (final ImageProvider<Object> provider in providers) {
            await provider.evict();
          }
          await tester.pumpWidget(const SizedBox());
          await tester.pumpAndSettle();
        });

        final Finder richTextFinder = find.byType(RichText);
        final Iterable<RichText> cells = tester.widgetList(richTextFinder);
        final bool hasBoldConsult = cells.any((RichText richText) {
          final InlineSpan span = richText.text;
          if (span is! TextSpan) {
            return false;
          }
          bool found = false;
          span.visitChildren((InlineSpan child) {
            if (child is TextSpan &&
                child.toPlainText().contains('Consult TP') &&
                (child.style?.fontWeight == FontWeight.bold ||
                    child.style?.fontWeight == FontWeight.w700)) {
              found = true;
              return false;
            }
            return true;
          });
          return found;
        });

        expect(hasBoldConsult, isTrue);
      },
    );

    testWidgets(
      'should work with alignments',
      (WidgetTester tester) async {
        const String data =
            '|Header 1|Header 2|Header 3|\n|:----|:----:|----:|\n|Col 1|Col 2|Col 3|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<DefaultTextStyle> styles =
            tester.widgetList(find.byType(DefaultTextStyle));

        expect(styles.first.textAlign, TextAlign.left);
        expect(styles.elementAt(1).textAlign, TextAlign.center);
        expect(styles.last.textAlign, TextAlign.right);

        final Iterable<Wrap> wraps = tester.widgetList(find.byType(Wrap));

        expect(wraps.first.alignment, WrapAlignment.start);
        expect(wraps.elementAt(1).alignment, WrapAlignment.center);
        expect(wraps.last.alignment, WrapAlignment.end);

        final Iterable<Text> texts = tester.widgetList(find.byType(Text));

        expect(texts.first.textAlign, TextAlign.left);
        expect(texts.elementAt(1).textAlign, TextAlign.center);
        expect(texts.last.textAlign, TextAlign.right);
      },
    );

    testWidgets(
      'should work with styling',
      (WidgetTester tester) async {
        const String data = '|Header|\n|----|\n|*italic*|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<Widget> widgets = tester.allWidgets;
        final Text text =
            widgets.lastWhere((Widget widget) => widget is Text) as Text;

        expectTextStrings(widgets, <String>['Header', 'italic']);
        expect(text.textSpan!.style!.fontStyle, FontStyle.italic);
      },
    );

    testWidgets(
      'should work next to other tables',
      (WidgetTester tester) async {
        const String data = '|first header|\n|----|\n|first col|\n\n'
            '|second header|\n|----|\n|second col|';
        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Iterable<Widget> tables = tester.widgetList(find.byType(Table));

        expect(tables.length, 2);
      },
    );

    testWidgets(
      'respect custom table builder output',
      (WidgetTester tester) async {
        const String data = '|H|\n|---|\n|C|';
        await tester.pumpWidget(
          boilerplate(
            MarkdownBody(
              data: data,
              builders: <String, MarkdownElementBuilder>{
                'table': _StubTableBuilder(),
              },
            ),
          ),
        );

        expect(find.text('custom table widget'), findsOneWidget);
        expect(find.byType(Table), findsNothing);
      },
    );

    testWidgets(
      'column width should follow stylesheet',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        const FixedColumnWidth columnWidth = FixedColumnWidth(100);
        final MarkdownStyleSheet style =
            MarkdownStyleSheet.fromTheme(theme).copyWith(
          tableColumnWidth: columnWidth,
        );

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expect(table.defaultColumnWidth, columnWidth);
      },
    );

    testWidgets(
      'table cell vertical alignment should default to middle',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        final MarkdownStyleSheet style = MarkdownStyleSheet.fromTheme(theme);
        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expect(
            table.defaultVerticalAlignment, TableCellVerticalAlignment.middle);
      },
    );

    testWidgets(
      'table cell vertical alignment should follow stylesheet',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        const TableCellVerticalAlignment tableCellVerticalAlignment =
            TableCellVerticalAlignment.top;
        final MarkdownStyleSheet style = MarkdownStyleSheet.fromTheme(theme)
            .copyWith(tableVerticalAlignment: tableCellVerticalAlignment);

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expect(table.defaultVerticalAlignment, tableCellVerticalAlignment);
      },
    );

    testWidgets(
      'table cell vertical alignment should follow stylesheet for different values',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        const TableCellVerticalAlignment tableCellVerticalAlignment =
            TableCellVerticalAlignment.bottom;
        final MarkdownStyleSheet style = MarkdownStyleSheet.fromTheme(theme)
            .copyWith(tableVerticalAlignment: tableCellVerticalAlignment);

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expect(table.defaultVerticalAlignment, tableCellVerticalAlignment);
      },
    );

    testWidgets(
      'table scrollbar thumbVisibility should follow stylesheet',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        const bool tableScrollbarThumbVisibility = true;
        final MarkdownStyleSheet style = MarkdownStyleSheet.fromTheme(theme)
            .copyWith(
                tableColumnWidth: const FixedColumnWidth(100),
                tableScrollbarThumbVisibility: tableScrollbarThumbVisibility,
                enableInteractiveTable: false);

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Scrollbar scrollbar = tester.widget(find.byType(Scrollbar));

        expect(scrollbar.thumbVisibility, tableScrollbarThumbVisibility);
      },
    );

    testWidgets(
      'table scrollbar thumbVisibility should follow stylesheet',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header|\n|----|\n|Column|';
        const bool tableScrollbarThumbVisibility = false;
        final MarkdownStyleSheet style = MarkdownStyleSheet.fromTheme(theme)
            .copyWith(
                tableColumnWidth: const FixedColumnWidth(100),
                tableScrollbarThumbVisibility: tableScrollbarThumbVisibility,
                enableInteractiveTable: false);

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Scrollbar scrollbar = tester.widget(find.byType(Scrollbar));

        expect(scrollbar.thumbVisibility, tableScrollbarThumbVisibility);
      },
    );

    testWidgets(
      'table with last row of empty table cells',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data = '|Header 1|Header 2|\n|----|----|\n| | |';
        const FixedColumnWidth columnWidth = FixedColumnWidth(100);
        final MarkdownStyleSheet style =
            MarkdownStyleSheet.fromTheme(theme).copyWith(
          tableColumnWidth: columnWidth,
        );

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expectTableSize(2, 2);

        expect(find.byType(Text), findsNWidgets(4));
        final List<String?> cellText = find
            .byType(Text)
            .evaluate()
            .map((Element e) => e.widget)
            .cast<Text>()
            .map((Text text) => text.textSpan!)
            .cast<TextSpan>()
            .map((TextSpan e) => e.text)
            .toList();
        expect(cellText[0], 'Header 1');
        expect(cellText[1], 'Header 2');
        expect(cellText[2], '');
        expect(cellText[3], '');

        expect(table.defaultColumnWidth, columnWidth);
      },
    );

    testWidgets(
      'table with an empty row an last row has an empty table cell',
      (WidgetTester tester) async {
        final ThemeData theme =
            ThemeData.light().copyWith(textTheme: textTheme);

        const String data =
            '|Header 1|Header 2|\n|----|----|\n| | |\n| bar | |';
        const FixedColumnWidth columnWidth = FixedColumnWidth(100);
        final MarkdownStyleSheet style =
            MarkdownStyleSheet.fromTheme(theme).copyWith(
          tableColumnWidth: columnWidth,
        );

        await tester.pumpWidget(
            boilerplate(MarkdownBody(data: data, styleSheet: style)));

        final Table table = tester.widget(find.byType(Table));

        expectTableSize(3, 2);

        expect(find.byType(RichText), findsNWidgets(6));
        final List<String?> cellText = find
            .byType(Text)
            .evaluate()
            .map((Element e) => e.widget)
            .cast<Text>()
            .map((Text richText) => richText.textSpan!)
            .cast<TextSpan>()
            .map((TextSpan e) => e.text)
            .toList();
        expect(cellText[0], 'Header 1');
        expect(cellText[1], 'Header 2');
        expect(cellText[2], '');
        expect(cellText[3], '');
        expect(cellText[4], 'bar');
        expect(cellText[5], '');

        expect(table.defaultColumnWidth, columnWidth);
      },
    );

    group('GFM Examples', () {
      testWidgets(
        // Example 198 from GFM.
        'simple table',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data = '| foo | bar |\n| --- | --- |\n| baz | bim |';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(2, 2);

          expect(find.byType(Text), findsNWidgets(4));
          final List<String?> cellText = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(cellText[0], 'foo');
          expect(cellText[1], 'bar');
          expect(cellText[2], 'baz');
          expect(cellText[3], 'bim');
          expect(table.defaultColumnWidth, columnWidth);
        },
      );

      testWidgets(
        // Example 199 from GFM.
        'input table cell data does not need to match column length',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data = '| abc | defghi |\n:-: | -----------:\nbar | baz';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(2, 2);

          expect(find.byType(Text), findsNWidgets(4));
          final List<String?> cellText = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(cellText[0], 'abc');
          expect(cellText[1], 'defghi');
          expect(cellText[2], 'bar');
          expect(cellText[3], 'baz');
          expect(table.defaultColumnWidth, columnWidth);
        },
      );

      testWidgets(
        // Example 200 from GFM.
        'include a pipe in table cell data by escaping the pipe',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data =
              '| f\\|oo  |\n| ------ |\n| b \\| az |\n| b **\\|** im |';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(1, 3);

          expect(find.byType(Text), findsNWidgets(4));
          final List<String?> cellText = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(cellText[0], 'f|oo');
          expect(cellText[1], 'defghi');
          expect(cellText[2], 'b | az');
          expect(cellText[3], 'b | im');
          expect(table.defaultColumnWidth, columnWidth);
        },
        // TODO(mjordan56): Remove skip once the issue #340 in the markdown package
        // is fixed and released. https://github.com/dart-lang/markdown/issues/340
        // This test will need adjusting once issue #340 is fixed.
        skip: true,
      );

      testWidgets(
        // Example 201 from GFM.
        'table definition is complete at beginning of new block',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data =
              '| abc | def |\n| --- | --- |\n| bar | baz |\n> bar';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(2, 2);

          expect(find.byType(Text), findsNWidgets(5));
          final List<String?> text = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(text[0], 'abc');
          expect(text[1], 'def');
          expect(text[2], 'bar');
          expect(text[3], 'baz');
          expect(table.defaultColumnWidth, columnWidth);

          // Blockquote
          expect(find.byType(DecoratedBox), findsOneWidget);
          expect(text[4], 'bar');
        },
      );

      testWidgets(
        // Example 202 from GFM.
        'table definition is complete at first empty line',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data =
              '| abc | def |\n| --- | --- |\n| bar | baz |\nbar\n\nbar';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(3, 2);

          expect(find.byType(Text), findsNWidgets(7));
          final List<String?> text = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(text, <String>['abc', 'def', 'bar', 'baz', 'bar', '', 'bar']);
          expect(table.defaultColumnWidth, columnWidth);
        },
      );

      testWidgets(
        // Example 203 from GFM.
        'table header row must match the delimiter row in number of cells',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data = '| abc | def |\n| --- |\n| bar |';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          expect(find.byType(Table), findsNothing);
          final List<String?> text = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(text[0], '| abc | def | | --- | | bar |');
        },
      );

      testWidgets(
        // Example 204 from GFM.
        'remainder of table cells may vary, excess cells are ignored',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data =
              '| abc | def |\n| --- | --- |\n| bar |\n| bar | baz | boo |';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(3, 2);

          expect(find.byType(Text), findsNWidgets(6));
          final List<String?> cellText = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(cellText, <String>['abc', 'def', 'bar', '', 'bar', 'baz']);
          expect(table.defaultColumnWidth, columnWidth);
        },
      );

      testWidgets(
        // Example 205 from GFM.
        'no table body is created when no rows are defined',
        (WidgetTester tester) async {
          final ThemeData theme =
              ThemeData.light().copyWith(textTheme: textTheme);

          const String data = '| abc | def |\n| --- | --- |';
          const FixedColumnWidth columnWidth = FixedColumnWidth(100);
          final MarkdownStyleSheet style =
              MarkdownStyleSheet.fromTheme(theme).copyWith(
            tableColumnWidth: columnWidth,
          );

          await tester.pumpWidget(
              boilerplate(MarkdownBody(data: data, styleSheet: style)));

          final Table table = tester.widget(find.byType(Table));

          expectTableSize(1, 2);

          expect(find.byType(Text), findsNWidgets(2));
          final List<String?> cellText = find
              .byType(Text)
              .evaluate()
              .map((Element e) => e.widget)
              .cast<Text>()
              .map((Text text) => text.textSpan!)
              .cast<TextSpan>()
              .map((TextSpan e) => e.text)
              .toList();
          expect(cellText[0], 'abc');
          expect(cellText[1], 'def');
          expect(table.defaultColumnWidth, columnWidth);
        },
      );
    });
  });

  testWidgets(
    'interactive table dialog shows sticky overlays',
    (WidgetTester tester) async {
      final binding = tester.binding;
      binding.window.physicalSizeTestValue = const Size(400, 800);
      binding.window.devicePixelRatioTestValue = 1.0;
      addTearDown(() {
        binding.window.clearPhysicalSizeTestValue();
        binding.window.clearDevicePixelRatioTestValue();
      });

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(size: Size(400, 800)),
            child: Center(
              child: SizedBox(
                key: const ValueKey('tableViewport'),
                width: 400,
                height: 800,
                child: MarkdownBody(
                  data: _wideTableMarkdown,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Dose in mcg/kg/min'), findsOneWidget);

      await tester.tap(find.text('Dose in mcg/kg/min'), warnIfMissed: false);
      await tester.pumpAndSettle();
      await tester.pump();

      expect(find.byIcon(Icons.close), findsOneWidget);
      expect(find.byType(StickyTable), findsOneWidget);

      final RenderStickyTable renderSticky =
          tester.renderObject<RenderStickyTable>(find.byType(StickyTable));
      expect(renderSticky.stickyRowCount, greaterThanOrEqualTo(1));
      expect(renderSticky.stickyColumnCount, greaterThanOrEqualTo(1));
      expect(renderSticky.stickyColumnMaxFraction, closeTo(1.0, 0.0001));

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpAndSettle();
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnoredAll(),
  );

  testWidgets(
    'interactive table disabled via style sheet',
    (WidgetTester tester) async {
      final ThemeData theme = ThemeData.light().copyWith(textTheme: textTheme);
      final MarkdownStyleSheet style =
          MarkdownStyleSheet.fromTheme(theme).copyWith(
        enableInteractiveTable: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MarkdownBody(
            data: _wideTableMarkdown,
            styleSheet: style,
          ),
        ),
      );

      expect(find.byType(MarkdownInteractiveTable), findsNothing);
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnoredAll(),
  );

  testWidgets(
    'interactive table sticky controls can be disabled',
    (WidgetTester tester) async {
      final ThemeData theme = ThemeData.light().copyWith(textTheme: textTheme);
      final MarkdownStyleSheet style =
          MarkdownStyleSheet.fromTheme(theme).copyWith(
        enableStickyTableHeader: false,
        enableStickyTableColumn: false,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MarkdownBody(
            data: _wideTableMarkdown,
            styleSheet: style,
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Dose in mcg/kg/min'), warnIfMissed: false);
      await tester.pumpAndSettle();

      final RenderStickyTable renderSticky =
          tester.renderObject<RenderStickyTable>(find.byType(StickyTable));
      expect(renderSticky.stickyRowCount, 0);
      expect(renderSticky.stickyColumnCount, 0);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();
    },
    experimentalLeakTesting: LeakTesting.settings.withIgnoredAll(),
  );
}

class _StubTableBuilder extends MarkdownElementBuilder {
  @override
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return const Padding(
      padding: EdgeInsets.all(8),
      child: Text('custom table widget'),
    );
  }
}

const String _wideTableMarkdown = '''
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
