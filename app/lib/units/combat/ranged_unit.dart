import '../game_unit.dart';

/// Shared aiming, automatic fire and shot events for ranged characters.
abstract class RangedUnit extends GameUnit {
  RangedUnit({
    required super.position,
    required super.stats,
    required super.upgrades,
    super.grid,
  });

  GameUnit? _target;
  List<GameUnit> _nearby = const [];
  List<GameUnit> _shotCandidates = const [];
  int _shotsFired = 0;
  int get shotsFired => _shotsFired;
  GameUnit? get attackTarget => _target;
  Map<GameUnit, int> lastHits = const {};
  @override
  bool get needsUpdate => super.needsUpdate || (alive && _target != null);

  bool fireAt(GameUnit target, {Iterable<GameUnit> nearby = const []}) {
    if (!alive ||
        !target.alive ||
        identical(target, this) ||
        position.distanceTo(target.position) > stats.attackRange) {
      return false;
    }
    if (grid != null &&
        !grid!.clearSegment(position, target.position, radius: 0)) {
      return false;
    }
    stop();
    _target = target;
    _nearby = List.unmodifiable(nearby);
    attemptShot();
    return true;
  }

  void attemptShot() {
    final target = _target;
    if (target == null) return;
    if (!target.alive ||
        position.distanceTo(target.position) > stats.attackRange ||
        (grid != null &&
            !grid!.clearSegment(position, target.position, radius: 0))) {
      _target = null;
      return;
    }
    // Base attack cancels orders; restore this explicit automatic-fire order.
    final candidates = _nearby;
    if (attack(target)) {
      _target = target.alive ? target : null;
      _nearby = candidates;
    }
  }

  @override
  bool attack(GameUnit target) {
    if (grid != null &&
        !grid!.clearSegment(position, target.position, radius: 0)) {
      return false;
    }
    _shotCandidates = _nearby;
    try {
      return super.attack(target);
    } finally {
      _shotCandidates = const [];
    }
  }

  @override
  void resolveAttack(GameUnit target) {
    _shotsFired++;
    lastHits = Map.unmodifiable(resolveShot(target, _shotCandidates));
  }

  Map<GameUnit, int> resolveShot(GameUnit primary, Iterable<GameUnit> nearby) =>
      {primary: primary.takeDamage(attackPower)};

  @override
  void cancelWork() {
    _target = null;
    _nearby = const [];
  }

  @override
  void update(double seconds) {
    if (!seconds.isFinite || seconds <= 0) return;
    super.update(seconds);
    if (alive) attemptShot();
  }
}
