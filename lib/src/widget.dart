// Copyright 2013 The Flutter Authors. All rights reserved.
// Use of this source code is governed by a BSD-style license that can be
// found in the LICENSE file.

import 'dart:convert';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:markdown/markdown.dart' as md;

import '../flutter_markdown_plus.dart';
import '_functions_io.dart' if (dart.library.js_interop) '_functions_web.dart';
import 'inline_syntaxes/html_break_syntax.dart';

/// Signature for callbacks used by [MarkdownWidget] when
/// [MarkdownWidget.selectable] is set to true and the user changes selection.
///
/// The callback will return the entire block of text available for selection,
/// along with the current [selection] and the [cause] of the selection change.
/// This is a wrapper of [SelectionChangedCallback] with additional context
/// [text] for the caller to process.
///
/// Used by [MarkdownWidget.onSelectionChanged]
typedef MarkdownOnSelectionChangedCallback = void Function(
    String? text, TextSelection selection, SelectionChangedCause? cause);

/// Signature for callbacks used by [MarkdownWidget] when the user taps a link.
/// The callback will return the link text, destination, and title from the
/// Markdown link tag in the document.
///
/// Used by [MarkdownWidget.onTapLink].
typedef MarkdownTapLinkCallback = void Function(String text, String? href, String title);

/// Signature for custom image widget.
///
/// Used by [MarkdownWidget.imageBuilder]
typedef MarkdownImageBuilder = Widget Function(Uri uri, String? title, String? alt);

/// Signature for custom checkbox widget.
///
/// Used by [MarkdownWidget.checkboxBuilder]
typedef MarkdownCheckboxBuilder = Widget Function(bool value);

/// Signature for custom bullet widget.
///
/// Used by [MarkdownWidget.bulletBuilder]
typedef MarkdownBulletBuilder = Widget Function(
  MarkdownBulletParameters parameters,
);

/// An parameters of [MarkdownBulletBuilder].
///
/// Used by [MarkdownWidget.bulletBuilder]
class MarkdownBulletParameters {
  /// Creates a new instance of [MarkdownBulletParameters].
  const MarkdownBulletParameters({
    required this.index,
    required this.style,
    required this.nestLevel,
  });

  /// The index of the bullet on that nesting level.
  final int index;

  /// The style of the bullet.
  final BulletStyle style;

  /// The nest level of the bullet.
  final int nestLevel;
}

/// Enumeration sent to the user when calling [MarkdownBulletBuilder]
///
/// Use this to differentiate the bullet styling when building your own.
enum BulletStyle {
  /// An ordered list.
  orderedList,

  /// An unordered list.
  unorderedList,
}

/// Creates a format [TextSpan] given a string.
///
/// Used by [MarkdownWidget] to highlight the contents of `pre` elements.
abstract class SyntaxHighlighter {
  // ignore: one_member_abstracts
  /// Returns the formatted [TextSpan] for the given string.
  TextSpan format(String source);
}

/// An interface for an element builder.
abstract class MarkdownElementBuilder {
  /// For block syntax has to return true.
  ///
  /// By default returns false.
  bool isBlockElement() => false;

  /// Called when an Element has been reached, before its children have been
  /// visited.
  void visitElementBefore(md.Element element) {}

  /// Called when a text node has been reached.
  ///
  /// If [MarkdownWidget.styleSheet] has a style of this tag, will passing
  /// to [preferredStyle].
  ///
  /// If you needn't build a widget, return null.
  Widget? visitText(md.Text text, TextStyle? preferredStyle) => null;

  /// Called when an Element has been reached, after its children have been
  /// visited.
  ///
  /// If [MarkdownWidget.styleSheet] has a style with this tag, it will be
  /// passed as [preferredStyle].
  ///
  /// If parent element has [TextStyle] set, it will be passed as
  /// [parentStyle].
  ///
  /// If a widget build isn't needed, return null.
  Widget? visitElementAfterWithContext(
    BuildContext context,
    md.Element element,
    TextStyle? preferredStyle,
    TextStyle? parentStyle,
  ) {
    return visitElementAfter(element, preferredStyle);
  }

