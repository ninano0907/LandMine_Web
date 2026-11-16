import 'dart:math';
import '../world/grid_map.dart';

class BuildingSpec {
  const BuildingSpec({
    required this.label,
    required this.width,
    required this.height,
    this.maxHealth = 1500,
    this.defense = 1,
  });
  final String label;
  final int width, height, maxHealth, defense;
}

abstract class Building {
  Building({
    required this.id,
    required this.grid,
    required this.spec,
    required int column,
    required int row,
  }) : area = TileArea(column, row, spec.width, spec.height) {
    if (!grid.place(id, area)) {
      throw StateError('Building footprint is occupied or outside map');
    }
  }
  final String id;
  final GridMap grid;
  final BuildingSpec spec;
  final TileArea area;
  double get left => area.column * grid.tileSize;
  double get top => area.row * grid.tileSize;
  double get width => area.width * grid.tileSize;
  double get height => area.height * grid.tileSize;
  Point<double> get center => Point(left + width / 2, top + height / 2);
  bool contains(Point<double> p) =>
      p.x >= left && p.x < left + width && p.y >= top && p.y < top + height;
}
