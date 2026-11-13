import 'dart:convert';

import 'simulation.dart';
import 'content.dart';

/// Permanent progress lives outside each individual mining run.
class MiningProfile {
  double balance;
  int unlockedStage;
  bool bridgeUnlocked;
  bool tunnelUnlocked;
  final Map<Upgrade, int> research;

  MiningProfile({
    this.balance = 0,
    this.unlockedStage = 0,
    this.bridgeUnlocked = false,
    this.tunnelUnlocked = false,
    Map<Upgrade, int>? research,
  })
      : research = {
          for (final upgrade in Upgrade.values)
            upgrade: (research?[upgrade] ?? 1).clamp(1, _cap(upgrade)).toInt(),
        };

  static int _cap(Upgrade upgrade) =>
      upgrade == Upgrade.speed ? 2 :
      (upgrade == Upgrade.processing || upgrade == Upgrade.purity || upgrade == Upgrade.artisan) ? 3 : 4;

  int limit(Upgrade upgrade) => research[upgrade]!;
  int maxLimit(Upgrade upgrade) => _cap(upgrade);
  bool canResearch(Upgrade upgrade) => limit(upgrade) < maxLimit(upgrade);

  double researchCost(Upgrade upgrade) {
    final next = limit(upgrade) + 1;
    return 300.0 * next * next;
  }

  bool purchaseResearch(Upgrade upgrade) {
    if (!canResearch(upgrade)) return false;
    final cost = researchCost(upgrade);
    if (balance + 1e-7 < cost) return false;
    balance -= cost;
    research[upgrade] = limit(upgrade) + 1;
    return true;
  }

  void unlockStageThrough(int index) {
    final safeIndex = index.clamp(0, stages.length - 1).toInt();
    if (safeIndex > unlockedStage) unlockedStage = safeIndex;
  }

  /// Negative runs cannot erase previously earned permanent currency.
  void collectRunProfit(double profit) {
    if (profit.isFinite && profit > 0) balance += profit;
  }

  static const bridgeResearchCost = 1500.0;
  static const tunnelResearchCost = 2200.0;

  bool unlockBridge() {
    if (bridgeUnlocked || balance < bridgeResearchCost) return false;
    balance -= bridgeResearchCost;
    bridgeUnlocked = true;
    return true;
  }

  bool unlockTunnel() {
    if (tunnelUnlocked || balance < tunnelResearchCost) return false;
    balance -= tunnelResearchCost;
    tunnelUnlocked = true;
    return true;
  }

  String encode() => jsonEncode({
        'version': 1,
        'balance': balance,
        'unlockedStage': unlockedStage,
        'bridgeUnlocked': bridgeUnlocked,
        'tunnelUnlocked': tunnelUnlocked,
        'research': {
          for (final upgrade in Upgrade.values)
            upgrade.name: limit(upgrade),
        },
      });

  factory MiningProfile.decode(String raw) {
    dynamic data;
    try {
      data = jsonDecode(raw);
    } on FormatException {
      return MiningProfile();
    }
    if (data is! Map) return MiningProfile();
    final stored = data['research'];
    final limits = <Upgrade, int>{};
    if (stored is Map) {
      for (final upgrade in Upgrade.values) {
        final value = stored[upgrade.name];
        if (value is num && value.isFinite) {
          limits[upgrade] = value.toInt();
        }
      }
    }
    final money = data['balance'];
    return MiningProfile(
      balance: money is num && money.isFinite && money > 0
          ? money.toDouble()
          : 0,
      research: limits,
      unlockedStage: data['unlockedStage'] is int
          ? (data['unlockedStage'] as int).clamp(0, stages.length - 1).toInt()
          : 0,
      bridgeUnlocked: data['bridgeUnlocked'] == true,
      tunnelUnlocked: data['tunnelUnlocked'] == true,
    );
  }
}