  /// Called when an Element has been reached, after its children have been
  /// visited.
  ///
  /// If [MarkdownWidget.styleSheet] has a style of this tag, will passing
  /// to [preferredStyle].
  ///
  /// If you needn't build a widget, return null.
  @Deprecated('Use visitElementAfterWithContext() instead.')
  Widget? visitElementAfter(md.Element element, TextStyle? preferredStyle) => null;
}

/// Enum to specify which theme being used when creating [MarkdownStyleSheet]
///
/// [material] - create MarkdownStyleSheet based on MaterialTheme
/// [cupertino] - create MarkdownStyleSheet based on CupertinoTheme
/// [platform] - create MarkdownStyleSheet based on the Platform where the
/// is running on. Material on Android and Cupertino on iOS
enum MarkdownStyleSheetBaseTheme {
  /// Creates a MarkdownStyleSheet based on MaterialTheme.
  material,

  /// Creates a MarkdownStyleSheet based on CupertinoTheme.
  cupertino,

  /// Creates a MarkdownStyleSheet whose theme is based on the current platform.
  platform,
}

/// Enumeration of alignment strategies for the cross axis of list items.
enum MarkdownListItemCrossAxisAlignment {
  /// Uses [CrossAxisAlignment.baseline] for the row the bullet and the list
  /// item are placed in.
  ///
  /// This alignment will ensure that the bullet always lines up with
  /// the list text on the baseline.
  ///
  /// However, note that this alignment does not support intrinsic height
  /// measurements because [RenderFlex] does not support it for
  /// [CrossAxisAlignment.baseline].
  /// See https://github.com/flutter/flutter_markdown_plus/issues/311 for cases,
  /// where this might be a problem for you.
  ///
  /// See also:
  /// * [start], which allows for intrinsic height measurements.
  baseline,

  /// Uses [CrossAxisAlignment.start] for the row the bullet and the list item
  /// are placed in.
  ///
  /// This alignment will ensure that intrinsic height measurements work.
  ///
  /// However, note that this alignment might not line up the bullet with the
  /// list text in the way you would expect in certain scenarios.
  /// See https://github.com/flutter/flutter_markdown_plus/issues/169 for example
  /// cases that do not produce expected results.
  ///
  /// See also:
  /// * [baseline], which will position the bullet and list item on the
  ///   baseline.
  start,
}

/// A base class for widgets that parse and display Markdown.
///
/// Supports all standard Markdown from the original
/// [Markdown specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [Markdown], which is a scrolling container of Markdown.
///  * [MarkdownBody], which is a non-scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
abstract class MarkdownWidget extends StatefulWidget {
  /// Creates a widget that parses and displays Markdown.
  ///
  /// The [data] argument must not be null.
  const MarkdownWidget({
    super.key,
    required this.data,
    this.selectable = false,
    this.styleSheet,
    this.styleSheetTheme = MarkdownStyleSheetBaseTheme.material,
    this.syntaxHighlighter,
    this.onSelectionChanged,
    this.onTapLink,
    this.onTapText,
    this.imageDirectory,
    this.blockSyntaxes,
    this.inlineSyntaxes,
    this.extensionSet,
    this.imageBuilder,
    this.checkboxBuilder,
    this.bulletBuilder,
    this.builders = const <String, MarkdownElementBuilder>{},
    this.paddingBuilders = const <String, MarkdownPaddingBuilder>{},
    this.fitContent = false,
    this.listItemCrossAxisAlignment = MarkdownListItemCrossAxisAlignment.baseline,
    this.softLineBreak = false,
  });

  /// The Markdown to display.
  final String data;

  /// If true, the text is selectable.
  ///
  /// Defaults to false.
  final bool selectable;

