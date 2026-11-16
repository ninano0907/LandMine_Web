import '../combat/ranged_unit.dart';
import '../combat/shotgun_spread.dart';
import '../game_unit.dart';
import '../stats.dart';
import '../actions.dart';
import '../animation.dart';

class ShotgunUnit extends RangedUnit {
  ShotgunUnit({
    required super.position,
    required super.upgrades,
    super.grid,
    this.spread = const ShotgunSpread(),
    super.stats = const UnitStats(attackPower: 28, attackRange: 90),
    this.fireCycleSeconds = 1,
  }) : assert(fireCycleSeconds > 0);
  final ShotgunSpread spread;
  final double fireCycleSeconds;
  @override
  String get label => '산탄병';
  @override
  int get colorValue => 0xffa9b269;
  @override
  Map<UnitAction, UnitActionSpec> get actions => {
    ...super.actions,
    UnitAction.move: const UnitActionSpec(
      UnitMotion.walk,
      cycleSeconds: 7 / 12,
      frames: 7,
    ),
    UnitAction.attack: UnitActionSpec(
      UnitMotion.attack,
      cycleSeconds: fireCycleSeconds,
      loop: false,
    ),
  };
  @override
  Map<GameUnit, int> resolveShot(GameUnit primary, Iterable<GameUnit> nearby) {
    final damage = spread.hits(this, [primary, ...nearby]);
    return {
      for (final hit in damage.entries) hit.key: hit.key.takeDamage(hit.value),
    };
  }
}
