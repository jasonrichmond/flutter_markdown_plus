import 'dart:collection';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Describes the scroll and viewport state used to paint sticky regions.
@immutable
class StickyTableViewport {
  const StickyTableViewport({
    this.horizontalOffset = 0,
    this.verticalOffset = 0,
    this.viewportWidth,
    this.viewportHeight,
    this.horizontalGutter = 0,
    this.verticalGutter = 0,
  });

  final double horizontalOffset;
  final double verticalOffset;
  final double? viewportWidth;
  final double? viewportHeight;
  final double horizontalGutter;
  final double verticalGutter;

  static const StickyTableViewport zero = StickyTableViewport();

  StickyTableViewport copyWith({
    double? horizontalOffset,
    double? verticalOffset,
    double? viewportWidth,
    double? viewportHeight,
    double? horizontalGutter,
    double? verticalGutter,
  }) {
    return StickyTableViewport(
      horizontalOffset: horizontalOffset ?? this.horizontalOffset,
      verticalOffset: verticalOffset ?? this.verticalOffset,
      viewportWidth: viewportWidth ?? this.viewportWidth,
      viewportHeight: viewportHeight ?? this.viewportHeight,
      horizontalGutter: horizontalGutter ?? this.horizontalGutter,
      verticalGutter: verticalGutter ?? this.verticalGutter,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is StickyTableViewport &&
        other.horizontalOffset == horizontalOffset &&
        other.verticalOffset == verticalOffset &&
        other.viewportWidth == viewportWidth &&
        other.viewportHeight == viewportHeight &&
        other.horizontalGutter == horizontalGutter &&
        other.verticalGutter == verticalGutter;
  }

  @override
  int get hashCode => Object.hash(
        horizontalOffset,
        verticalOffset,
        viewportWidth,
        viewportHeight,
        horizontalGutter,
        verticalGutter,
      );

  @override
  String toString() {
    return 'StickyTableViewport(horizontalOffset: $horizontalOffset, '
        'verticalOffset: $verticalOffset, viewportWidth: $viewportWidth, '
        'viewportHeight: $viewportHeight, horizontalGutter: $horizontalGutter, '
        'verticalGutter: $verticalGutter)';
  }
}

/// A table widget that keeps the leading rows and columns pinned while
/// scrolling, without duplicating subtree widgets.
class StickyTable extends RenderObjectWidget {
  StickyTable({
    super.key,
    this.children = const <TableRow>[],
    this.columnWidths,
    this.defaultColumnWidth = const FlexColumnWidth(),
    this.textDirection,
    this.border,
    this.defaultVerticalAlignment = TableCellVerticalAlignment.top,
    this.textBaseline,
    this.stickyRowCount = 0,
    this.stickyColumnCount = 0,
    this.viewport = StickyTableViewport.zero,
    this.stickyColumnMaxFraction = 1.0,
    this.stickyBackgroundColor,
  })  : assert(children.isEmpty || children.first.children.isNotEmpty),
        assert(
          children.isEmpty ||
              !children.any((TableRow row) =>
                  row.children.length != children.first.children.length),
          'Every TableRow in a StickyTable must have the same number of children.',
        ),
        assert(
          textBaseline != null ||
              defaultVerticalAlignment != TableCellVerticalAlignment.baseline,
          'A textBaseline must be provided when using TableCellVerticalAlignment.baseline.',
        ),
        assert(stickyColumnMaxFraction >= 0),
        _rowDecorations = children.any((TableRow row) => row.decoration != null)
            ? children
                .map<Decoration?>((TableRow row) => row.decoration)
                .toList(growable: false)
            : null;

  final List<TableRow> children;
  final Map<int, TableColumnWidth>? columnWidths;
  final TableColumnWidth defaultColumnWidth;
  final TextDirection? textDirection;
  final TableBorder? border;
  final TableCellVerticalAlignment defaultVerticalAlignment;
  final TextBaseline? textBaseline;
  final int stickyRowCount;
  final int stickyColumnCount;
  final StickyTableViewport viewport;
  final double stickyColumnMaxFraction;
  final Color? stickyBackgroundColor;

