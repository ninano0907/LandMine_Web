import 'dart:io';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

void require(bool value, String reason) {
  if (!value) throw StateError(reason);
}

void conserved(MiningGame g, {double extraOre = 0, double extraGold = 0}) {
  final initial = g.deposits.fold(0.0, (s, d) => s + d.total) + extraOre;
  final ore =
      g.deposits.fold(0.0, (s, d) => s + d.remaining + d.stock) +
      g.carts.fold(0.0, (s, c) => s + c.cargo) +
      g.rawStored +
      g.factory.refinery.consumedOre;
  require(
    (initial - ore).abs() < .00001,
    'Ore lost or duplicated: $initial / $ore',
  );
  final gold =
      g.stored +
      g.trade.merchants.fold(0.0, (s, m) => s + m.cargo.amount) +
      g.trade.deliveredGold;
  require(
    (g.factory.refinery.producedGold + extraGold - gold).abs() < .00001,
    'Gold lost or duplicated',
  );
  require(g.trade.reserved <= g.stored + .00001, 'Over-reserved gold');
  require(g.cash >= -.00001, 'Negative cash');
  require(
    (g.cash - (g.stage.startingCash + g.revenue - g.spending)).abs() < .00001,
    'Cash ledger',
  );
  require(
    g.availableWorkers >= 0 && g.totalWorkers <= g.purchasedWorkers,
    'Duplicated workers',
  );
  final inventories = [
    g.factory.rawOre,
    g.factory.gold,
    ...g.deposits.map((d) => d.storage.ore),
    ...g.carts.map((c) => c.hold),
    ...g.trade.merchants.map((m) => m.cargo),
  ];
  for (final i in inventories) {
    require(
      i.amount >= -.00001 && i.amount <= i.capacity + .00001,
      'Inventory overflow',
    );
  }
  for (final order in g.trade.orders) {
    require(
      (order.quantity -
                  order.pending -
                  order.inTransit -
                  order.delivered -
                  order.cancelled)
              .abs() <
          .00001,
      'Order quantity mismatch',
    );
  }
}

MiningGame fixture() => MiningGame(
  stage: const StageSpec(
    1,
    'fixture',
    seed: 101,
    deposits: 4,
    seconds: 600,
    startingCash: 10000,
    targetProfit: 500,
  ),
);
void main() {
  final g = fixture();
  g.deposits.clear();
  const points = [
    Point2(.5, .2),
    Point2(.8, .5),
    Point2(.5, .8),
    Point2(.2, .5),
  ];
  for (var i = 0; i < 4; i++) {
    g.deposits.add(MineShaft(i, handEra.minerals.first, points[i], 500));
    g.scan(points[i]);
    g.buyWorker();
    g.assignWorker(i);
    require(g.connect(i), 'Gate $i not connectable');
    require(g.railFor(i)!.gateId == i, 'Wrong gate route');
  }
  require(
    g.upgradeMineStorage(0) && g.deposit(0).storage.capacity == 200,
    'Storage level 2',
  );
  require(
    g.upgradeMineStorage(0) && g.deposit(0).storage.capacity == 300,
    'Storage level 3',
  );
  require(!g.upgradeMineStorage(0), 'Storage exceeded 3 levels');
  require(g.upgradeCart(0) && g.carts[0].capacity == 100, 'Cart level 2');
  require(g.upgradeCart(0) && g.carts[0].capacity == 200, 'Cart level 3');
  require(!g.upgradeCart(0), 'Cart exceeded 3 levels');
  g.paused = true;
  g.tick(100);
  require(g.elapsed == 0, 'Pause advanced');
  g.paused = false;
  for (var i = 0; i < 400; i++) {
    g.tick(1);
    final n = g.trade.available.floorToDouble();
    if (n >= 1) {
      g.splitSale((n / 2).floorToDouble(), n - (n / 2).floorToDouble());
    }
    conserved(g);
  }
  require(
    g.factory.refinery.consumedOre > 0 && g.stored + g.trade.deliveredGold > 0,
    'Refinery did not run',
  );
  require(g.revenue > 0, 'Merchants did not settle');
  stdout.writeln(
    'PASS: four gates, local storage/cart tiers, refining, merchant settlement and conservation.',
  );

  for (final stage in stages) {
    var minProfit = double.infinity;
    for (var seed = 0; seed < 10; seed++) {
      final game = MiningGame(stage: stage, seed: seed);
      game.hireScout();
      for (var t = 0; t < stage.seconds; t++) {
        game.tick(1);
        if (t % 4 == 0 && game.canCommand) {
          final available = game.trade.available.floorToDouble();
          if (available >= 1) {
            final a = (available / 2).floorToDouble();
            game.splitSale(a, available - a);
          }
        }
        if (t % 10 == 0 && game.active && t < stage.seconds * .5) {
          for (final mine in game.deposits.where((d) => d.discovered)) {
            if (game.railFor(mine.id) == null &&
                game.cash > game.railPrice(mine.id) + 80) {
              game.connect(mine.id);
            }
            if (game.railFor(mine.id) != null &&
                mine.workers < 2 &&
                game.cash > 250) {
              if (game.availableWorkers == 0) game.buyWorker();
              game.assignWorker(mine.id);
            }
            if (mine.stock > 80 && mine.storage.canUpgrade && game.cash > 600) {
              game.upgradeMineStorage(mine.id);
            }
          }
          if (game.searchingScouts < 2 && game.cash > 600) game.hireScout();
          if (game.rawStored > 150 &&
              game.cash > 700 &&
              game.levels[Upgrade.processing]! < 2) {
            game.upgrade(Upgrade.processing);
          }
          if (game.cash > 900 && game.levels[Upgrade.speed]! < 2) {
            game.upgrade(Upgrade.speed);
          }
        }
        conserved(game);
      }
      minProfit = game.profit < minProfit ? game.profit : minProfit;
      require(
        game.cleared,
        'Goal not reached: stage ${stage.number}, seed $seed, profit ${game.profit}',
      );
      final cash = game.cash;
      game.tick(100);
      require(game.cash == cash && !game.buyWorker(), 'Finished state changed');
    }
    stdout.writeln(
      'PASS stage ${stage.number}: 10 seeds, min profit ${minProfit.toStringAsFixed(0)}, target ${stage.targetProfit.round()}',
    );
  }
}
