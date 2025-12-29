// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:markdown/markdown.dart' as md;

// ignore_for_file: public_member_api_docs

/// Parses raw HTML `<sub>`, `<sup>`, and `<u>` tags into Markdown elements.
class HtmlInlineTagSyntax extends md.InlineSyntax {
  HtmlInlineTagSyntax()
      : super(
          _pattern,
          caseSensitive: false,
          startCharacter: _startCharacter,
        );

  static const String _pattern = r'<(sub|sup|u)\b[^>]*>([^<]*)</\1\s*>';
  static const int _startCharacter = 0x3C; // '<'

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final String tag = match.group(1)!.toLowerCase();
    final String text = match.group(2) ?? '';
    parser.addNode(md.Element.text(tag, text));
    return true;
  }
}
