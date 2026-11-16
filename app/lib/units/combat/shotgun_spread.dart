import 'dart:math' as math;
import '../game_unit.dart';

/// A fixed damage budget spread over rays. Each pellet hits only the first unit.
class ShotgunSpread {
  const ShotgunSpread({
    this.pellets = 7,
    this.arc = math.pi / 3,
    this.fullDamageDistance = 35,
    this.minimumDamageFactor = 0.4,
  }) : assert(pellets > 0),
       assert(arc > 0 && arc <= math.pi),
       assert(fullDamageDistance >= 0),
       assert(minimumDamageFactor >= 0 && minimumDamageFactor <= 1);
  final int pellets;
  final double arc, fullDamageDistance, minimumDamageFactor;

  double damageFactor(double distance, double range) {
    if (distance <= fullDamageDistance || range <= fullDamageDistance) return 1;
    final t = ((distance - fullDamageDistance) / (range - fullDamageDistance))
        .clamp(0.0, 1.0);
    return 1 - t * (1 - minimumDamageFactor);
  }

  Map<GameUnit, int> hits(GameUnit shooter, Iterable<GameUnit> targets) {
    final candidates = targets
        .where((unit) => unit.alive && !identical(unit, shooter))
        .toSet();
    final hits = <GameUnit, int>{};
    final range = shooter.stats.attackRange;
    for (var i = 0; i < pellets; i++) {
      final angle =
          shooter.facing +
          (pellets == 1 ? 0 : -arc / 2 + i * arc / (pellets - 1));
      final ux = math.cos(angle), uy = math.sin(angle);
      GameUnit? nearest;
      var nearestDistance = range + 1e-9;
      for (final unit in candidates) {
        final dx = unit.position.x - shooter.position.x;
        final dy = unit.position.y - shooter.position.y;
        final projection = dx * ux + dy * uy;
        final discriminant =
            unit.radius * unit.radius -
            (dx * dx + dy * dy - projection * projection);
        if (discriminant < 0) continue;
        final root = math.sqrt(discriminant);
        if (projection + root < 0) continue;
        final entry = math.max(0.0, projection - root);
        if (entry >= nearestDistance) continue;
        if (shooter.grid != null &&
            !shooter.grid!.clearSegment(
              shooter.position,
              unit.position,
              radius: 0,
            )) {
          continue;
        }
        nearestDistance = entry;
        nearest = unit;
      }
      if (nearest == null) continue;
      // Integer allocation guarantees pellets can never create extra raw damage.
      final budget =
          shooter.attackPower ~/ pellets +
          (i < shooter.attackPower % pellets ? 1 : 0);
      final factor = damageFactor(
        shooter.position.distanceTo(nearest.position),
        range,
      );
      final damage = (budget * factor).floor();
      if (damage > 0) {
        hits.update(nearest, (value) => value + damage, ifAbsent: () => damage);
      }
    }
    return hits;
  }
}
