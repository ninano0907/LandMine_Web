import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/buildings/barracks.dart';
import 'package:mine_path/units/characters/soldier.dart';
import 'package:mine_path/units/characters/shotgun.dart';
import 'package:mine_path/units/game_unit.dart';
import 'package:mine_path/units/unit_kind.dart';
import 'package:mine_path/units/upgrades.dart';
import 'package:mine_path/world/unit_lab_world.dart';

void main() {
  test('infantry and shotgun train in order outside the school', () {
    final world = UnitLabWorld();
    final school = world.barracks;
    final upgrades = UnitUpgrades();
    final units = <GameUnit>[];
    expect(school.enqueue(UnitKind.soldier), isTrue);
    expect(school.enqueue(UnitKind.shotgun), isTrue);
    expect(school.update(2, upgrades, units), isNull);
    expect(school.progress, closeTo(2 / 3, .001));
    final infantry = school.update(1, upgrades, units)!;
    units.add(infantry);
    expect(infantry, isA<SoldierUnit>());
    expect(school.contains(infantry.position), isFalse);
    expect(world.grid.walkable(infantry.position), isTrue);
    expect(school.queue, [UnitKind.shotgun]);
    expect(school.update(2.9, upgrades, units), isNull);
    final shotgun = school.update(.1, upgrades, units)!;
    expect(shotgun, isA<ShotgunUnit>());
    expect(
      shotgun.position.distanceTo(infantry.position),
      greaterThanOrEqualTo(28),
    );
    expect(school.queue, isEmpty);
    expect(school.update(30, upgrades, units), isNull);
  });

  test('cavalry requires a future stable and workers are not trained here', () {
    final school = UnitLabWorld().barracks;
    expect(school.enqueue(UnitKind.cavalry), isFalse);
    expect(school.enqueue(UnitKind.engineer), isFalse);
    expect(school.queue, isEmpty);
  });

  test(
    'blocked exit retains completed training until space becomes available',
    () {
      final world = UnitLabWorld();
      final school = world.barracks;
      final upgrades = UnitUpgrades();
      final blockers = <GameUnit>[
        for (var row = 0; row < 2; row++)
          for (var column = 0; column < 5; column++)
            UnitKind.soldier.spawn(
              Point(
                school.left + 12 + column * 30.0,
                school.top + school.height + 26 + row * 30.0,
              ),
              upgrades,
              grid: world.grid,
            ),
      ];
      school.enqueue(UnitKind.shotgun);
      expect(
        school.update(Barracks.trainingSeconds, upgrades, blockers),
        isNull,
      );
      expect(school.progress, 1);
      expect(school.queue, [UnitKind.shotgun]);
      blockers.removeAt(0);
      expect(school.update(.01, upgrades, blockers), isA<ShotgunUnit>());
      expect(school.queue, isEmpty);
    },
  );
}
