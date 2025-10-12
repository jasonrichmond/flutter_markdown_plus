// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'package:markdown/markdown.dart' as md;

// ignore_for_file: public_member_api_docs

/// Parses raw HTML `<br>` tags and emits Markdown-compatible line breaks.
class HtmlBreakSyntax extends md.InlineSyntax {
  HtmlBreakSyntax()
      : super(
          _pattern,
          caseSensitive: false,
          startCharacter: _startCharacter,
        );

  static const String _pattern = r'<br\s*/?>';
  static const int _startCharacter = 0x3C; // '<'

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    parser.addNode(md.Element.empty('br'));
    return true;
  }
}