  /// The styles to use when displaying the Markdown.
  ///
  /// If null, the styles are inferred from the current [Theme].
  final MarkdownStyleSheet? styleSheet;

  /// Setting to specify base theme for MarkdownStyleSheet
  ///
  /// Default to [MarkdownStyleSheetBaseTheme.material]
  final MarkdownStyleSheetBaseTheme? styleSheetTheme;

  /// The syntax highlighter used to color text in `pre` elements.
  ///
  /// If null, the [MarkdownStyleSheet.code] style is used for `pre` elements.
  final SyntaxHighlighter? syntaxHighlighter;

  /// Called when the user taps a link.
  final MarkdownTapLinkCallback? onTapLink;

  /// Called when the user changes selection when [selectable] is set to true.
  final MarkdownOnSelectionChangedCallback? onSelectionChanged;

  /// Default tap handler used when [selectable] is set to true
  final VoidCallback? onTapText;

  /// The base directory holding images referenced by Img tags with local or network file paths.
  final String? imageDirectory;

  /// Collection of custom block syntax types to be used parsing the Markdown data.
  final List<md.BlockSyntax>? blockSyntaxes;

  /// Collection of custom inline syntax types to be used parsing the Markdown data.
  final List<md.InlineSyntax>? inlineSyntaxes;

  /// Markdown syntax extension set
  ///
  /// Defaults to [md.ExtensionSet.gitHubFlavored]
  final md.ExtensionSet? extensionSet;

  /// Call when build an image widget.
  final MarkdownImageBuilder? imageBuilder;

  /// Call when build a checkbox widget.
  final MarkdownCheckboxBuilder? checkboxBuilder;

  /// Called when building a bullet
  final MarkdownBulletBuilder? bulletBuilder;

  /// Render certain tags, usually used with [extensionSet]
  ///
  /// For example, we will add support for `sub` tag:
  ///
  /// ```dart
  /// builders: {
  ///   'sub': SubscriptBuilder(),
  /// }
  /// ```
  ///
  /// The `SubscriptBuilder` is a subclass of [MarkdownElementBuilder].
  final Map<String, MarkdownElementBuilder> builders;

  /// Add padding for different tags (use only for block elements and img)
  ///
  /// For example, we will add padding for `img` tag:
  ///
  /// ```dart
  /// paddingBuilders: {
  ///   'img': ImgPaddingBuilder(),
  /// }
  /// ```
  ///
  /// The `ImgPaddingBuilder` is a subclass of [MarkdownPaddingBuilder].
  final Map<String, MarkdownPaddingBuilder> paddingBuilders;

  /// Whether to allow the widget to fit the child content.
  final bool fitContent;

  /// Controls the cross axis alignment for the bullet and list item content
  /// in lists.
  ///
  /// Defaults to [MarkdownListItemCrossAxisAlignment.baseline], which
  /// does not allow for intrinsic height measurements.
  final MarkdownListItemCrossAxisAlignment listItemCrossAxisAlignment;

  /// The soft line break is used to identify the spaces at the end of aline of
  /// text and the leading spaces in the immediately following the line of text.
  ///
  /// Default these spaces are removed in accordance with the Markdown
  /// specification on soft line breaks when lines of text are joined.
  final bool softLineBreak;

  /// Subclasses should override this function to display the given children,
  /// which are the parsed representation of [data].
  @protected
  Widget build(BuildContext context, List<Widget>? children);

  @override
  State<MarkdownWidget> createState() => _MarkdownWidgetState();
}

class _MarkdownWidgetState extends State<MarkdownWidget> implements MarkdownBuilderDelegate {
  List<Widget>? _children;
  final List<GestureRecognizer> _recognizers = <GestureRecognizer>[];

  @override
  void didChangeDependencies() {
    _parseMarkdown();
    super.didChangeDependencies();
  }

