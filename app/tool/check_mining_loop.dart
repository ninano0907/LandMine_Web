import 'dart:io';
import 'dart:math';
import 'package:mine_path/world/grid_map.dart';
import 'package:mine_path/world/unit_lab_world.dart';
import 'package:mine_path/buildings/command_center.dart';
import 'package:mine_path/resources/mineral_deposit.dart';
import 'package:mine_path/units/characters/engineer.dart';
import 'package:mine_path/units/upgrades.dart';

int checks = 0;
void check(bool condition, String description) {
  checks++;
  if (!condition) throw StateError(description);
}

void main() {
  final grid = GridMap(columns: 20, rows: 12);
  final center = CommandCenter(grid: grid, column: 8, row: 4);
  check(
    center.area.width == 4 &&
        center.area.height == 3 &&
        grid.occupiedCells == 12,
    'Command center occupies exactly twelve tiles',
  );
  check(
    !grid.place('overlap', const TileArea(9, 5, 2, 2)) &&
        grid.occupiedCells == 12,
    'Overlapping placement fails atomically',
  );
  check(
    !grid.place('outside', const TileArea(19, 11, 4, 3)) &&
        grid.occupiedCells == 12,
    'Map-edge placement fails atomically',
  );
  check(!grid.walkable(center.center), 'Building interior blocks movement');
  final path = grid.route(const Point(200.0, 220.0), const Point(600.0, 220.0));
  check(path.length > 1, 'Path routes around command center');
  var previous = const Point(200.0, 220.0);
  for (final point in path) {
    check(
      grid.clearSegment(previous, point),
      'Every path segment has clearance',
    );
    previous = point;
  }
  check(
    grid.route(const Point(200.0, 220.0), center.center).isEmpty,
    'Cannot issue movement inside an occupied footprint',
  );
  final source = MineralDeposit(const Point(400.0, 410.0));
  final worker = EngineerUnit(
    position: const Point(400.0, 384.0),
    upgrades: UnitUpgrades(),
    grid: grid,
  );
  check(!worker.hasCargo && worker.cargo == 0, 'Starts with an empty bag');
  check(worker.speed == 100, 'Empty backpack speed is 100');
  worker.gather(source, center);
  check(
    worker.gatheringPhase == GatheringPhase.mining,
    'Already in reach starts mining',
  );
  worker.update(0.624);
  check(
    worker.strikes == 0 && worker.cargo == 0,
    'No strike before impact frame',
  );
  worker.update(0.002);
  check(
    worker.strikes == 1 && source.remaining == 1500,
    'First strike does not take ore',
  );
  worker.update(1);
  check(
    worker.strikes == 2 && worker.cargo == 0,
    'Second strike does not take ore',
  );
  worker.update(0.998);
  check(
    worker.strikes == 2 && worker.cargo == 0,
    'Still no load before third impact',
  );
  worker.update(0.002);
  check(
    worker.delivering && worker.cargo == 5 && source.remaining == 1495,
    'Third impact creates one five-mineral load',
  );
  check(
    center.storedMinerals == 0,
    'Mining does not credit storage before arrival',
  );
  check(worker.speed == 70, 'Loaded backpack speed is 70');
  worker.stop();
  check(worker.hasCargo, 'Stopping cannot clear the full-bag flag');
  check(worker.cargo == 5 && source.remaining == 1495, 'Stop preserves cargo');
  worker.moveTo(const Point(500.0, 350.0));
  final beforeTravel = worker.movement.distanceTravelled;
  worker.update(0.5);
  check(
    (worker.movement.distanceTravelled - beforeTravel - 35).abs() < 0.000001,
    'Loaded movement really travels 70 units per second',
  );
  worker.update(0.5);
  check(worker.cargo == 5, 'Manual movement preserves cargo');
  worker.returnCargo(center);
  for (var i = 0; i < 300 && worker.cargo > 0; i++) {
    worker.update(0.05);
  }
  check(
    worker.cargo == 0 && center.storedMinerals == 5,
    'Manual return deposits once',
  );
  check(!worker.hasCargo, 'Unloading empties the bag');
  check(worker.speed == 100, 'Unloading restores speed 100');
  worker.update(10);
  check(center.storedMinerals == 5, 'Idle cannot credit the same load again');

  for (
    var direction = 0;
    direction < UnitLabWorld().deposits.length;
    direction++
  ) {
    final world = UnitLabWorld();
    final unit = EngineerUnit(
      position: UnitLabWorld.spawn,
      upgrades: UnitUpgrades(),
      grid: world.grid,
    );
    final mineral = world.deposits[direction];
    unit.gather(mineral, world.commandCenter);
    for (
      var step = 0;
      step < 1200 && world.commandCenter.storedMinerals < 10;
      step++
    ) {
      unit.update(0.05);
      check(
        unit.hasCargo == (unit.cargo > 0),
        'Bag state follows actual cargo',
      );
      if (unit.gatheringPhase == GatheringPhase.mining) {
        check(
          unit.position.distanceTo(mineral.position) <= 26.01,
          'Pickaxe swings close to the crystal',
        );
        check(
          !unit.hasCargo,
          'Every new mining cycle starts with an empty bag',
        );
      }
      check(
        world.grid.walkable(unit.position, radius: unit.radius),
        'Worker cannot walk through building ($direction)',
      );
      check(
        mineral.remaining + unit.cargo + world.commandCenter.storedMinerals ==
            1500,
        'Resource conservation through mining, hauling and unloading ($direction)',
      );
    }
    check(
      world.commandCenter.storedMinerals >= 10,
      'Direction $direction completes at least two automatic trips',
    );
  }

  final startingWorld = UnitLabWorld();
  final startingWorkers = [
    for (final position in UnitLabWorld.workerSpawns)
      EngineerUnit(
        position: position,
        upgrades: UnitUpgrades(),
        grid: startingWorld.grid,
      ),
  ];
  check(startingWorkers.length == 4, 'Start with four workers');
  for (var i = 0; i < startingWorkers.length; i++) {
    final worker = startingWorkers[i];
    check(
      startingWorld.grid.walkable(worker.position, radius: worker.radius),
      'Starting worker is outside the command center',
    );
    worker.gather(
      startingWorld.deposits[i % startingWorld.deposits.length],
      startingWorld.commandCenter,
    );
  }
  for (var step = 0; step < 1200; step++) {
    for (final worker in startingWorkers) {
      worker.update(0.05);
      check(
        startingWorld.grid.walkable(worker.position, radius: worker.radius),
        'Concurrent workers stay outside buildings',
      );
    }
    check(
      startingWorld.deposits.fold<int>(
                0,
                (sum, deposit) => sum + deposit.remaining,
              ) +
              startingWorkers.fold<int>(
                0,
                (sum, worker) => sum + worker.cargo,
              ) +
              startingWorld.commandCenter.storedMinerals ==
          startingWorld.deposits.length * 1500,
      'Four workers conserve all gold',
    );
  }
  for (var i = 0; i < startingWorkers.length; i++) {
    check(
      startingWorld.deposits[i % startingWorld.deposits.length].remaining <
          1500,
      'Each starting worker mines its assigned deposit',
    );
  }
  check(
    startingWorld.commandCenter.storedMinerals >= 40,
    'Four workers complete repeated deliveries',
  );

  final sharedWorld = UnitLabWorld();
  final sharedOre = sharedWorld.deposits.last;
  final sharedWorkers = [
    for (final position in UnitLabWorld.workerSpawns)
      EngineerUnit(
        position: position,
        upgrades: UnitUpgrades(),
        grid: sharedWorld.grid,
      ),
  ];
  for (final worker in sharedWorkers) {
    worker.gather(sharedOre, sharedWorld.commandCenter);
    check(
      sharedOre.miningPosition(worker) != null,
      'Shared ore assigns a mining position',
    );
  }
  final worked = <EngineerUnit>{};
  var simultaneous = false;
  for (var step = 0; step < 1200; step++) {
    for (final worker in sharedWorkers) {
      worker.update(0.05);
      if (worker.gatheringPhase == GatheringPhase.mining) worked.add(worker);
    }
    final mining = sharedWorkers
        .where((worker) => worker.gatheringPhase == GatheringPhase.mining)
        .toList();
    if (mining.length == 4) simultaneous = true;
    for (var i = 0; i < mining.length; i++) {
      for (var j = i + 1; j < mining.length; j++) {
        check(
          mining[i].position.distanceTo(mining[j].position) >= 17.99,
          'Workers sharing a mineral have separate mining positions',
        );
      }
    }
    check(
      sharedOre.remaining +
              sharedWorkers.fold<int>(0, (sum, worker) => sum + worker.cargo) +
              sharedWorld.commandCenter.storedMinerals ==
          1500,
      'Shared mineral conserves gold through concurrent mining',
    );
  }
  check(
    worked.length == 4 && simultaneous,
    'Four workers mine one mineral at the same time',
  );
  check(
    sharedWorld.commandCenter.storedMinerals >= 40,
    'Shared mineral supports repeated deliveries',
  );
  sharedWorkers.first.stop();
  check(
    sharedOre.miningPosition(sharedWorkers.first) == null,
    'Stopping releases the mining position',
  );
  sharedWorkers.first.gather(sharedOre, sharedWorld.commandCenter);
  check(
    sharedOre.miningPosition(sharedWorkers.first) != null,
    'Worker can rejoin shared mineral',
  );

  final finalWorld = UnitLabWorld();
  final small = MineralDeposit(const Point(400.0, 410.0), amount: 2);
  final lastWorker = EngineerUnit(
    position: UnitLabWorld.spawn,
    upgrades: UnitUpgrades(),
    grid: finalWorld.grid,
  );
  lastWorker.gather(small, finalWorld.commandCenter);
  for (var i = 0; i < 400; i++) {
    lastWorker.update(0.05);
  }
  check(
    small.remaining == 0 &&
        lastWorker.cargo == 0 &&
        finalWorld.commandCenter.storedMinerals == 2,
    'Final partial load is delivered without creating resources',
  );
  check(
    lastWorker.workTarget == null && !lastWorker.moving,
    'Depleted mineral ends the automatic loop',
  );
  grid.remove(center.id);
  check(
    grid.occupiedCells == 0 && grid.walkable(center.center),
    'Removing a building releases its tiles',
  );
  stdout.writeln(
    'PASS: $checks checks for 4x3 tiles, routing, exactly three impacts, mineral hauling, shared mining and resource conservation.',
  );
}
