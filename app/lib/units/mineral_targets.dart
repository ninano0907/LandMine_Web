import 'dart:math';

/// Edge-connected 2x2 rock tiles, stepped along the 40-pixel map grid.
const mineralTargets = <Point<double>>[Point(360, 158), Point(440, 158)];

// The half-size worker can swing its pickaxe from just beside the crystal.
const miningStandOff = 26.0;

/// Stop close to the approaching face of the crystal.
Point<double> miningApproach(Point<double> from, Point<double> mineral) {
  final distance = from.distanceTo(mineral);
  if (distance <= miningStandOff) return from;
  return Point(
    mineral.x + (from.x - mineral.x) / distance * miningStandOff,
    mineral.y + (from.y - mineral.y) / distance * miningStandOff,
  );
}