  @override
  void didUpdateWidget(MarkdownWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.data != oldWidget.data || widget.styleSheet != oldWidget.styleSheet) {
      _parseMarkdown();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _parseMarkdown() {
    final MarkdownStyleSheet fallbackStyleSheet = kFallbackStyle(context, widget.styleSheetTheme);
    final MarkdownStyleSheet styleSheet = fallbackStyleSheet.merge(widget.styleSheet);

    _disposeRecognizers();

    final List<md.InlineSyntax> inlineSyntaxes = <md.InlineSyntax>[
      HtmlBreakSyntax(),
      if (widget.inlineSyntaxes != null) ...widget.inlineSyntaxes!,
    ];

    final md.Document document = md.Document(
      blockSyntaxes: widget.blockSyntaxes,
      inlineSyntaxes: inlineSyntaxes,
      extensionSet: widget.extensionSet ?? md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );

    final String normalizedData = _replaceHtmlLists(widget.data);

    // Parse the source Markdown data into nodes of an Abstract Syntax Tree.
    final List<String> lines = const LineSplitter().convert(normalizedData);
    final List<md.Node> astNodes = document.parseLines(lines);

    // Configure a Markdown widget builder to traverse the AST nodes and
    // create a widget tree based on the elements.
    final MarkdownBuilder builder = MarkdownBuilder(
      delegate: this,
      selectable: widget.selectable,
      styleSheet: styleSheet,
      imageDirectory: widget.imageDirectory,
      imageBuilder: widget.imageBuilder,
      checkboxBuilder: widget.checkboxBuilder,
      bulletBuilder: widget.bulletBuilder,
      builders: widget.builders,
      paddingBuilders: widget.paddingBuilders,
      fitContent: widget.fitContent,
      listItemCrossAxisAlignment: widget.listItemCrossAxisAlignment,
      onSelectionChanged: widget.onSelectionChanged,
      onTapText: widget.onTapText,
      softLineBreak: widget.softLineBreak,
    );

    _children = builder.build(astNodes);
  }

  void _disposeRecognizers() {
    if (_recognizers.isEmpty) {
      return;
    }
    final List<GestureRecognizer> localRecognizers = List<GestureRecognizer>.from(_recognizers);
    _recognizers.clear();
    for (final GestureRecognizer recognizer in localRecognizers) {
      recognizer.dispose();
    }
  }

  @override
  GestureRecognizer createLink(String text, String? href, String title) {
    final TapGestureRecognizer recognizer = TapGestureRecognizer()
      ..onTap = () {
        if (widget.onTapLink != null) {
          widget.onTapLink!(text, href, title);
        }
      };
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  TextSpan formatText(MarkdownStyleSheet styleSheet, String code) {
    code = code.replaceAll(RegExp(r'\n$'), '');
    if (widget.syntaxHighlighter != null) {
      return widget.syntaxHighlighter!.format(code);
    }
    return TextSpan(style: styleSheet.code, text: code);
  }

  @override
  Widget build(BuildContext context) => widget.build(context, _children);
}

/// A non-scrolling widget that parses and displays Markdown.
///
/// Supports all GitHub Flavored Markdown from the
/// [specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [Markdown], which is a scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
class MarkdownBody extends MarkdownWidget {
  /// Creates a non-scrolling widget that parses and displays Markdown.
  const MarkdownBody({
    super.key,
    required super.data,
    super.selectable,
    super.styleSheet,
    super.styleSheetTheme = null,
    super.syntaxHighlighter,
    super.onSelectionChanged,
    super.onTapLink,
    super.onTapText,
    super.imageDirectory,
    super.blockSyntaxes,
    super.inlineSyntaxes,
    super.extensionSet,
    super.imageBuilder,
    super.checkboxBuilder,
    super.bulletBuilder,
    super.builders,
    super.paddingBuilders,
    super.listItemCrossAxisAlignment,
    this.shrinkWrap = true,
    super.fitContent = true,
    super.softLineBreak,
  });

  /// If [shrinkWrap] is `true`, [MarkdownBody] will take the minimum height
  /// that wraps its content. Otherwise, [MarkdownBody] will expand to the
  /// maximum allowed height.
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    if (children!.length == 1 && shrinkWrap) {
      return children.single;
    }
    return Column(
      mainAxisSize: shrinkWrap ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: fitContent ? CrossAxisAlignment.start : CrossAxisAlignment.stretch,
      children: children,
    );
  }
}

/// A scrolling widget that parses and displays Markdown.
///
/// Supports all GitHub Flavored Markdown from the
/// [specification](https://github.github.com/gfm/).
///
/// See also:
///
///  * [MarkdownBody], which is a non-scrolling container of Markdown.
///  * <https://github.github.com/gfm/>
class Markdown extends MarkdownWidget {
  /// Creates a scrolling widget that parses and displays Markdown.
  const Markdown({
    super.key,
    required super.data,
    super.selectable,
    super.styleSheet,
    super.styleSheetTheme = null,
    super.syntaxHighlighter,
    super.onSelectionChanged,
    super.onTapLink,
    super.onTapText,
    super.imageDirectory,
    super.blockSyntaxes,
    super.inlineSyntaxes,
    super.extensionSet,
    super.imageBuilder,
    super.checkboxBuilder,
    super.bulletBuilder,
    super.builders,
    super.paddingBuilders,
    super.listItemCrossAxisAlignment,
    this.padding = const EdgeInsets.all(16.0),
    this.controller,
    this.physics,
    this.shrinkWrap = false,
    super.softLineBreak,
  });

