import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';

void main() {
  final theme = ThemeData.light();
  final sheet = MarkdownStyleSheet.fromTheme(theme);
  print(sheet.tableColumnWidth);
}
