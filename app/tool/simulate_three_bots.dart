import 'dart:io';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

/// Three deterministic bot strategies. This is an offline balance simulation,
/// not a player-facing bot or a substitute for an actual Flutter run.
enum BotStrategy { conservative, balanced, aggressive }

class BotResult {
  final int stage, seed;
  final BotStrategy strategy;
  final double profit, revenue, spending;
  final bool cleared;
  BotResult(this.stage, this.seed, this.strategy, MiningGame game)
      : profit = game.profit,
        revenue = game.revenue,
        spending = game.spending,
        cleared = game.cleared;
}

void _act(MiningGame game, BotStrategy strategy, int second) {
  if (!game.canCommand) return;
  final reserve = switch (strategy) {
    BotStrategy.conservative => 600.0,
    BotStrategy.balanced => 350.0,
    BotStrategy.aggressive => 100.0,
  };
  final scoutLimit = switch (strategy) {
    BotStrategy.conservative => 1,
    BotStrategy.balanced => 2,
    BotStrategy.aggressive => 3,
  };
  if (game.searchingScouts < scoutLimit &&
      game.cash >= MiningGame.scoutCost + reserve &&
      second < game.stage.seconds * .65) {
    game.hireScout();
  }

  final discovered = game.deposits.where((d) => d.discovered).toList()
    ..sort((a, b) => b.remaining.compareTo(a.remaining));
  for (final mine in discovered) {
    if (game.railFor(mine.id) == null &&
        game.cash >= game.railPrice(mine.id) + reserve) {
      game.connect(mine.id);
    }
    final workerTarget = switch (strategy) {
      BotStrategy.conservative => 1,
      BotStrategy.balanced => 2,
      BotStrategy.aggressive => 3,
    };
    if (game.railFor(mine.id) != null &&
        mine.workers < workerTarget &&
        mine.remaining > 0 &&
        game.cash >= MiningGame.workerCost + reserve) {
      if (game.availableWorkers == 0) game.buyWorker();
      game.assignWorker(mine.id);
    }
    if (mine.stock >= mine.storage.capacity * .8 &&
        mine.storage.canUpgrade &&
        game.cash >= mine.storage.upgradeCost + reserve) {
      game.upgradeMineStorage(mine.id);
    }
  }

  if (game.cash >= game.upgradePrice(Upgrade.processing) + reserve &&
      game.levels[Upgrade.processing]! <
          game.maxUpgradeLevel(Upgrade.processing) &&
      game.rawStored >= 50) {
    game.upgrade(Upgrade.processing);
  }
  if (strategy != BotStrategy.conservative &&
      game.cash >= game.upgradePrice(Upgrade.speed) + reserve &&
      game.levels[Upgrade.speed]! < game.maxUpgradeLevel(Upgrade.speed) &&
      game.rails.isNotEmpty) {
    game.upgrade(Upgrade.speed);
  }
  final available = game.trade.available.floorToDouble();
  if (available >= 1) {
    final half = (available / 2).floorToDouble();
    game.splitSale(half, available - half);
  }
}

BotResult simulate(StageSpec stage, int seed, BotStrategy strategy) {
  final game = MiningGame(stage: stage, seed: seed);
  for (var second = 0; second < stage.seconds; second++) {
    if (second % 5 == 0) _act(game, strategy, second);
    game.tick(1);
  }
  return BotResult(stage.number, seed, strategy, game);
}

void main(List<String> args) {
  final seedCount = args.isEmpty ? 10 : int.tryParse(args.first) ?? 10;
  if (seedCount < 1 || seedCount > 1000) {
    stderr.writeln('Seed count must be between 1 and 1000.');
    exitCode = 2;
    return;
  }
  stdout.writeln('stage,strategy,runs,clear_rate,avg_profit,min_profit,max_profit');
  for (final stage in stages) {
    for (final strategy in BotStrategy.values) {
      final results = [
        for (var seed = 0; seed < seedCount; seed++)
          simulate(stage, seed, strategy),
      ];
      final profits = results.map((r) => r.profit).toList();
      final average = profits.reduce((a, b) => a + b) / profits.length;
      final minimum = profits.reduce((a, b) => a < b ? a : b);
      final maximum = profits.reduce((a, b) => a > b ? a : b);
      final clearRate = results.where((r) => r.cleared).length / seedCount;
      stdout.writeln(
        '${stage.number},${strategy.name},$seedCount,'
        '${clearRate.toStringAsFixed(3)},${average.toStringAsFixed(1)},'
        '${minimum.toStringAsFixed(1)},${maximum.toStringAsFixed(1)}',
      );
    }
  }
}
