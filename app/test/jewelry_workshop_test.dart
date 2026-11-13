import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/jewelry.dart';
import 'package:mine_path/mining/simulation.dart';

void main() {
  test('gold converts into jewelry and is counted only at settlement', () {
    final game = MiningGame(stage: stages.first);
    game.factory.gold.put(4);
    expect(game.jewelry.pieces, 0);
    expect(game.craftJewelry(), isTrue);
    expect(game.jewelry.pieces, 1);
    expect(game.factory.gold.amount, 2);
    expect(game.pendingJewelryValue, greaterThan(0));
    expect(game.revenue, 0);
    final expected = game.pendingJewelryValue;
    game.finishEarly();
    expect(game.revenue, closeTo(expected, 0.001));
  });

  test('merchant reserved gold cannot also be crafted', () {
    final game = MiningGame(stage: stages.first);
    game.factory.gold.put(JewelryWorkshop.goldPerPiece);
    expect(game.orderSale(0, JewelryWorkshop.goldPerPiece), isTrue);
    expect(game.craftJewelry(), isFalse);
    expect(game.factory.gold.amount, JewelryWorkshop.goldPerPiece);
  });

  test('research limit restricts in-run purity and artisan upgrades', () {
    final game = MiningGame(
      stage: stages.first,
      unlockedUpgradeLevels: {Upgrade.purity: 1, Upgrade.artisan: 1},
    );
    expect(game.upgrade(Upgrade.purity), isTrue);
    expect(game.upgrade(Upgrade.purity), isFalse);
    expect(game.upgrade(Upgrade.artisan), isTrue);
    expect(game.upgrade(Upgrade.artisan), isFalse);
    expect(game.jewelry.purityMultiplier, greaterThan(1));
    expect(game.jewelry.craftsmanshipMultiplier, greaterThan(1.5));
  });
}
