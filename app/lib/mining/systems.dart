import 'dart:math';
import 'economy.dart';
import 'entities.dart';
import 'rail_network.dart';

class ProductionSystem {
  void update(
    List<MineShaft> mines,
    double elapsed,
    double dt,
    double workerRate,
  ) {
    for (final mine in mines) {
      final active = mine.workforce.where((w) => w.arrivesAt <= elapsed).length;
      final amount = min(
        mine.remaining,
        min(
          mine.storage.ore.free,
          active * workerRate / mine.mineral.hardness * dt,
        ),
      );
      final accepted = mine.storage.ore.put(amount);
      mine.deposit.remaining -= accepted;
    }
  }
}

/// Continuous conveyor delivery. Shared segments have a single throughput
/// budget, so connecting more mines cannot duplicate belt capacity.
class TransportSystem {
  static const double baseOrePerSecond = 6.0;

  void update(
    List<Cart> unusedCarts,
    List<MineShaft> mines,
    RailNetwork network,
    MiningFactory factory,
    double dt,
    double speed,
  ) {
    if (dt <= 0) return;
    final budgets = <int, double>{};
    for (final segment in network.segments) {
      if (segment.ready) {
        budgets[segment.id] = baseOrePerSecond * speed * dt;
      }
    }

    // All mines compete for capacity on any conveyor sections they share.
    // Alternate priority over simulation ticks to prevent starvation.
    final active = mines.where((m) {
      final route = network.routeFor(m.id);
      return route != null && route.ready && m.stock > 0;
    }).toList();
    if (active.isEmpty) return;
    _turn = (_turn + 1) % active.length;
    for (var i = 0; i < active.length; i++) {
      final mine = active[(i + _turn) % active.length];
      final route = network.routeFor(mine.id)!;
      var quantity = min(mine.stock, factory.rawOre.free);
      for (final segment in route.segments) {
        quantity = min(quantity, budgets[segment.id] ?? 0);
      }
      if (quantity <= 0) continue;
      final moved = mine.storage.ore.transferTo(factory.rawOre, quantity);
      for (final segment in route.segments) {
        budgets[segment.id] = max(0, (budgets[segment.id] ?? 0) - moved);
      }
    }
  }

  int _turn = 0;
}
