// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'utils.dart';

void main() => defineTests();

void defineTests() {
  group('HTML', () {
    testWidgets(
      'ignore tags',
      (WidgetTester tester) async {
        final List<String> data = <String>[
          'Line 1\n<p>HTML content</p>\nLine 2',
          'Line 1\n<!-- HTML\n comment\n ignored --><\nLine 2'
        ];

        for (final String line in data) {
          await tester.pumpWidget(boilerplate(MarkdownBody(data: line)));

          final Iterable<Widget> widgets = tester.allWidgets;
          expectTextStrings(widgets, <String>['Line 1', 'Line 2']);
        }
      },
    );

    testWidgets(
      "doesn't convert & to &amp; when parsing",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          boilerplate(
            const Markdown(data: '&'),
          ),
        );
        expectTextStrings(tester.allWidgets, <String>['&']);
      },
    );

    testWidgets(
      "doesn't convert < to &lt; when parsing",
      (WidgetTester tester) async {
        await tester.pumpWidget(
          boilerplate(
            const Markdown(data: '<'),
          ),
        );
        expectTextStrings(tester.allWidgets, <String>['<']);
      },
    );

    testWidgets(
      'parses inline sub, sup, and u tags',
      (WidgetTester tester) async {
        const String data = 'H<sub>2</sub>O and E = mc<sup>2</sup> plus <u>underline</u>.';

        await tester.pumpWidget(
          boilerplate(
            const MarkdownBody(data: data),
          ),
        );

        final Text text = tester.widget(find.byType(Text).first);
        final TextSpan span = text.textSpan! as TextSpan;
        expect(
          _extractInlineText(span),
          'H2O and E = mc2 plus underline.',
        );

        final List<TextSpan> spans = _collectTextSpans(span);
        expect(
          spans.where((TextSpan s) => s.text == '2' && _hasFontFeature(s, 'subs')).length,
          1,
        );
        expect(
          spans.where((TextSpan s) => s.text == '2' && _hasFontFeature(s, 'sups')).length,
          1,
        );

        final TextSpan underlineSpan =
            spans.firstWhere((TextSpan s) => s.text?.contains('underline') ?? false);
        expect(underlineSpan.style, isNotNull);
        expect(underlineSpan.style!.decoration, TextDecoration.underline);
      },
    );
  });
}

List<TextSpan> _collectTextSpans(InlineSpan span) {
  final List<TextSpan> spans = <TextSpan>[];
  void visit(InlineSpan current) {
    if (current is TextSpan) {
      spans.add(current);
      final List<InlineSpan>? children = current.children;
      if (children != null) {
        for (final InlineSpan child in children) {
          visit(child);
        }
      }
    } else if (current is WidgetSpan) {
      spans.addAll(_collectTextSpansFromWidget(current.child));
    }
  }

  visit(span);
  return spans;
}

List<TextSpan> _collectTextSpansFromWidget(Widget widget) {
  if (widget is Text && widget.textSpan is TextSpan) {
    return _collectTextSpans(widget.textSpan!);
  }
  if (widget is RichText && widget.text is TextSpan) {
    return _collectTextSpans(widget.text as TextSpan);
  }
  if (widget is SelectableText && widget.textSpan is TextSpan) {
    return _collectTextSpans(widget.textSpan!);
  }
  if (widget is Transform && widget.child != null) {
    return _collectTextSpansFromWidget(widget.child!);
  }
  return <TextSpan>[];
}

bool _hasFontFeature(TextSpan span, String feature) {
  final List<FontFeature>? features = span.style?.fontFeatures;
  if (features == null) {
    return false;
  }
  return features.any((FontFeature value) => value.feature == feature);
}

String _extractInlineText(InlineSpan span) {
  if (span is TextSpan) {
    String text = span.text ?? '';
    final List<InlineSpan>? children = span.children;
    if (children != null) {
      for (final InlineSpan child in children) {
        text += _extractInlineText(child);
      }
    }
    return text;
  }
  if (span is WidgetSpan) {
    return _extractInlineTextFromWidget(span.child);
  }
  return '';
}

String _extractInlineTextFromWidget(Widget widget) {
  if (widget is Text && widget.textSpan is TextSpan) {
    return _extractInlineText(widget.textSpan!);
  }
  if (widget is RichText && widget.text is TextSpan) {
    return _extractInlineText(widget.text as TextSpan);
  }
  if (widget is SelectableText && widget.textSpan is TextSpan) {
    return _extractInlineText(widget.textSpan!);
  }
  if (widget is Transform && widget.child != null) {
    return _extractInlineTextFromWidget(widget.child!);
  }
  return '';
}