  final List<Decoration?>? _rowDecorations;

  @override
  RenderObjectElement createElement() => _StickyTableElement(this);

  @override
  RenderStickyTable createRenderObject(BuildContext context) {
    assert(debugCheckHasDirectionality(context));
    return RenderStickyTable(
      columns: children.isNotEmpty ? children.first.children.length : 0,
      rows: children.length,
      columnWidths: columnWidths,
      defaultColumnWidth: defaultColumnWidth,
      textDirection: textDirection ?? Directionality.of(context),
      border: border,
      rowDecorations: _rowDecorations,
      configuration: createLocalImageConfiguration(context),
      defaultVerticalAlignment: defaultVerticalAlignment,
      textBaseline: textBaseline,
      stickyRowCount: stickyRowCount,
      stickyColumnCount: stickyColumnCount,
      viewport: viewport,
      stickyColumnMaxFraction: stickyColumnMaxFraction,
      stickyBackgroundColor: stickyBackgroundColor,
    );
  }

  @override
  void updateRenderObject(
      BuildContext context, RenderStickyTable renderObject) {
    assert(debugCheckHasDirectionality(context));
    assert(renderObject.columns ==
        (children.isNotEmpty ? children.first.children.length : 0));
    assert(renderObject.rows == children.length);
    renderObject
      ..columnWidths = columnWidths
      ..defaultColumnWidth = defaultColumnWidth
      ..textDirection = textDirection ?? Directionality.of(context)
      ..border = border
      ..rowDecorations = _rowDecorations
      ..configuration = createLocalImageConfiguration(context)
      ..defaultVerticalAlignment = defaultVerticalAlignment
      ..textBaseline = textBaseline
      ..stickyRowCount = stickyRowCount
      ..stickyColumnCount = stickyColumnCount
      ..viewport = viewport
      ..stickyColumnMaxFraction = stickyColumnMaxFraction
      ..stickyBackgroundColor = stickyBackgroundColor;
  }

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('rows', children.length));
    properties.add(IntProperty(
      'columns',
      children.isNotEmpty ? children.first.children.length : 0,
    ));
    properties
        .add(IntProperty('stickyRowCount', stickyRowCount, defaultValue: 0));
    properties.add(
        IntProperty('stickyColumnCount', stickyColumnCount, defaultValue: 0));
    properties
        .add(DiagnosticsProperty<StickyTableViewport>('viewport', viewport));
    properties.add(DoubleProperty(
      'stickyColumnMaxFraction',
      stickyColumnMaxFraction,
      defaultValue: 1.0,
    ));
    properties.add(
      ColorProperty(
        'stickyBackgroundColor',
        stickyBackgroundColor,
        defaultValue: null,
      ),
    );
  }
}

class _StickyTableElementRow {
  const _StickyTableElementRow({this.key, required this.children});

  final LocalKey? key;
  final List<Element> children;
}

@immutable
class _StickyTableSlot with Diagnosticable {
  const _StickyTableSlot(this.column, this.row);

  final int column;
  final int row;

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is _StickyTableSlot &&
        column == other.column &&
        row == other.row;
  }

  @override
  int get hashCode => Object.hash(column, row);

  @override
  void debugFillProperties(DiagnosticPropertiesBuilder properties) {
    super.debugFillProperties(properties);
    properties.add(IntProperty('x', column));
    properties.add(IntProperty('y', row));
  }
}

class _StickyTableElement extends RenderObjectElement {
  _StickyTableElement(StickyTable super.widget);

  @override
  StickyTable get widget => super.widget as StickyTable;

  @override
  RenderStickyTable get renderObject => super.renderObject as RenderStickyTable;

  List<_StickyTableElementRow> _children = const <_StickyTableElementRow>[];
  bool _doingMountOrUpdate = false;
  final Set<Element> _forgottenChildren = HashSet<Element>();

