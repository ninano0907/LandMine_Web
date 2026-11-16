import 'dart:math';
import 'building.dart';
import '../units/game_unit.dart';
import '../units/unit_kind.dart';
import '../units/upgrades.dart';

class Barracks extends Building {
  Barracks({required super.grid, required super.column, required super.row})
    : super(id: 'barracks', spec: definition);

  static const definition = BuildingSpec(label: '훈련소', width: 4, height: 3);
  static const trainingSeconds = 3.0;
  final _queue = <UnitKind>[];
  double _elapsed = 0;
  List<UnitKind> get queue => List.unmodifiable(_queue);
  double get progress =>
      _queue.isEmpty ? 0 : (_elapsed / trainingSeconds).clamp(0, 1);

  bool enqueue(UnitKind kind) {
    if (kind != UnitKind.soldier && kind != UnitKind.shotgun) return false;
    _queue.add(kind);
    return true;
  }

  GameUnit? update(
    double seconds,
    UnitUpgrades upgrades,
    List<GameUnit> units,
  ) {
    if (_queue.isEmpty || !seconds.isFinite || seconds <= 0) return null;
    _elapsed = min(trainingSeconds, _elapsed + seconds);
    if (_elapsed < trainingSeconds) return null;
    // Exit at the front of the school; wait if every exit position is occupied.
    for (var row = 0; row < 2; row++) {
      for (var column = 0; column < 5; column++) {
        final point = Point(
          left + 12 + column * 30.0,
          top + height + 26 + row * 30.0,
        );
        final recruit = _queue.first.spawn(point, upgrades, grid: grid);
        if (!grid.walkable(point, radius: recruit.radius) ||
            units.any(
              (unit) => unit.alive && unit.position.distanceTo(point) < 28,
            )) {
          continue;
        }
        _queue.removeAt(0);
        _elapsed = 0;
        recruit.facing = pi / 2;
        return recruit;
      }
    }
    return null;
  }
}
