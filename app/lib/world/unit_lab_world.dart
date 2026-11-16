import 'dart:math';
import 'grid_map.dart';
import '../buildings/command_center.dart';
import '../buildings/barracks.dart';
import '../resources/mineral_deposit.dart';
import '../units/mineral_targets.dart';
import '../units/characters/training_dummy.dart';
import '../units/upgrades.dart';

enum TrainingSetup { eightDirections, closeSingle, farGroup }

/// A small isolated world for unit and building interaction tests.
class UnitLabWorld {
  UnitLabWorld() {
    commandCenter = CommandCenter(grid: grid, column: 8, row: 6);
    barracks = Barracks(grid: grid, column: 14, row: 6);
    configureTargets(TrainingSetup.eightDirections);
  }
  final grid = GridMap(columns: 20, rows: 12);
  late final CommandCenter commandCenter;
  late final Barracks barracks;
  final deposits = [for (final p in mineralTargets) MineralDeposit(p)];
  static const spawn = Point(400.0, 410.0);
  static const workerSpawns = <Point<double>>[
    Point(310, 420),
    Point(370, 420),
    Point(430, 420),
    Point(490, 420),
  ];
  static const combatSpawn = Point(200.0, 330.0);
  final targets = <TrainingDummy>[];
  final _targetTeam = UnitUpgrades();

  void configureTargets(TrainingSetup setup) {
    final angles = switch (setup) {
      TrainingSetup.eightDirections => [for (var i = 0; i < 8; i++) i * pi / 4],
      TrainingSetup.closeSingle => [0.0],
      TrainingSetup.farGroup => [-pi / 9, 0.0, pi / 9],
    };
    final distance = setup == TrainingSetup.closeSingle ? 28.0 : 80.0;
    targets
      ..clear()
      ..addAll([
        for (final angle in angles)
          TrainingDummy(
            position: Point(
              combatSpawn.x + cos(angle) * distance,
              combatSpawn.y + sin(angle) * distance,
            ),
            upgrades: _targetTeam,
          ),
      ]);
  }
}