  @override
  void mount(Element? parent, Object? newSlot) {
    assert(!_doingMountOrUpdate);
    _doingMountOrUpdate = true;
    super.mount(parent, newSlot);
    int rowIndex = -1;
    _children = widget.children.map<_StickyTableElementRow>((TableRow row) {
      int columnIndex = 0;
      rowIndex += 1;
      return _StickyTableElementRow(
        key: row.key,
        children: row.children.map<Element>((Widget child) {
          return inflateWidget(
              child, _StickyTableSlot(columnIndex++, rowIndex));
        }).toList(growable: false),
      );
    }).toList(growable: false);
    _updateRenderObjectChildren();
    assert(_doingMountOrUpdate);
    _doingMountOrUpdate = false;
  }

  @override
  void update(covariant StickyTable newWidget) {
    assert(!_doingMountOrUpdate);
    _doingMountOrUpdate = true;
    final Map<LocalKey, List<Element>> oldKeyedRows =
        <LocalKey, List<Element>>{};
    for (final _StickyTableElementRow row in _children) {
      if (row.key != null) {
        oldKeyedRows[row.key!] = row.children;
      }
    }
    final Iterator<_StickyTableElementRow> oldUnkeyedRows = _children
        .where((_StickyTableElementRow row) => row.key == null)
        .iterator;
    final List<_StickyTableElementRow> newChildren = <_StickyTableElementRow>[];
    final Set<List<Element>> taken = <List<Element>>{};
    for (int rowIndex = 0; rowIndex < newWidget.children.length; rowIndex++) {
      final TableRow row = newWidget.children[rowIndex];
      List<Element> oldChildren;
      if (row.key != null && oldKeyedRows.containsKey(row.key)) {
        oldChildren = oldKeyedRows[row.key]!;
        taken.add(oldChildren);
      } else if (row.key == null && oldUnkeyedRows.moveNext()) {
        oldChildren = oldUnkeyedRows.current.children;
      } else {
        oldChildren = const <Element>[];
      }
      final List<_StickyTableSlot> slots = List<_StickyTableSlot>.generate(
        row.children.length,
        (int columnIndex) => _StickyTableSlot(columnIndex, rowIndex),
      );
      newChildren.add(
        _StickyTableElementRow(
          key: row.key,
          children: updateChildren(
            oldChildren,
            row.children,
            forgottenChildren: _forgottenChildren,
            slots: slots,
          ),
        ),
      );
    }
    while (oldUnkeyedRows.moveNext()) {
      updateChildren(
        oldUnkeyedRows.current.children,
        const <Widget>[],
        forgottenChildren: _forgottenChildren,
      );
    }
    for (final List<Element> oldChildren in oldKeyedRows.values.where(
      (List<Element> list) => !taken.contains(list),
    )) {
      updateChildren(oldChildren, const <Widget>[],
          forgottenChildren: _forgottenChildren);
    }

    _children = newChildren;
    _updateRenderObjectChildren();
    _forgottenChildren.clear();
    super.update(newWidget);
    assert(widget == newWidget);
    assert(_doingMountOrUpdate);
    _doingMountOrUpdate = false;
  }

  void _updateRenderObjectChildren() {
    renderObject.setFlatChildren(
      _children.isNotEmpty ? _children[0].children.length : 0,
      _children.expand<RenderBox>((_StickyTableElementRow row) {
        return row.children.map<RenderBox>((Element child) {
          return child.renderObject as RenderBox;
        });
      }).toList(growable: false),
    );
  }

  @override
  void visitChildren(ElementVisitor visitor) {
    for (final Element child in _children
        .expand<Element>((_StickyTableElementRow row) => row.children)) {
      if (!_forgottenChildren.contains(child)) {
        visitor(child);
      }
    }
  }

  @override
  bool forgetChild(Element child) {
    _forgottenChildren.add(child);
    super.forgetChild(child);
    return true;
  }

