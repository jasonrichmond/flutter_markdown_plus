import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:markdown/markdown.dart' as md;

import 'sticky_table.dart';
import 'style_sheet.dart';

typedef MarkdownTableElementBuilder = List<Widget> Function(
  md.Element element, {
  MarkdownStyleSheet? overrideStyleSheet,
});

class MarkdownInteractiveTable extends StatelessWidget {
  const MarkdownInteractiveTable({
    required this.inlineTable,
    required this.tableElement,
    required this.styleSheet,
    required this.buildElement,
  });

  final Widget inlineTable;
  final md.Element tableElement;
  final MarkdownStyleSheet styleSheet;
  final MarkdownTableElementBuilder buildElement;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => _showOverlay(context),
      child: inlineTable,
    );
  }

  void _showOverlay(BuildContext context) {
    Navigator.of(context, rootNavigator: true).push<void>(
      _InteractiveTableRoute(
        builder: (BuildContext routeContext) {
          return _InteractiveTablePage(
            tableElement: tableElement,
            styleSheet: styleSheet,
            buildElement: buildElement,
          );
        },
      ),
    );
  }
}

class _InteractiveTableRoute extends PopupRoute<void> {
  _InteractiveTableRoute({required this.builder});

  final WidgetBuilder builder;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.black.withOpacity(0.6);

  @override
  String? get barrierLabel => 'Dismiss';

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return builder(context);
  }
}

class _InteractiveTablePage extends StatefulWidget {
  const _InteractiveTablePage({
    required this.tableElement,
    required this.styleSheet,
    required this.buildElement,
  });

  final md.Element tableElement;
  final MarkdownStyleSheet styleSheet;
  final MarkdownTableElementBuilder buildElement;

  @override
  State<_InteractiveTablePage> createState() => _InteractiveTablePageState();
}

class _InteractiveTablePageState extends State<_InteractiveTablePage> {
  final ScrollController _horizontalController = ScrollController();
  final ScrollController _verticalController = ScrollController();
  final ValueNotifier<StickyTableViewport> _viewportNotifier =
      ValueNotifier<StickyTableViewport>(StickyTableViewport.zero);
  final GlobalKey _tableKey = GlobalKey();

