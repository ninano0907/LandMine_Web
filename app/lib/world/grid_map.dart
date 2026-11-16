import 'dart:math';

class TileArea {
  const TileArea(this.column, this.row, this.width, this.height);
  final int column, row, width, height;
  Iterable<Point<int>> get cells sync* {
    for (var y = row; y < row + height; y++) {
      for (var x = column; x < column + width; x++) {
        yield Point(x, y);
      }
    }
  }
}

/// Logical square tiles; artwork is independent of occupied cells.
class GridMap {
  GridMap({required this.columns, required this.rows, this.tileSize = 40});
  final int columns, rows;
  final double tileSize;
  final _areas = <String, TileArea>{};
  final _owners = <Point<int>, String>{};
  double get width => columns * tileSize;
  double get height => rows * tileSize;
  int get occupiedCells => _owners.length;

  bool canPlace(TileArea area) =>
      area.width > 0 &&
      area.height > 0 &&
      area.column >= 0 &&
      area.row >= 0 &&
      area.column + area.width <= columns &&
      area.row + area.height <= rows &&
      area.cells.every((cell) => !_owners.containsKey(cell));

  bool place(String id, TileArea area) {
    if (_areas.containsKey(id) || !canPlace(area)) return false;
    _areas[id] = area;
    for (final cell in area.cells) {
      _owners[cell] = id;
    }
    return true;
  }

  void remove(String id) {
    final area = _areas.remove(id);
    if (area != null) {
      for (final cell in area.cells) {
        _owners.remove(cell);
      }
    }
  }

  bool walkable(Point<double> point, {double radius = 16}) {
    if (point.x < radius ||
        point.y < radius ||
        point.x > width - radius ||
        point.y > height - radius) {
      return false;
    }
    for (final area in _areas.values) {
      if (point.x > area.column * tileSize - radius &&
          point.x < (area.column + area.width) * tileSize + radius &&
          point.y > area.row * tileSize - radius &&
          point.y < (area.row + area.height) * tileSize + radius) {
        return false;
      }
    }
    return true;
  }

  bool clearSegment(Point<double> a, Point<double> b, {double radius = 16}) {
    final steps = max(1, (a.distanceTo(b) / 4).ceil());
    for (var i = 0; i <= steps; i++) {
      final t = i / steps;
      if (!walkable(
        Point(a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t),
        radius: radius,
      )) {
        return false;
      }
    }
    return true;
  }

  /// A* routes around occupied buildings with unit clearance, including corners.
  List<Point<double>> route(
    Point<double> from,
    Point<double> to, {
    double radius = 16,
  }) {
    if (!walkable(from, radius: radius) || !walkable(to, radius: radius)) {
      return [];
    }
    if (clearSegment(from, to, radius: radius)) return [to];
    Point<double> center(int id) =>
        Point((id % columns + .5) * tileSize, (id ~/ columns + .5) * tileSize);
    int? connection(Point<double> point) {
      int? best;
      var distance = double.infinity;
      for (var id = 0; id < columns * rows; id++) {
        final p = center(id);
        final d = p.distanceTo(point);
        if (d < distance && clearSegment(point, p, radius: radius)) {
          best = id;
          distance = d;
        }
      }
      return best;
    }

    final start = connection(from), goal = connection(to);
    if (start == null || goal == null) return [];
    final costs = <int, double>{start: 0};
    final parents = <int, int>{};
    final open = <int>[start], closed = <int>{};
    while (open.isNotEmpty) {
      open.sort(
        (a, b) => (costs[a]! + center(a).distanceTo(to)).compareTo(
          costs[b]! + center(b).distanceTo(to),
        ),
      );
      final current = open.removeAt(0);
      if (current == goal) {
        final reverse = <Point<double>>[to, center(goal)];
        var cursor = goal;
        while (cursor != start) {
          cursor = parents[cursor]!;
          reverse.add(center(cursor));
        }
        return reverse.reversed.toList();
      }
      if (!closed.add(current)) continue;
      final x = current % columns, y = current ~/ columns;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (dx == 0 && dy == 0) continue;
          final nx = x + dx, ny = y + dy;
          if (nx < 0 || nx >= columns || ny < 0 || ny >= rows) continue;
          final next = ny * columns + nx;
          if (closed.contains(next) ||
              !clearSegment(center(current), center(next), radius: radius)) {
            continue;
          }
          final cost =
              costs[current]! + center(current).distanceTo(center(next));
          if (cost >= (costs[next] ?? double.infinity)) continue;
          costs[next] = cost;
          parents[next] = current;
          if (!open.contains(next)) open.add(next);
        }
      }
    }
    return [];
  }
}