  @override
  void insertRenderObjectChild(RenderBox child, _StickyTableSlot slot) {
    renderObject.setChild(slot.column, slot.row, child);
  }

  @override
  void moveRenderObjectChild(
      RenderBox child, _StickyTableSlot oldSlot, _StickyTableSlot newSlot) {
    // Children are rearranged in [_updateRenderObjectChildren].
  }

  @override
  void removeRenderObjectChild(RenderBox child, _StickyTableSlot slot) {
    renderObject.setChild(slot.column, slot.row, null);
  }
}

class RenderStickyTable extends RenderTable {
  RenderStickyTable({
    required super.columns,
    required super.rows,
    super.columnWidths,
    super.defaultColumnWidth,
    required super.textDirection,
    super.border,
    super.rowDecorations,
    super.configuration,
    super.defaultVerticalAlignment,
    super.textBaseline,
    int stickyRowCount = 0,
    int stickyColumnCount = 0,
    StickyTableViewport viewport = StickyTableViewport.zero,
    double stickyColumnMaxFraction = 1.0,
    Color? stickyBackgroundColor,
  })  : _stickyRowCount = stickyRowCount,
        _stickyColumnCount = stickyColumnCount,
        _viewport = viewport,
        _stickyColumnMaxFraction = stickyColumnMaxFraction,
        _stickyBackgroundColor = stickyBackgroundColor;

  int _stickyRowCount;
  int get stickyRowCount => _stickyRowCount;
  set stickyRowCount(int value) {
    value = math.max(0, value);
    if (value == _stickyRowCount) {
      return;
    }
    _stickyRowCount = value;
    markNeedsPaint();
  }

  int _stickyColumnCount;
  int get stickyColumnCount => _stickyColumnCount;
  set stickyColumnCount(int value) {
    value = math.max(0, value);
    if (value == _stickyColumnCount) {
      return;
    }
    _stickyColumnCount = value;
    markNeedsPaint();
  }

  StickyTableViewport _viewport;
  StickyTableViewport get viewport => _viewport;
  set viewport(StickyTableViewport value) {
    if (_viewport == value) {
      return;
    }
    _viewport = value;
    markNeedsPaint();
  }

  double _stickyColumnMaxFraction;
  double get stickyColumnMaxFraction => _stickyColumnMaxFraction;
  set stickyColumnMaxFraction(double value) {
    if (!value.isFinite || value.isNaN) {
      value = 1.0;
    } else {
      value = value.clamp(0.0, 1.0);
    }
    if (value == _stickyColumnMaxFraction) {
      return;
    }
    _stickyColumnMaxFraction = value;
    markNeedsPaint();
  }

  Color? _stickyBackgroundColor;
  Color? get stickyBackgroundColor => _stickyBackgroundColor;
  set stickyBackgroundColor(Color? value) {
    if (value == _stickyBackgroundColor) {
      return;
    }
    _stickyBackgroundColor = value;
    markNeedsPaint();
  }

  bool get _hasStickyRows => _stickyRowCount > 0 && rows > 0;
  bool get _hasStickyColumns => _stickyColumnCount > 0 && columns > 0;

  List<List<RenderBox?>> _collectChildrenGrid() {
    final List<List<RenderBox?>> grid = List<List<RenderBox?>>.generate(
      rows,
      (_) => List<RenderBox?>.filled(columns, null),
    );
    visitChildren((RenderObject child) {
      final RenderBox box = child as RenderBox;
      final TableCellParentData parentData =
          box.parentData! as TableCellParentData;
      final int x = parentData.x ?? 0;
      final int y = parentData.y ?? 0;
      if (y >= 0 && y < rows && x >= 0 && x < columns) {
        grid[y][x] = box;
      }
    });
    return grid;
  }

  double _rowExtent(int stickyRows) {
    double extent = 0;
    for (int row = 0; row < stickyRows && row < rows; row += 1) {
      final Rect box = getRowBox(row);
      extent += box.height;
    }
    return extent;
  }

