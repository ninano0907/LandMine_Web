import 'dart:math';
import 'geometry.dart';

/// Lightweight deterministic 2D terrain for the mining map.
class Mountain {
  final Point2 center;
  final double radius;
  const Mountain(this.center, this.radius);
  bool contains(Point2 p) => center.distance(p) < radius;
}

class TerrainMap {
  final double riverY;
  final double riverBend;
  final double riverPhase;
  final List<Mountain> mountains;

  TerrainMap._(this.riverY, this.riverBend, this.riverPhase, this.mountains);

  factory TerrainMap.generate(int seed) {
    final random = Random(seed ^ 0x52AF3);
    // River is north or south of the factory, never through its footprint.
    final north = random.nextBool();
    final riverY = north ? .17 + random.nextDouble() * .09
                         : .74 + random.nextDouble() * .09;
    final bend = .025 + random.nextDouble() * .018;
    final phase = random.nextDouble() * pi * 2;
    final terrain = TerrainMap._(riverY, bend, phase, []);
    for (var i = 0; i < 4; i++) {
      for (var attempt = 0; attempt < 100; attempt++) {
        final center = Point2(
          .12 + random.nextDouble() * .76,
          .10 + random.nextDouble() * .80,
        );
        final mountain = Mountain(center, .095 + random.nextDouble() * .05);
        if (center.distance(MapGeometry.factoryCenter) < .39 ||
            terrain.isRiver(center) ||
            terrain.mountains.any((m) =>
              center.distance(m.center) < mountain.radius + m.radius + .04)) {
          continue;
        }
        terrain.mountains.add(mountain);
        break;
      }
    }
    return terrain;
  }

  double riverCenterY(double x) =>
      riverY + riverBend * sin(x * pi * 3 + riverPhase);

  bool isRiver(Point2 p) => (p.y - riverCenterY(p.x)).abs() < .026;
  bool isMountain(Point2 p) => mountains.any((m) => m.contains(p));
  bool blocked(Point2 p) => isRiver(p) || isMountain(p);

  /// Segment sampling is sufficient for the first playable terrain iteration.
  bool crossesObstacle(Point2 a, Point2 b) {
    final steps = max(12, (a.distance(b) * 100).ceil());
    for (var i = 0; i <= steps; i++) {
      if (blocked(a.towards(b, i / steps))) return true;
    }
    return false;
  }
}