  /// The amount of space by which to inset the children.
  final EdgeInsets padding;

  /// An object that can be used to control the position to which this scroll view is scrolled.
  ///
  /// See also: [ScrollView.controller]
  final ScrollController? controller;

  /// How the scroll view should respond to user input.
  ///
  /// See also: [ScrollView.physics]
  final ScrollPhysics? physics;

  /// Whether the extent of the scroll view in the scroll direction should be
  /// determined by the contents being viewed.
  ///
  /// See also: [ScrollView.shrinkWrap]
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context, List<Widget>? children) {
    return ListView(
      padding: padding,
      controller: controller,
      physics: physics,
      shrinkWrap: shrinkWrap,
      children: children!,
    );
  }
}

/// Parse [task list items](https://github.github.com/gfm/#task-list-items-extension-).
///
/// This class is no longer used as Markdown now supports checkbox syntax natively.
@Deprecated('Use [OrderedListWithCheckBoxSyntax] or [UnorderedListWithCheckBoxSyntax]')
class TaskListSyntax extends md.InlineSyntax {
  /// Creates a new instance.
  @Deprecated('Use [OrderedListWithCheckBoxSyntax] or [UnorderedListWithCheckBoxSyntax]')
  TaskListSyntax() : super(_pattern);

  static const String _pattern = r'^ *\[([ xX])\] +';

  @override
  bool onMatch(md.InlineParser parser, Match match) {
    final md.Element el = md.Element.withTag('input');
    el.attributes['type'] = 'checkbox';
    el.attributes['disabled'] = 'true';
    el.attributes['checked'] = '${match[1]!.trim().isNotEmpty}';
    parser.addNode(el);
    return true;
  }
}

/// An interface for an padding builder for element.
abstract class MarkdownPaddingBuilder {
  /// Called when an Element has been reached, before its children have been
  /// visited.
  void visitElementBefore(md.Element element) {}

  /// Called when a widget node has been rendering and need tag padding.
  EdgeInsets getPadding() => EdgeInsets.zero;
}

final RegExp _htmlListOpenPattern = RegExp(r'<(ul|ol)\b[^>]*>', caseSensitive: false);
final RegExp _htmlListItemPattern = RegExp(r'<li\b[^>]*>', caseSensitive: false);
final RegExp _htmlParagraphPattern = RegExp(r'</?p[^>]*>', caseSensitive: false);
final RegExp _htmlBreakPattern = RegExp(r'<br\s*/?>', caseSensitive: false);

