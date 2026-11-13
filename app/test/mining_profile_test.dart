import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/profile.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

void main() {
  test('profits accumulate, research costs money, and persists', () {
    final profile = MiningProfile();
    expect(profile.limit(Upgrade.speed), 1);
    expect(profile.purchaseResearch(Upgrade.speed), isFalse);
    profile.collectRunProfit(5000);
    profile.collectRunProfit(-100);
    final balanceBefore = profile.balance;
    final cost = profile.researchCost(Upgrade.speed);
    expect(profile.purchaseResearch(Upgrade.speed), isTrue);
    expect(profile.balance, closeTo(balanceBefore - cost, 0.001));
    expect(profile.limit(Upgrade.speed), 2);

    final loaded = MiningProfile.decode(profile.encode());
    expect(loaded.balance, closeTo(profile.balance, 0.001));
    expect(loaded.limit(Upgrade.speed), 2);
    expect(loaded.purchaseResearch(Upgrade.speed), isFalse);
  });

  test('research caps clamp invalid saved data', () {
    final loaded = MiningProfile.decode(
      '{"balance":-50,"research":{"speed":99,"storage":-3}}',
    );
    expect(loaded.balance, 0);
    expect(loaded.limit(Upgrade.speed), 2);
    expect(loaded.limit(Upgrade.storage), 1);
  });
  test('a new round resets paid upgrades but keeps permanent caps', () {
    final profile = MiningProfile()..collectRunProfit(5000);
    expect(profile.purchaseResearch(Upgrade.speed), isTrue);
    final first = MiningGame(
      stage: stages.first,
      unlockedUpgradeLevels: profile.research,
    );
    expect(first.maxUpgradeLevel(Upgrade.speed), 2);
    expect(first.levels[Upgrade.speed], 0);
    expect(first.upgrade(Upgrade.speed), isTrue);
    expect(first.levels[Upgrade.speed], 1);

    final second = MiningGame(
      stage: stages.first,
      unlockedUpgradeLevels: profile.research,
    );
    expect(second.maxUpgradeLevel(Upgrade.speed), 2);
    expect(second.levels[Upgrade.speed], 0);
    expect(second.maxUpgradeLevel(Upgrade.storage), 1);
    expect(second.upgrade(Upgrade.storage), isTrue);
    expect(second.upgrade(Upgrade.storage), isFalse);
  });

}
