import 'dart:math';
import 'economy.dart';
import 'content.dart';
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

class TransportSystem {
  void update(
    List<Cart> carts,
    List<MineShaft> mines,
    RailNetwork network,
    MiningFactory factory,
    double dt,
    double speed,
  ) {
    for (final cart in carts) {
      final route = network.routeFor(cart.depositId);
      if (route == null || !route.ready) continue;
      final mine = mines.firstWhere((m) => m.id == cart.depositId),
          gate = factory.gates[route.gateId];
      switch (cart.state) {
        case CartState.waitingForRoute:
          cart.state = CartState.outbound;
        case CartState.outbound:
          cart.progress = min(
            1,
            cart.progress + dt * speed / max(.01, route.length),
          );
          if (cart.progress >= 1) {
            cart.state = CartState.loading;
            cart.loadWait = 0;
          }
        case CartState.loading:
          final loadBudget = dt * GameBalance.cartLoadPerSecond;
          final loaded = mine.storage.ore.transferTo(cart.hold, loadBudget);
          if (loaded >= loadBudget - 1e-7) {
            cart.loadWait = 0;
          } else if (cart.cargo > 0) {
            cart.loadWait += dt;
          }
          if (cart.hold.free < 1e-7 ||
              (cart.cargo > 0 &&
                  (cart.loadWait >= GameBalance.partialLoadWait ||
                      (mine.remaining <= 1e-7 && mine.stock <= 1e-7)))) {
            cart.state = CartState.inbound;
          }
        case CartState.inbound:
          cart.progress = max(
            0,
            cart.progress - dt * speed / max(.01, route.length),
          );
          if (cart.progress <= 0) cart.state = CartState.unloading;
        case CartState.unloading:
          if (gate.unloadingCart != null && gate.unloadingCart != cart.id) {
            continue;
          }
          gate.unloadingCart = cart.id;
          cart.hold.transferTo(
            factory.rawOre,
            dt * GameBalance.cartUnloadPerSecond,
          );
          if (cart.cargo < 1e-7) {
            gate.unloadingCart = null;
            cart.state = CartState.outbound;
          }
      }
    }
  }
}
