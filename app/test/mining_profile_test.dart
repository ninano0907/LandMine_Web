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

  test('bridge and tunnel research spends permanent money and survives reload', () {
    final profile = MiningProfile()..collectRunProfit(6000);
    final opening = profile.balance;
    expect(profile.unlockBridge(), isTrue);
    expect(profile.unlockBridge(), isFalse);
    expect(profile.unlockTunnel(), isTrue);
    expect(profile.balance,
        closeTo(opening - MiningProfile.bridgeResearchCost -
            MiningProfile.tunnelResearchCost, 0.001));

    final restored = MiningProfile.decode(profile.encode());
    expect(restored.bridgeUnlocked, isTrue);
    expect(restored.tunnelUnlocked, isTrue);
    expect(restored.unlockBridge(), isFalse);
    expect(restored.unlockTunnel(), isFalse);

    final nextRound = MiningGame(
      stage: stages.first,
      bridgeUnlocked: restored.bridgeUnlocked,
      tunnelUnlocked: restored.tunnelUnlocked,
      unlockedUpgradeLevels: restored.research,
    );
    expect(nextRound.bridgeUnlocked, isTrue);
    expect(nextRound.tunnelUnlocked, isTrue);
    expect(nextRound.levels[Upgrade.speed], 0);
  });

  test('unlocked stages survive saving and do not regress', () {
    final profile = MiningProfile();
    expect(profile.unlockedStage, 0);
    profile.unlockStageThrough(3);
    profile.unlockStageThrough(1);
    expect(profile.unlockedStage, 3);

    final restored = MiningProfile.decode(profile.encode());
    expect(restored.unlockedStage, 3);
    expect(MiningProfile.decode('{}').unlockedStage, 0);
    profile.unlockStageThrough(999);
    expect(profile.unlockedStage, stages.length - 1);
    expect(MiningProfile.decode('{"unlockedStage":999}').unlockedStage, stages.length - 1);
  });

  test('direct profile construction clamps invalid persistent values', () {
    final negative = MiningProfile(balance: -50, unlockedStage: -2);
    expect(negative.balance, 0);
    expect(negative.unlockedStage, 0);

    final oversized = MiningProfile(balance: double.nan, unlockedStage: 999);
    expect(oversized.balance, 0);
    expect(oversized.unlockedStage, stages.length - 1);
    expect(MiningProfile.decode(oversized.encode()).unlockedStage,
        stages.length - 1);
  });

  test('invalid saved data recovers without crashing startup', () {
    expect(MiningProfile.decode('invalid json').balance, 0);
    expect(MiningProfile.decode('null').unlockedStage, 0);
    expect(MiningProfile.decode('[]').bridgeUnlocked, isFalse);
    expect(MiningProfile.decode('{"balance":"5000","research":"bad"}').balance, 0);
    expect(MiningProfile.decode('{"unlockedStage":-3,"bridgeUnlocked":"true","tunnelUnlocked":1}').unlockedStage, 0);
    expect(MiningProfile.decode('{"bridgeUnlocked":"true","tunnelUnlocked":1}').bridgeUnlocked, isFalse);
    expect(MiningProfile.decode('{"bridgeUnlocked":"true","tunnelUnlocked":1}').tunnelUnlocked, isFalse);
  });

}
