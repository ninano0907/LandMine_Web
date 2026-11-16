import 'dart:io';
import 'dart:math';
import 'package:mine_path/units/characters/soldier.dart';
import 'package:mine_path/units/characters/shotgun.dart';
import 'package:mine_path/units/characters/training_dummy.dart';
import 'package:mine_path/units/combat/shotgun_spread.dart';
import 'package:mine_path/units/direction.dart';
import 'package:mine_path/units/animation.dart';
import 'package:mine_path/units/unit_kind.dart';
import 'package:mine_path/units/upgrades.dart';
import 'package:mine_path/world/grid_map.dart';
import 'package:mine_path/world/unit_lab_world.dart';

int checks = 0;
void check(bool condition, String message) {
  checks++;
  if (!condition) throw StateError(message);
}

TrainingDummy target(double x, double y) =>
    TrainingDummy(position: Point(x, y), upgrades: UnitUpgrades());

void main() {
  const origin = Point(200.0, 330.0);
  final world = UnitLabWorld();
  for (final kind in UnitKind.values) {
    final unit = kind.spawn(origin, UnitUpgrades(), grid: world.grid);
    check(
      identical(unit.grid, world.grid),
      'Every spawned kind receives grid collision',
    );
  }
  for (var i = 0; i < 8; i++) {
    final soldier = SoldierUnit(position: origin, upgrades: UnitUpgrades());
    final angle = i * pi / 4;
    final dummy = target(
      origin.x + cos(angle) * 80,
      origin.y + sin(angle) * 80,
    );
    final untouched = target(dummy.position.x + 10, dummy.position.y);
    check(
      soldier.fireAt(dummy, nearby: [dummy, untouched]),
      'Can aim in direction $i',
    );
    check(
      directionRow(soldier.facing) == i,
      'Turns toward direction $i before firing',
    );
    check(
      dummy.health == 90 && untouched.health == 100,
      'Pistol hits exactly one target',
    );
    check(soldier.shotsFired == 1, 'First aimed shot fires immediately');
    soldier.update(0.1);
    check(soldier.shotsFired == 1, 'Cooldown prevents instant repeated shots');
    for (var t = 0; t < 7; t++) {
      soldier.update(0.1);
    }
    check(
      soldier.shotsFired == 2,
      'Automatic shooting continues after cooldown',
    );
    soldier.moveTo(const Point(210.0, 330.0));
    for (var t = 0; t < 20; t++) {
      soldier.update(0.1);
    }
    check(
      soldier.attackTarget == null && soldier.shotsFired == 2,
      'Movement interrupts automatic fire',
    );
  }
  final walkingShotgun = ShotgunUnit(
    position: origin,
    upgrades: UnitUpgrades(),
  );
  walkingShotgun.moveTo(const Point(400.0, 330.0));
  check(
    walkingShotgun.animation.frameCount == 7,
    'Shotgun walk matches its seven-frame atlas',
  );
  for (var i = 0; i < 40; i++) {
    walkingShotgun.update(0.02);
    check(
      walkingShotgun.animation.frame < 7,
      'Walking cannot select an eighth nonexistent frame',
    );
  }
  walkingShotgun.stop();
  check(
    walkingShotgun.animation.motion == UnitMotion.idle,
    'Walk can return to idle',
  );
  final closeShooter = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: UnitUpgrades(),
  );
  final close = target(28, 0), hidden = target(80, 0);
  check(
    closeShooter.fireAt(close, nearby: [close, hidden]),
    'Near shotgun attack accepted',
  );
  final nearDamage = 100 - close.health;
  check(nearDamage == 28, 'Near single unit catches entire base pellet damage');
  check(
    hidden.health == 100,
    'Pellets stop on first unit rather than piercing',
  );
  check(
    closeShooter.lastHits.length == 1,
    'Close attack concentrates on one unit',
  );

  final farShooter = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: UnitUpgrades(),
  );
  final far = target(80, 0);
  check(farShooter.fireAt(far), 'Far shotgun shot accepted');
  final farDamage = 100 - far.health;
  check(
    farDamage > 0 && farDamage < nearDamage,
    'Distance and spread reduce damage on one far unit',
  );

  final groupShooter = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: UnitUpgrades(),
  );
  final group = [
    for (final a in [-pi / 9, 0.0, pi / 9]) target(cos(a) * 80, sin(a) * 80),
  ];
  check(
    groupShooter.fireAt(group[1], nearby: group),
    'Far cluster shot accepted',
  );
  check(
    groupShooter.lastHits.length == 3,
    'Distant spread hits all three clustered targets',
  );
  check(
    group.every((unit) => 100 - unit.health < nearDamage),
    'Each far target takes less than close hit',
  );
  final total = groupShooter.lastHits.values.fold(
    0,
    (sum, value) => sum + value,
  );
  check(
    total <= groupShooter.attackPower,
    'Area attack cannot create more raw pellet damage',
  );

  final outside = target(0, 60),
      behind = target(-30, 0),
      beyond = target(130, 0);
  final ignored = groupShooter.spread.hits(groupShooter, [
    outside,
    behind,
    beyond,
  ]);
  check(
    ignored.isEmpty,
    'Targets behind, outside cone, or beyond range are not hit',
  );
  const profile = ShotgunSpread();
  check(profile.damageFactor(20, 90) == 1, 'Full damage inside close range');
  check(
    (profile.damageFactor(90, 90) - 0.4).abs() < 0.000001,
    'Configured far damage factor',
  );
  check(
    profile.damageFactor(50, 90) > profile.damageFactor(80, 90),
    'Damage falls with distance',
  );
  const narrow = ShotgunSpread(
    pellets: 1,
    arc: pi / 4,
    minimumDamageFactor: 0.8,
  );
  final tuned = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: UnitUpgrades(),
    spread: narrow,
  );
  final tunedTarget = target(80, 0);
  tuned.fireAt(tunedTarget);
  check(
    tunedTarget.health < far.health,
    'Pellet count, cone and falloff are configurable',
  );

  final upgrades = UnitUpgrades()
    ..upgradeAttack()
    ..upgradeAttack();
  final upgraded = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: upgrades,
  );
  final upgradedTarget = target(28, 0);
  upgraded.fireAt(upgradedTarget);
  check(
    100 - upgradedTarget.health == 30,
    'Attack upgrade changes total pellet budget',
  );
  final armoredTeam = UnitUpgrades()
    ..upgradeDefense()
    ..upgradeDefense();
  final armored = SoldierUnit(
    position: const Point(28.0, 0.0),
    upgrades: armoredTeam,
  );
  final armorShooter = ShotgunUnit(
    position: const Point(0.0, 0.0),
    upgrades: UnitUpgrades(),
  );
  armorShooter.fireAt(armored);
  check(
    armored.health == 74,
    'Armor is applied once to aggregated shotgun hit',
  );

  final blocker = GridMap(columns: 20, rows: 12)
    ..place('wall', const TileArea(8, 5, 1, 1));
  final blocked = SoldierUnit(
    position: const Point(300.0, 220.0),
    upgrades: UnitUpgrades(),
    grid: blocker,
  );
  final blockedTarget = target(380, 220);
  check(
    !blocked.fireAt(blockedTarget) && blockedTarget.health == 100,
    'Cannot shoot through an occupied building',
  );
  final finishing = SoldierUnit(position: origin, upgrades: UnitUpgrades());
  final doomed = target(220, 330)..takeDamage(90);
  finishing.fireAt(doomed);
  for (var i = 0; i < 20; i++) {
    finishing.update(0.1);
  }
  check(
    finishing.shotsFired == 1 && finishing.attackTarget == null,
    'Dead target stops automatic fire',
  );
  check(!finishing.fireAt(target(700, 330)), 'Out-of-range order is rejected');
  stdout.writeln(
    'PASS: $checks checks; close shotgun $nearDamage, far single $farDamage, far group ${groupShooter.lastHits.values.toList()}, pistol eight-direction aiming and fire interruption.',
  );
}
