import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:markdown/markdown.dart' as md;

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
  final ValueNotifier<double> _horizontalOffset = ValueNotifier<double>(0);
  final ValueNotifier<double> _verticalOffset = ValueNotifier<double>(0);
  final GlobalKey _tableKey = GlobalKey();

  double _scale = 1;
  double _initialScale = 1;
  bool _isScaling = false;
  bool _scheduledMeasurement = false;

  double? _tableWidth;
  double? _tableHeight;
  double? _headerHeight;
  double? _firstColumnWidth;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _horizontalController.addListener(
      () => _horizontalOffset.value = _horizontalController.offset,
    );
    _verticalController.addListener(
      () => _verticalOffset.value = _verticalController.offset,
    );
  }

  @override
  void dispose() {
    _horizontalController.dispose();
    _verticalController.dispose();
    _horizontalOffset.dispose();
    _verticalOffset.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bool canStick =
        _TableSummary.fromElement(widget.tableElement).supportsSticky;
    final MarkdownStyleSheet interactiveSheet = widget.styleSheet.copyWith(
      tableColumnWidth: const IntrinsicColumnWidth(),
      textScaler: TextScaler.linear(_scale),
      enableInteractiveTable: false,
    );

    final Widget bodyScroll = _buildBodyScroll(interactiveSheet);
    final List<Widget> overlays = <Widget>[
      if (canStick) ..._buildStickyOverlays(interactiveSheet),
    ];

    if (canStick) {
      _scheduleMeasurement();
    }

    final Widget content = GestureDetector(
      behavior: HitTestBehavior.translucent,
      onScaleStart: _handleScaleStart,
      onScaleUpdate: _handleScaleUpdate,
      onScaleEnd: _handleScaleEnd,
      child: Stack(
        fit: StackFit.expand,
        clipBehavior: Clip.hardEdge,
        children: <Widget>[
          Positioned.fill(child: bodyScroll),
          ...overlays,
        ],
      ),
    );

    return SafeArea(
      child: Material(
        color: theme.colorScheme.surface,
        child: Column(
          children: [
            _InteractiveTableHeader(
              onClose: _requestClose,
            ),
            const Divider(height: 1),
            Expanded(child: content),
          ],
        ),
      ),
    );
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

  Widget _buildBodyScroll(MarkdownStyleSheet sheet) {
    final Widget tableWidget = _buildFullTable(
      sheet,
      key: _tableKey,
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
            child: tableWidget,
          ),
        ),
      ),
    );
  }

  List<Widget> _buildStickyOverlays(MarkdownStyleSheet sheet) {
    if (_tableWidth == null ||
        _tableHeight == null ||
        _headerHeight == null ||
        _firstColumnWidth == null ||
        _headerHeight == 0 ||
        _firstColumnWidth == 0) {
      return const <Widget>[];
    }

    final Color overlayColor = Theme.of(context).colorScheme.surface;

    final Widget headerOverlay = Positioned(
      top: 0,
      left: 0,
      right: 0,
      height: _headerHeight!,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: _horizontalOffset,
          builder: (BuildContext context, double offset, Widget? child) {
            return Transform.translate(
              offset: Offset(-offset, 0),
              child: child,
            );
          },
          child: ClipRect(
            clipper: _HeaderClipper(height: _headerHeight!),
            child: DecoratedBox(
              decoration: BoxDecoration(color: overlayColor),
              child: SizedBox(
                width: _tableWidth!,
                height: _headerHeight!,
                child: _buildFullTable(sheet),
              ),
            ),
          ),
        ),
      ),
    );

    final Widget leftColumnOverlay = Positioned(
      top: _headerHeight!,
      left: 0,
      bottom: 0,
      width: _firstColumnWidth!,
      child: IgnorePointer(
        child: ValueListenableBuilder<double>(
          valueListenable: _verticalOffset,
          builder: (BuildContext context, double offset, Widget? child) {
            return Transform.translate(
              offset: Offset(0, -offset),
              child: child,
            );
          },
          child: ClipRect(
            clipper: _LeftColumnClipper(
              width: _firstColumnWidth!,
            ),
            child: DecoratedBox(
              decoration: BoxDecoration(color: overlayColor),
              child: Transform.translate(
                offset: Offset(0, -_headerHeight!),
                child: SizedBox(
                  width: _tableWidth!,
                  height: _tableHeight!,
                  child: _buildFullTable(sheet),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    return <Widget>[
      leftColumnOverlay,
      headerOverlay,
    ];
  }

  Widget _buildFullTable(
    MarkdownStyleSheet sheet, {
    Key? key,
  }) {
    final List<Widget> built = widget.buildElement(
      widget.tableElement,
      overrideStyleSheet: sheet,
    );
    final Widget table =
        built.isNotEmpty ? built.first : const SizedBox.shrink();
    return KeyedSubtree(
      key: key,
      child: table,
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
    final double nextScale =
        (_initialScale * details.scale).clamp(1.0, 3.0) as double;
    if ((nextScale - _scale).abs() > 0.001) {
      setState(() {
        _scale = nextScale;
      });
      _scheduleMeasurement();
    }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
    _isScaling = false;
  }

  void _scheduleMeasurement() {
    if (_scheduledMeasurement) {
      return;
    }
    _scheduledMeasurement = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduledMeasurement = false;
      _updateMeasurements();
    });
  }

  void _updateMeasurements() {
    final RenderObject? renderObject =
        _tableKey.currentContext?.findRenderObject();
    if (renderObject == null) {
      return;
    }

    final RenderTable? table = _locateRenderTable(renderObject);
    if (table == null) {
      return;
    }
    final double newTableWidth = table.size.width;
    final double newTableHeight = table.size.height;
    final double newHeaderHeight =
        table.rows > 0 ? table.getRowBox(0).height : 0;
    double newFirstColumnWidth = 0;

    table.visitChildren((RenderObject child) {
      if (child is! RenderBox) {
        return;
      }
      final TableCellParentData parentData =
          child.parentData! as TableCellParentData;
      if (parentData.x == 0) {
        newFirstColumnWidth = math.max(newFirstColumnWidth, child.size.width);
      }
    });

    bool changed = false;

    void updateValue(
        double? current, double next, void Function(double) setter) {
      if (current == null || (current - next).abs() > 0.5) {
        setter(next);
        changed = true;
      }
    }

    updateValue(_tableWidth, newTableWidth, (double value) {
      _tableWidth = value;
    });
    updateValue(_tableHeight, newTableHeight, (double value) {
      _tableHeight = value;
    });
    updateValue(_headerHeight, newHeaderHeight, (double value) {
      _headerHeight = value;
    });
    updateValue(_firstColumnWidth, newFirstColumnWidth, (double value) {
      _firstColumnWidth = value;
    });

    if (changed && mounted) {
      setState(() {});
    }
  }

  RenderTable? _locateRenderTable(RenderObject node) {
    if (node is RenderTable) {
      return node;
    }
    if (node is RenderObjectWithChildMixin<RenderObject>) {
      final RenderObject? child = node.child;
      final RenderTable? result =
          child == null ? null : _locateRenderTable(child);
      if (result != null) {
        return result;
      }
    }
    if (node is ContainerRenderObjectMixin<RenderObject,
        ContainerParentDataMixin<RenderObject>>) {
      RenderObject? child = node.firstChild;
      while (child != null) {
        final RenderTable? result = _locateRenderTable(child);
        if (result != null) {
          return result;
        }
        final ContainerParentDataMixin<RenderObject>? parentData =
            child.parentData as ContainerParentDataMixin<RenderObject>?;
        child = parentData?.nextSibling;
      }
    }
    return null;
  }
}

class _HeaderClipper extends CustomClipper<Rect> {
  _HeaderClipper({required this.height});

  final double height;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTWH(0, 0, size.width, math.min(height, size.height));

  @override
  bool shouldReclip(_HeaderClipper oldClipper) =>
      (oldClipper.height - height).abs() > 0.5;
}

class _LeftColumnClipper extends CustomClipper<Rect> {
  _LeftColumnClipper({
    required this.width,
  });

  final double width;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
        0,
        0,
        math.min(width, size.width),
        size.height,
      );

  @override
  bool shouldReclip(_LeftColumnClipper oldClipper) =>
      (oldClipper.width - width).abs() > 0.5;
}

class _TableSummary {
  _TableSummary({
    required this.rowCount,
    required this.columnCount,
  });

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
