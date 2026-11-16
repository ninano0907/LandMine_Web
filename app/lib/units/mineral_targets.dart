import 'dart:math';

/// Fixed targets around the unit lab's starting point, clockwise from east.
const mineralTargets = <Point<double>>[
  Point(630, 250),
  Point(563, 363),
  Point(400, 410),
  Point(237, 363),
  Point(170, 250),
  Point(237, 137),
  Point(400, 90),
  Point(563, 137),
];

/// Stop on the approaching side of a crystal instead of walking inside it.
Point<double> miningApproach(Point<double> from, Point<double> mineral) {
  final distance = from.distanceTo(mineral);
  if (distance <= 58) return from;
  return Point(
    mineral.x + (from.x - mineral.x) / distance * 58,
    mineral.y + (from.y - mineral.y) / distance * 58,
  );
}