  double _scale = 1;
  double _initialScale = 1;
  bool _isScaling = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(_handleScrollChanged);
    _verticalController.addListener(_handleScrollChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateViewport());
  }

  @override
  void dispose() {
    _horizontalController.removeListener(_handleScrollChanged);
    _verticalController.removeListener(_handleScrollChanged);
    _horizontalController.dispose();
    _verticalController.dispose();
    _viewportNotifier.dispose();
    super.dispose();
  }

  void _handleScrollChanged() {
    _updateViewport();
  }

  void _updateViewport() {
    if (!mounted) {
      return;
    }
    final bool hasHorizontal = _horizontalController.hasClients &&
        _horizontalController.position.maxScrollExtent > 0;
    final bool hasVertical = _verticalController.hasClients &&
        _verticalController.position.maxScrollExtent > 0;
    final StickyTableViewport next = StickyTableViewport(
      horizontalOffset:
          _horizontalController.hasClients ? _horizontalController.offset : 0,
      verticalOffset:
          _verticalController.hasClients ? _verticalController.offset : 0,
      viewportWidth: _horizontalController.hasClients
          ? _horizontalController.position.viewportDimension
          : null,
      viewportHeight: _verticalController.hasClients
          ? _verticalController.position.viewportDimension
          : null,
      horizontalGutter:
          hasVertical ? _resolveScrollbarThickness(Axis.vertical) : 0,
      verticalGutter:
          hasHorizontal ? _resolveScrollbarThickness(Axis.horizontal) : 0,
    );
    if (_viewportNotifier.value != next) {
      _viewportNotifier.value = next;
    }
  }

  double _resolveScrollbarThickness(Axis axis) {
    final ScrollbarThemeData theme = ScrollbarTheme.of(context);
    final double? themed = theme.thickness?.resolve(const <MaterialState>{});
    if (themed != null) {
      return themed;
    }
    final TargetPlatform platform = Theme.of(context).platform;
    switch (platform) {
      case TargetPlatform.android:
        return 4.0;
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return CupertinoScrollbar.defaultThickness;
      default:
        return 8.0;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canStick =
        _TableSummary.fromElement(widget.tableElement).supportsSticky;
    final MarkdownStyleSheet interactiveSheet = widget.styleSheet.copyWith(
      tableColumnWidth: const _IntrinsicDelegateColumnWidth(),
      textScaler: TextScaler.linear(_scale),
      enableInteractiveTable: false,
    );

    final _TableBuildResult tableResult = _buildTable(interactiveSheet);
    final bool enableStickyHeader =
        canStick && widget.styleSheet.enableStickyTableHeader;
    final bool enableStickyColumn =
        canStick && widget.styleSheet.enableStickyTableColumn;
    final int stickyRows = enableStickyHeader ? 1 : 0;
    final int stickyColumns = enableStickyColumn ? 1 : 0;

    final double stickyColumnMaxFraction =
        widget.styleSheet.interactiveTableStickyColumnMaxViewportFraction;

    final Widget body = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: Semantics(
        label: 'Expanded table view',
        hint: 'Scroll or pinch to explore. Press escape to close.',
        container: true,
        child: canStick && tableResult.table != null
            ? _buildStickyScroll(
                tableResult.table!,
                stickyRows,
                stickyColumns,
                stickyColumnMaxFraction,
              )
            : _buildFallbackScroll(tableResult.widget),
      ),
    );

    return SafeArea(
      child: Shortcuts(
        shortcuts: <LogicalKeySet, Intent>{
          LogicalKeySet(LogicalKeyboardKey.escape): DismissIntent(),
        },
        child: Actions(
          actions: <Type, Action<Intent>>{
            DismissIntent: CallbackAction<DismissIntent>(
              onInvoke: (_) {
                _requestClose();
                return null;
              },
            ),
          },
          child: FocusScope(
            autofocus: true,
            child: Material(
              color: theme.colorScheme.surface,
              child: Column(
                children: [
                  _InteractiveTableHeader(
                    onClose: _requestClose,
                  ),
                  const Divider(height: 1),
                  Expanded(child: body),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _TableBuildResult _buildTable(MarkdownStyleSheet sheet) {
    final List<Widget> built = widget.buildElement(
      widget.tableElement,
      overrideStyleSheet: sheet,
    );
    final Widget widgetResult =
        built.isNotEmpty ? built.first : const SizedBox.shrink();
    final Table? table = widgetResult is Table ? widgetResult : null;
    return _TableBuildResult(table: table, widget: widgetResult);
  }

  Widget _buildFallbackScroll(Widget content) {
    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (ScrollNotification notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: content,
          ),
        ),
      ),
    );
  }

  Widget _buildStickyScroll(
    Table table,
    int stickyRows,
    int stickyColumns,
    double stickyColumnMaxFraction,
  ) {
    final Widget sticky = ValueListenableBuilder<StickyTableViewport>(
      valueListenable: _viewportNotifier,
      child: null,
      builder: (BuildContext context, StickyTableViewport viewport, Widget? _) {
        return StickyTable(
          key: _tableKey,
          children: table.children,
          columnWidths: table.columnWidths,
          defaultColumnWidth: table.defaultColumnWidth,
          textDirection: table.textDirection ?? Directionality.of(context),
          border: table.border,
          defaultVerticalAlignment: table.defaultVerticalAlignment,
          textBaseline: table.textBaseline,
          stickyRowCount: stickyRows,
          stickyColumnCount: stickyColumns,
          viewport: viewport,
          stickyColumnMaxFraction: stickyColumnMaxFraction,
          stickyBackgroundColor: Theme.of(context).colorScheme.surface,
        );
      },
    );

    return Scrollbar(
      controller: _verticalController,
      thumbVisibility: true,
      child: SingleChildScrollView(
        controller: _verticalController,
        scrollDirection: Axis.vertical,
        child: Scrollbar(
          controller: _horizontalController,
          thumbVisibility: true,
          notificationPredicate: (ScrollNotification notification) =>
              notification.metrics.axis == Axis.horizontal,
          child: SingleChildScrollView(
            controller: _horizontalController,
            scrollDirection: Axis.horizontal,
            child: sticky,
          ),
        ),
      ),
    );
  }

  void _handleScaleStart(ScaleStartDetails details) {
    _isScaling = details.pointerCount > 1;
    if (_isScaling) {
      _initialScale = _scale;
    }
  }

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (!_isScaling) {
      return;
    }
    final double nextScale = (_initialScale * details.scale).clamp(1.0, 3.0);
    if ((nextScale - _scale).abs() > 0.001) {
      setState(() {
        _scale = nextScale;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _updateViewport());
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isScaling = false;
  }

  void _requestClose() {
    if (_closing) {
      return;
    }
    _closing = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      Navigator.of(context).maybePop();
      if (mounted) {
        setState(() {
          _closing = false;
        });
      } else {
        _closing = false;
      }
    });
  }
}

class _TableBuildResult {
  const _TableBuildResult({required this.table, required this.widget});

  final Table? table;
  final Widget widget;
}

class _TableSummary {
  _TableSummary({required this.rowCount, required this.columnCount});

  final int rowCount;
  final int columnCount;

  bool get supportsSticky => rowCount > 1 && columnCount > 1;

  factory _TableSummary.fromElement(md.Element element) {
    int rows = 0;
    int maxColumns = 0;

    void collect(md.Node node) {
      if (node is md.Element) {
        if (node.tag == 'tr') {
          rows += 1;
          int columns = 0;
          for (final md.Node child in node.children ?? const <md.Node>[]) {
            if (child is md.Element &&
                (child.tag == 'td' || child.tag == 'th')) {
              columns += 1;
            }
          }
          if (columns > maxColumns) {
            maxColumns = columns;
          }
        } else {
          for (final md.Node child in node.children ?? const <md.Node>[]) {
            collect(child);
          }
        }
      }
    }

    collect(element);

    return _TableSummary(rowCount: rows, columnCount: maxColumns);
  }
}

class _IntrinsicDelegateColumnWidth extends TableColumnWidth {
  const _IntrinsicDelegateColumnWidth();

  static const IntrinsicColumnWidth _delegate = IntrinsicColumnWidth();

  @override
  double minIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      _delegate.minIntrinsicWidth(cells, containerWidth);

  @override
  double maxIntrinsicWidth(Iterable<RenderBox> cells, double containerWidth) =>
      _delegate.maxIntrinsicWidth(cells, containerWidth);

  @override
  double? flex(Iterable<RenderBox> cells) => _delegate.flex(cells);
}

class _InteractiveTableHeader extends StatelessWidget {
  const _InteractiveTableHeader({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Align(
        alignment: Alignment.centerRight,
        child: IconButton(
          icon: const Icon(Icons.close),
          tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
          onPressed: onClose,
        ),
      ),
    );
  }
}
