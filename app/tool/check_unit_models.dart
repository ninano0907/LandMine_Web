import 'dart:io';
import 'dart:math';
import 'package:mine_path/units/actions.dart';
import 'package:mine_path/units/animation.dart';
import 'package:mine_path/units/characters/engineer.dart';
import 'package:mine_path/units/characters/soldier.dart';
import 'package:mine_path/units/characters/cavalry.dart';
import 'package:mine_path/units/game_unit.dart';
import 'package:mine_path/units/direction.dart';
import 'package:mine_path/units/mineral_targets.dart';
import 'package:mine_path/units/unit_kind.dart';
import 'package:mine_path/units/upgrades.dart';

int checks = 0;
void check(bool condition, String description) {
  checks++;
  if (!condition) throw StateError(description);
}

class FastEngineer extends EngineerUnit {
  FastEngineer({required super.position, required super.upgrades});
  @override
  Map<UnitAction, UnitActionSpec> get actions => {
    ...super.actions,
    UnitAction.gather: const UnitActionSpec(UnitMotion.mine, cycleSeconds: 0.5),
  };
}

void main() {
  const origin = Point(400.0, 250.0);
  final team = UnitUpgrades();
  final worker = EngineerUnit(position: origin, upgrades: team);
  final soldier = SoldierUnit(position: origin, upgrades: team);
  final cavalry = CavalryUnit(position: origin, upgrades: team);
  final rival = SoldierUnit(position: origin, upgrades: UnitUpgrades());
  final units = <GameUnit>[worker, soldier, cavalry];
  final initialAttacks = [for (final unit in units) unit.attackPower];
  final initialDefenses = [for (final unit in units) unit.defense];
  team.upgradeAttack();
  team.upgradeAttack();
  team.upgradeDefense();
  for (var i = 0; i < units.length; i++) {
    check(
      units[i].attackPower == initialAttacks[i] + (i == 0 ? 0 : 2),
      'Existing ${units[i].label}: only combat units receive attack upgrades',
    );
    check(
      units[i].defense == initialDefenses[i] + 1,
      'Existing ${units[i].label}: all units receive defense upgrades',
    );
  }
  check(
    rival.attackPower == rival.stats.attackPower &&
        rival.defense == rival.stats.defense,
    'Opposing team is unaffected',
  );
  for (final kind in UnitKind.values) {
    final fresh = kind.spawn(origin, team);
    check(
      fresh.attackPower ==
          fresh.stats.attackPower + (fresh is EngineerUnit ? 0 : 2),
      'New units inherit completed upgrades',
    );
    check(
      fresh.defense == fresh.stats.defense + 1,
      'New units inherit defense upgrades',
    );
    check(
      fresh.supports(UnitAction.attack) && fresh.supports(UnitAction.move),
      'Common attack and movement actions are inherited',
    );
    fresh.moveTo(const Point(500.0, 250.0));
    fresh.update(0.25);
    check(
      (fresh.position.x - 400 - fresh.speed * 0.25).abs() < 0.000001,
      'Each character uses its own movement speed',
    );
    fresh.update(10);
    check(
      fresh.position == const Point(500.0, 250.0) &&
          fresh.action == UnitAction.stop,
      'Arrival returns to idle without overshoot',
    );
    check(
      fresh.takeDamage(10) == 10 - fresh.defense,
      'Shared damage calculation uses current defense',
    );
    fresh.takeDamage(100000);
    final deathPosition = fresh.position;
    fresh.moveTo(origin);
    fresh.update(1);
    check(
      fresh.health == 0 &&
          fresh.position == deathPosition &&
          !fresh.attack(rival),
      'Dead units cannot move or attack',
    );
  }
  for (final fighter in [soldier, cavalry]) {
    check(
      !fighter.supports(UnitAction.gather) &&
          !fighter.perform(UnitAction.repair) &&
          !fighter.perform(UnitAction.build),
      'Combat units cannot perform engineer-only work',
    );
  }
  for (var i = 0; i < mineralTargets.length; i++) {
    final engineer = EngineerUnit(position: origin, upgrades: team);
    engineer.gatherAt(mineralTargets[i]);
    check(
      engineer.action == UnitAction.move,
      'Gather order first moves to mineral',
    );
    engineer.update(engineer.movement.remainingDistance / engineer.speed);
    check(
      engineer.action == UnitAction.gather &&
          !engineer.moving &&
          directionRow(engineer.facing) == i,
      'Arrival starts correct facing mining',
    );
    engineer.update(0.25);
    check(
      engineer.animation.frame == 2,
      'Mining frame speed follows action spec',
    );
    engineer.moveTo(origin);
    engineer.update(10);
    check(
      engineer.workTarget == null && engineer.action == UnitAction.stop,
      'New movement cancels mining instead of resuming old order',
    );
    engineer.gatherAt(mineralTargets[i]);
    engineer.stop();
    check(
      engineer.workTarget == null && !engineer.moving,
      'Stop cancels pending gathering',
    );
  }
  final fast = FastEngineer(position: origin, upgrades: team);
  fast.gatherAt(origin);
  fast.update(0.25);
  check(
    fast.animation.frame == 4,
    'Subclass action speed changes animation without changing screen code',
  );
  check(
    worker.perform(UnitAction.repair) &&
        worker.animation.motion == UnitMotion.repair,
    'Repair uses engineer action',
  );
  check(
    worker.perform(UnitAction.build) && worker.action == UnitAction.build,
    'Construction is a separate inherited action',
  );
  check(soldier.attack(rival), 'Combat unit can attack an in-range target');
  check(
    rival.health == rival.stats.maxHealth - soldier.attackPower,
    'Upgraded attack applies to damage',
  );
  check(
    !soldier.attack(rival),
    'Attack cooldown prevents repeated instant hits',
  );
  soldier.update(soldier.actions[UnitAction.attack]!.cycleSeconds);
  check(
    soldier.attack(rival),
    'Attack becomes available after action cooldown',
  );
  check(!soldier.attack(soldier), 'Cannot attack self');
  final distant = SoldierUnit(
    position: const Point(1000.0, 1000.0),
    upgrades: team,
  );
  check(
    !soldier.attack(distant),
    'Cannot attack beyond character attack range',
  );
  stdout.writeln(
    'PASS: $checks checks for inheritance, team upgrades, actions, combat, movement and eight-direction mining.',
  );
}
