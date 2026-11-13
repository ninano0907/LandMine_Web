import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/economy.dart';
import 'package:mine_path/mining/profile.dart';
import 'package:mine_path/mining/simulation.dart';

void main() {
  test('refining conserves ore and never exceeds gold storage capacity', () {
    final factory = MiningFactory();
    factory.gold.put(factory.gold.capacity - 1);
    factory.rawOre.put(10);

    final consumed = factory.refinery.update(
      10,
      factory.rawOre,
      factory.gold,
    );

    expect(consumed, closeTo(GameBalance.orePerGold, 1e-7));
    expect(factory.gold.amount, closeTo(factory.gold.capacity, 1e-7));
    expect(factory.rawOre.amount, closeTo(8, 1e-7));
    expect(factory.refinery.producedGold, closeTo(1, 1e-7));
  });

  test('crafted jewelry consumes gold and labor, settling only at finish', () {
    final game = MiningGame(stage: stages.first, seed: 41);
    game.factory.gold.put(5);
    final startingCash = game.cash;

    expect(game.craftJewelry(), isTrue);
    expect(game.factory.gold.amount, closeTo(3, 1e-7));
    expect(game.jewelry.pieces, 1);
    expect(game.jewelry.goldConsumed, closeTo(2, 1e-7));
    expect(game.cash, closeTo(startingCash - 18, 1e-7));
    expect(game.revenue, 0);

    game.finishEarly();
    expect(game.revenue, closeTo(game.jewelry.settlementValue, 1e-7));
    expect(game.craftJewelry(), isFalse);
  });

  test('permanent research limits next round but paid levels reset', () {
    final profile = MiningProfile()..collectRunProfit(5000);
    expect(profile.purchaseResearch(Upgrade.processing), isTrue);
    expect(profile.purchaseResearch(Upgrade.artisan), isTrue);

    final round = MiningGame(
      stage: stages.first,
      seed: 42,
      unlockedUpgradeLevels: MiningProfile.decode(profile.encode()).research,
    );

    expect(round.maxUpgradeLevel(Upgrade.processing), 2);
    expect(round.maxUpgradeLevel(Upgrade.artisan), 2);
    expect(round.levels[Upgrade.processing], 0);
    expect(round.levels[Upgrade.artisan], 0);
    expect(round.upgrade(Upgrade.processing), isTrue);
    expect(round.upgrade(Upgrade.processing), isTrue);
    expect(round.upgrade(Upgrade.processing), isFalse);
    expect(round.factory.refinery.level, 2);
    expect(round.upgrade(Upgrade.artisan), isTrue);
    expect(round.jewelry.artisanLevel, 1);

    final nextRound = MiningGame(
      stage: stages.first,
      seed: 43,
      unlockedUpgradeLevels: profile.research,
    );
    expect(nextRound.levels[Upgrade.processing], 0);
    expect(nextRound.factory.refinery.level, 0);
    expect(nextRound.maxUpgradeLevel(Upgrade.processing), 2);
  });
}