  (double left, double right)? _columnBounds(
      int column, List<List<RenderBox?>> grid) {
    for (int row = 0; row < rows; row += 1) {
      final RenderBox? child = grid[row][column];
      if (child != null) {
        final TableCellParentData parentData =
            child.parentData! as TableCellParentData;
        final double left = parentData.offset.dx;
        final double right = parentData.offset.dx + child.size.width;
        return (left, right);
      }
    }
    return null;
  }

  void _paintStickyRows(
    PaintingContext context,
    Offset offset,
    List<List<RenderBox?>> grid,
    int stickyRows,
    int stickyColumns,
    double verticalOffset,
    double clipWidth,
    double clipHeight,
  ) {
    _paintBackgroundRect(context, offset, clipWidth, clipHeight);
    for (int row = 0; row < stickyRows; row += 1) {
      for (int column = stickyColumns; column < columns; column += 1) {
        final RenderBox? child = grid[row][column];
        if (child == null) {
          continue;
        }
        final TableCellParentData parentData =
            child.parentData! as TableCellParentData;
        Offset childOffset = parentData.offset + offset;
        if (verticalOffset != 0) {
          childOffset = childOffset.translate(0, verticalOffset);
        }
        _paintChildWithBackground(context, child, childOffset);
      }
    }
  }

  void _paintStickyColumns(
    PaintingContext context,
    Offset offset,
    List<List<RenderBox?>> grid,
    int stickyRows,
    int stickyColumns,
    double horizontalOffset,
    double clipWidth,
    double clipHeight,
  ) {
    _paintBackgroundRect(context, offset, clipWidth, clipHeight);
    for (int column = 0; column < stickyColumns; column += 1) {
      for (int row = stickyRows; row < rows; row += 1) {
        final RenderBox? child = grid[row][column];
        if (child == null) {
          continue;
        }
        final TableCellParentData parentData =
            child.parentData! as TableCellParentData;
        Offset childOffset = parentData.offset + offset;
        if (horizontalOffset != 0) {
          childOffset = childOffset.translate(horizontalOffset, 0);
        }
        _paintChildWithBackground(context, child, childOffset);
      }
    }
  }

  void _paintStickyIntersection(
    PaintingContext context,
    Offset offset,
    List<List<RenderBox?>> grid,
    int stickyRows,
    int stickyColumns,
    double horizontalOffset,
    double verticalOffset,
    double clipWidth,
    double clipHeight,
  ) {
    _paintBackgroundRect(context, offset, clipWidth, clipHeight);
    for (int row = 0; row < stickyRows; row += 1) {
      for (int column = 0; column < stickyColumns; column += 1) {
        final RenderBox? child = grid[row][column];
        if (child == null) {
          continue;
        }
        final TableCellParentData parentData =
            child.parentData! as TableCellParentData;
        Offset childOffset = parentData.offset + offset;
        if (horizontalOffset != 0) {
          childOffset = childOffset.translate(horizontalOffset, 0);
        }
        if (verticalOffset != 0) {
          childOffset = childOffset.translate(0, verticalOffset);
        }
        _paintChildWithBackground(context, child, childOffset);
      }
    }
  }

  Paint? _backgroundPaint;

  void _paintChildWithBackground(
    PaintingContext context,
    RenderBox child,
    Offset offset,
  ) {
    if (_stickyBackgroundColor != null) {
      _backgroundPaint ??= Paint()..isAntiAlias = false;
      _backgroundPaint!.color = _stickyBackgroundColor!;
      final Rect rect = offset & child.size;
      context.canvas.drawRect(rect, _backgroundPaint!);
    }
    context.paintChild(child, offset);
  }