String _replaceHtmlLists(String input, {int depth = 0}) {
  if (input.isEmpty) {
    return input;
  }

  final StringBuffer buffer = StringBuffer();
  int index = 0;

  while (index < input.length) {
    final RegExpMatch? match = _firstMatch(_htmlListOpenPattern, input, index);
    if (match == null) {
      buffer.write(input.substring(index));
      break;
    }

    buffer.write(input.substring(index, match.start));
    final String tag = match.group(1)!.toLowerCase();
    final _TagSegment? segment = _extractTag(input, match, tag);
    if (segment == null) {
      buffer.write(input.substring(match.start, match.end));
      index = match.end;
      continue;
    }

    final String rendered = _renderHtmlList(segment.inner, tag, depth);
    buffer.write(rendered);
    index = segment.end;
  }

  return buffer.toString();
}

String _renderHtmlList(String content, String tag, int depth) {
  final bool ordered = tag == 'ol';
  final List<String> items = <String>[];
  int index = 0;
  int counter = 1;

  while (index < content.length) {
    final RegExpMatch? match = _firstMatch(_htmlListItemPattern, content, index);
    if (match == null) {
      break;
    }
    final _TagSegment? segment = _extractTag(content, match, 'li');
    if (segment == null) {
      index = match.end;
      continue;
    }

    final String processed = _replaceHtmlLists(segment.inner, depth: depth + 1)
        .replaceAll(_htmlParagraphPattern, '')
        .trim();
    final List<String> lines = _splitHtmlLines(processed).map((String line) => line.trim()).toList();
    if (lines.isEmpty) {
      lines.add('');
    }

    final String indent = '\u00A0' * (depth * 2);
    final String marker = ordered ? '${counter++}.' : '•';
    final List<String> renderedLines = <String>[];
    renderedLines.add('$indent$marker ${lines.first}'.trimRight());

    final String childIndent = '$indent\u00A0\u00A0';
    for (final String line in lines.skip(1)) {
      if (line.isEmpty) {
        continue;
      }
      renderedLines.add('$childIndent$line');
    }

    items.add(renderedLines.join('<br>'));
    index = segment.end;
  }

  return items.join('<br>');
}

Iterable<String> _splitHtmlLines(String input) {
  if (input.isEmpty) {
    return const <String>[];
  }
  return input.split(_htmlBreakPattern);
}

_TagSegment? _extractTag(String source, RegExpMatch openMatch, String tag) {
  final RegExp openPattern = RegExp('<$tag\\b[^>]*>', caseSensitive: false);
  final RegExp closePattern = RegExp('</$tag\\s*>', caseSensitive: false);

  int searchIndex = openMatch.end;
  int depth = 1;

  while (searchIndex < source.length) {
    final RegExpMatch? nextOpen = _firstMatch(openPattern, source, searchIndex);
    final RegExpMatch? nextClose = _firstMatch(closePattern, source, searchIndex);

    if (nextClose == null) {
      return null;
    }

    if (nextOpen != null && nextOpen.start < nextClose.start) {
      depth++;
      searchIndex = nextOpen.end;
      continue;
    }

    depth--;
    final int closeStart = nextClose.start;
    final int closeEnd = nextClose.end;
    if (depth == 0) {
      final String inner = source.substring(openMatch.end, closeStart);
      return _TagSegment(inner, closeEnd);
    }
    searchIndex = closeEnd;
  }

  return null;
}

RegExpMatch? _firstMatch(RegExp pattern, String source, int start) {
  for (final RegExpMatch match in pattern.allMatches(source, start)) {
    return match;
  }
  return null;
}

class _TagSegment {
  const _TagSegment(this.inner, this.end);

  final String inner;
  final int end;
}
