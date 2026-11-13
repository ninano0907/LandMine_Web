import 'dart:math';

class MapGeometry {
  static const aspect = 2.5, scale = 2.0;
  static const factoryCenter = Point2(.5, .5);
}

class Point2 {
  final double x, y;
  const Point2(this.x, this.y);
  double distance(Point2 other) =>
      sqrt(pow((x - other.x) * MapGeometry.aspect, 2) + pow(y - other.y, 2)) *
      MapGeometry.scale;
  Point2 towards(Point2 other, double t) =>
      Point2(x + (other.x - x) * t, y + (other.y - y) * t);
}

bool segmentsConflict(Point2 a, Point2 b, Point2 c, Point2 d) {
  const e = 1e-9;
  double cross(Point2 p, Point2 q, Point2 r) =>
      (q.x - p.x) * (r.y - p.y) - (q.y - p.y) * (r.x - p.x);
  int sign(double n) => n.abs() <= e
      ? 0
      : n > 0
      ? 1
      : -1;
  final o1 = cross(a, b, c),
      o2 = cross(a, b, d),
      o3 = cross(c, d, a),
      o4 = cross(c, d, b);
  final shared = a.distance(c) < e || a.distance(d) < e;
  if ([o1, o2, o3, o4].every((n) => n.abs() <= e)) {
    final useX = (b.x - a.x).abs() >= (b.y - a.y).abs();
    final av = useX ? a.x : a.y,
        bv = useX ? b.x : b.y,
        cv = useX ? c.x : c.y,
        dv = useX ? d.x : d.y;
    final overlap =
        min(max(av, bv), max(cv, dv)) - max(min(av, bv), min(cv, dv));
    return overlap > e || (overlap >= -e && !shared);
  }
  final bounds =
      max(min(a.x, b.x), min(c.x, d.x)) <=
          min(max(a.x, b.x), max(c.x, d.x)) + e &&
      max(min(a.y, b.y), min(c.y, d.y)) <=
          min(max(a.y, b.y), max(c.y, d.y)) + e;
  return bounds &&
      sign(o1) * sign(o2) <= 0 &&
      sign(o3) * sign(o4) <= 0 &&
      !shared;
}

/// A rail cannot enter the solid factory footprint, including unfinished rails.
bool crossesFactory(Point2 a, Point2 b) {
  const xmin = .4815, xmax = .5185, ymin = .4705, ymax = .5295;
  var low = 0.0, high = 1.0;
  for (final axis in [
    (a.x, b.x - a.x, xmin, xmax),
    (a.y, b.y - a.y, ymin, ymax),
  ]) {
    if (axis.$2.abs() < 1e-12) {
      if (axis.$1 < axis.$3 || axis.$1 > axis.$4) return false;
      continue;
    }
    var near = (axis.$3 - axis.$1) / axis.$2,
        far = (axis.$4 - axis.$1) / axis.$2;
    if (near > far) {
      final temp = near;
      near = far;
      far = temp;
    }
    low = max(low, near);
    high = min(high, far);
    if (low > high) return false;
  }
  return high >= low;
}