  void _paintBackgroundRect(
    PaintingContext context,
    Offset offset,
    double width,
    double height,
  ) {
    if (_stickyBackgroundColor == null || width <= 0 || height <= 0) {
      return;
    }
    _backgroundPaint ??= Paint()..isAntiAlias = false;
    _backgroundPaint!.color = _stickyBackgroundColor!;
    context.canvas.drawRect(Rect.fromLTWH(offset.dx, offset.dy, width, height), _backgroundPaint!);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    if ((!_hasStickyRows && !_hasStickyColumns) || columns == 0 || rows == 0) {
      return;
    }

    final List<List<RenderBox?>> grid = _collectChildrenGrid();
    final int stickyRows = math.min(_stickyRowCount, rows);
    final int stickyColumns = math.min(_stickyColumnCount, columns);
    final double verticalOffset = _viewport.verticalOffset;
    final double horizontalOffset = _viewport.horizontalOffset;
    final double viewportWidth = _viewport.viewportWidth ?? size.width;
    final double viewportHeight = _viewport.viewportHeight ?? size.height;
    final double availableWidth =
        math.max(0.0, viewportWidth - _viewport.verticalGutter);
    final double availableHeight =
        math.max(0.0, viewportHeight - _viewport.horizontalGutter);
    final double maxStickyWidth = _stickyColumnMaxFraction <= 0
        ? double.infinity
        : availableWidth * _stickyColumnMaxFraction.clamp(0.0, 1.0);

    if (_hasStickyRows) {
      final double stickyHeight =
          math.min(_rowExtent(stickyRows), availableHeight);
      if (stickyHeight > 0 && availableWidth > 0) {
        final Rect clipRect = Rect.fromLTWH(
          horizontalOffset,
          verticalOffset,
          availableWidth,
          stickyHeight,
        );
        context.pushClipRect(
          needsCompositing,
          offset,
          clipRect,
          (PaintingContext context, Offset clipOffset) {
            _paintStickyRows(context, clipOffset, grid, stickyRows,
                stickyColumns, verticalOffset);
          },
          clipBehavior: Clip.hardEdge,
        );
      }
    }

    if (_hasStickyColumns) {
      final (double left, double right)? bounds =
          _columnBounds(stickyColumns - 1, grid);
      double stickyWidth = bounds == null ? 0 : bounds.$2;
      stickyWidth = math.min(stickyWidth, availableWidth);
      if (maxStickyWidth.isFinite) {
        stickyWidth = math.min(stickyWidth, maxStickyWidth);
      }
      if (stickyWidth > 0 && availableHeight > 0) {
        final Rect clipRect = Rect.fromLTWH(
          horizontalOffset,
          verticalOffset,
          stickyWidth,
          availableHeight,
        );
        context.pushClipRect(
          needsCompositing,
          offset,
          clipRect,
          (PaintingContext context, Offset clipOffset) {
            _paintStickyColumns(context, clipOffset, grid, stickyRows,
                stickyColumns, horizontalOffset);
          },
          clipBehavior: Clip.hardEdge,
        );
      }
    }

    if (_hasStickyRows && _hasStickyColumns) {
      final (double left, double right)? bounds =
          _columnBounds(stickyColumns - 1, grid);
      double stickyWidth = bounds == null ? 0 : bounds.$2;
      stickyWidth = math.min(stickyWidth, math.max(0.0, availableWidth));
      if (maxStickyWidth.isFinite) {
        stickyWidth = math.min(stickyWidth, maxStickyWidth);
      }
      final double stickyHeight =
          math.min(_rowExtent(stickyRows), math.max(0.0, availableHeight));
      if (stickyWidth > 0 && stickyHeight > 0) {
        final Rect clipRect = Rect.fromLTWH(
          horizontalOffset,
          verticalOffset,
          stickyWidth,
          stickyHeight,
        );
        context.pushClipRect(
          needsCompositing,
          offset,
          clipRect,
          (PaintingContext context, Offset clipOffset) {
            _paintStickyIntersection(
              context,
              clipOffset,
              grid,
              stickyRows,
              stickyColumns,
              horizontalOffset,
              verticalOffset,
            );
          },
          clipBehavior: Clip.hardEdge,
        );
      }
    }
  }
}
