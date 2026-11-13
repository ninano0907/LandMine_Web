import 'dart:convert';

import 'simulation.dart';

/// Permanent progress lives outside each individual mining run.
class MiningProfile {
  double balance;
  final Map<Upgrade, int> research;

  MiningProfile({this.balance = 0, Map<Upgrade, int>? research})
      : research = {
          for (final upgrade in Upgrade.values)
            upgrade: (research?[upgrade] ?? 1).clamp(1, _cap(upgrade)),
        };

  static int _cap(Upgrade upgrade) =>
      upgrade == Upgrade.speed ? 2 : upgrade == Upgrade.processing ? 3 : 4;

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

  /// Negative runs cannot erase previously earned permanent currency.
  void collectRunProfit(double profit) {
    if (profit.isFinite && profit > 0) balance += profit;
  }

  String encode() => jsonEncode({
        'version': 1,
        'balance': balance,
        'research': {
          for (final upgrade in Upgrade.values)
            upgrade.name: limit(upgrade),
        },
      });

  factory MiningProfile.decode(String raw) {
    final data = jsonDecode(raw);
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
    );
  }
}
