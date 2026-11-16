import 'dart:math' as math;
import 'actions.dart';
import 'animation.dart';
import 'movement.dart';
import 'stats.dart';
import 'upgrades.dart';
import '../world/grid_map.dart';

/// Shared unit behavior; independent of Flutter, maps, and sprite loading.
abstract class GameUnit {
  GameUnit({
    required math.Point<double> position,
    required this.stats,
    required this.upgrades,
    this.grid,
  }) : movement = UnitMovement(
         position: position,
         speed: stats.speed,
         radius: stats.radius,
       ),
       _health = stats.maxHealth;

  final GridMap? grid;
  final UnitStats stats;
  final UnitUpgrades upgrades;
  final UnitMovement movement;
  final UnitAnimation animation = UnitAnimation();
  int _health;
  double _attackCooldown = 0;
  double _actionElapsed = 0;
  UnitAction _action = UnitAction.stop;

  String get label;
  int get colorValue;
  bool get canUpgradeAttack => true;
  bool get canUpgradeDefense => true;
  int get attackPower =>
      stats.attackPower +
      (canUpgradeAttack ? upgrades.attackLevel * stats.attackUpgradeBonus : 0);
  int get defense =>
      stats.defense +
      (canUpgradeDefense
          ? upgrades.defenseLevel * stats.defenseUpgradeBonus
          : 0);
  int get health => _health;
  bool get alive => _health > 0;
  UnitAction get action => _action;
  math.Point<double> get position => movement.position;
  math.Point<double>? get destination => movement.destination;
  bool get moving => movement.moving;
  double get speed => stats.speed;
  double get radius => stats.radius;
  double get facing => movement.facing;
  set facing(double radians) => movement.facing = radians;
  math.Point<double>? get workTarget => null;
  bool get needsUpdate =>
      alive &&
      (_attackCooldown > 0 || moving || animation.motion != UnitMotion.idle);

  Map<UnitAction, UnitActionSpec> get actions => const {
    UnitAction.move: UnitActionSpec(UnitMotion.walk, cycleSeconds: 2 / 3),
    UnitAction.stop: UnitActionSpec(UnitMotion.idle),
    UnitAction.attack: UnitActionSpec(
      UnitMotion.attack,
      cycleSeconds: UnitDefaults.attackCycle,
      loop: false,
    ),
  };

  bool supports(UnitAction action) => actions.containsKey(action);

  void moveTo(math.Point<double> point) {
    if (!alive) return;
    cancelWork();
    travelTo(point);
    startAction(moving ? UnitAction.move : UnitAction.stop);
  }

  bool travelTo(math.Point<double> point) {
    final path = grid?.route(position, point, radius: radius) ?? [point];
    if (path.isEmpty) {
      movement.stop();
      return false;
    }
    movement.moveAlong(path);
    return true;
  }

  void stop() {
    cancelWork();
    movement.stop();
    startAction(UnitAction.stop);
  }

  /// Override for character-specific orders that need cancelling on movement.
  void cancelWork() {}

  /// Called once when movement reaches its destination.
  void onArrival() => startAction(UnitAction.stop);

  void startAction(UnitAction value) {
    final spec = actions[value];
    if (spec == null) return;
    _action = value;
    _actionElapsed = 0;
    animation.play(
      spec.motion,
      framesPerSecond: spec.framesPerSecond,
      frames: spec.frames,
    );
  }

  /// Target-free work is a visual test; gathering and attacks require targets.
  bool perform(UnitAction value) {
    if (!alive || !supports(value)) return false;
    if (value == UnitAction.move ||
        value == UnitAction.attack ||
        value == UnitAction.gather) {
      return false;
    }
    stop();
    startAction(value);
    return true;
  }

  bool attack(GameUnit target) {
    if (!alive ||
        !target.alive ||
        identical(target, this) ||
        !supports(UnitAction.attack) ||
        _attackCooldown > 0 ||
        position.distanceTo(target.position) > stats.attackRange) {
      return false;
    }
    stop();
    facing = math.atan2(
      target.position.y - position.y,
      target.position.x - position.x,
    );
    startAction(UnitAction.attack);
    _attackCooldown = actions[UnitAction.attack]!.cycleSeconds;
    resolveAttack(target);
    return true;
  }

  void resolveAttack(GameUnit target) => target.takeDamage(attackPower);

  int takeDamage(int power) {
    if (!alive || power <= 0) return 0;
    final amount = math.min(_health, math.max(0, power - defense));
    _health -= amount;
    if (!alive) stop();
    return amount;
  }

  void onActionTick(double seconds) {}

  void update(double seconds) {
    if (!alive || !seconds.isFinite || seconds <= 0) return;
    _attackCooldown = math.max(0, _attackCooldown - seconds);
    final wasMoving = moving;
    final travelSeconds = movement.remainingDistance / speed;
    movement.update(seconds, speedOverride: speed);
    var actionSeconds = seconds;
    if (wasMoving && !moving) {
      onArrival();
      actionSeconds = math.max(0, seconds - travelSeconds);
    }
    _actionElapsed += actionSeconds;
    final spec = actions[action]!;
    if (!spec.loop && _actionElapsed >= spec.cycleSeconds) {
      startAction(UnitAction.stop);
    }
    animation.update(actionSeconds);
    onActionTick(actionSeconds);
  }
}
