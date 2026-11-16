import 'dart:math' as math;

/// World-space movement, independent of maps, combat, and rendering.
class UnitMovement {
  UnitMovement({
    required this.position,
    required this.speed,
    required this.radius,
  }) : assert(speed > 0),
       assert(radius > 0);

  math.Point<double> position;
  final double speed;
  final double radius;
  math.Point<double>? destination;
  double facing = 0;
  double distanceTravelled = 0;
  final _waypoints = <math.Point<double>>[];
  double get remainingDistance {
    var total = 0.0;
    var previous = position;
    for (final point in _waypoints) {
      total += previous.distanceTo(point);
      previous = point;
    }
    return total;
  }

  bool get moving => destination != null;

  void moveTo(math.Point<double> point) => moveAlong([point]);

  void moveAlong(List<math.Point<double>> path) {
    _waypoints
      ..clear()
      ..addAll(path);
    while (_waypoints.isNotEmpty &&
        position.distanceTo(_waypoints.first) < 0.000001) {
      _waypoints.removeAt(0);
    }
    destination = _waypoints.isEmpty ? null : _waypoints.last;
  }

  void stop() {
    destination = null;
    _waypoints.clear();
  }

  void update(double seconds, {double? speedOverride}) {
    final actualSpeed = speedOverride ?? speed;
    if (!seconds.isFinite ||
        seconds <= 0 ||
        destination == null ||
        !actualSpeed.isFinite ||
        actualSpeed <= 0) {
      return;
    }
    var budget = actualSpeed * seconds;
    while (budget > 0 && _waypoints.isNotEmpty) {
      final target = _waypoints.first;
      final distance = position.distanceTo(target);
      if (distance < 0.000001) {
        _waypoints.removeAt(0);
        continue;
      }
      final dx = target.x - position.x, dy = target.y - position.y;
      facing = math.atan2(dy, dx);
      final travel = budget + 1e-8 >= distance ? distance : budget;
      position = travel >= distance
          ? target
          : math.Point(
              position.x + dx / distance * travel,
              position.y + dy / distance * travel,
            );
      distanceTravelled += travel;
      budget -= travel;
      if (travel >= distance) _waypoints.removeAt(0);
    }
    if (_waypoints.isEmpty) destination = null;
  }
}
