import 'dart:math';
import 'geometry.dart';
import 'content.dart';

enum Resource { ore, gold }

class Inventory {
  final Resource resource;
  double capacity;
  double _amount = 0;
  Inventory(this.resource, this.capacity);
  double get amount => _amount;
  double get free => max(0, capacity - _amount);
  double put(double requested) {
    if (!requested.isFinite || requested <= 0) return 0;
    final n = min(requested, free);
    _amount += n;
    return n;
  }

  double take(double requested) {
    if (!requested.isFinite || requested <= 0) return 0;
    final n = min(requested, _amount);
    _amount -= n;
    return n;
  }

  double transferTo(Inventory target, double requested) {
    if (identical(this, target) ||
        resource != target.resource ||
        !requested.isFinite ||
        requested <= 0) {
      return 0;
    }
    final n = min(requested, min(_amount, target.free));
    _amount -= n;
    target._amount += n;
    return n;
  }
}

class MineStorage {
  int level = 1;
  final Inventory ore = Inventory(
    Resource.ore,
    GameBalance.mineStorageCapacities.first,
  );
  double get capacity => ore.capacity;
  double get upgradeCost =>
      canUpgrade ? GameBalance.mineStorageUpgradeCosts[level - 1] : 0;
  bool get canUpgrade => level < 3;
  void upgrade() {
    if (canUpgrade) {
      level++;
      ore.capacity = GameBalance.mineStorageCapacities[level - 1];
    }
  }
}

enum GateDirection { north, east, south, west }

class FactoryGate {
  final int id;
  final GateDirection direction;
  final Point2 point;
  int? unloadingCart;
  FactoryGate(this.id, this.direction, this.point);
  String get label => const ['북문', '동문', '남문', '서문'][id];
}

class Refinery {
  static const orePerGold = GameBalance.orePerGold;
  int level = 0;
  double consumedOre = 0, producedGold = 0;
  double get rate => GameBalance.refineryOrePerSecond * (1 + level * .5);
  double update(double dt, Inventory input, Inventory output) {
    final ore = min(input.amount, min(rate * dt, output.free * orePerGold));
    if (ore <= 0) return 0;
    input.take(ore);
    output.put(ore / orePerGold);
    consumedOre += ore;
    producedGold += ore / orePerGold;
    return ore;
  }
}

class MiningFactory {
  final Point2 center = MapGeometry.factoryCenter;
  final Inventory rawOre = Inventory(Resource.ore, 500);
  final Inventory gold = Inventory(Resource.gold, 300);
  final Refinery refinery = Refinery();
  final List<FactoryGate> gates = [
    FactoryGate(0, GateDirection.north, const Point2(.5, .458)),
    FactoryGate(1, GateDirection.east, const Point2(.524, .5)),
    FactoryGate(2, GateDirection.south, const Point2(.5, .542)),
    FactoryGate(3, GateDirection.west, const Point2(.476, .5)),
  ];
  void expand(int level) {
    rawOre.capacity = 500 + level * 300.0;
    gold.capacity = 300 + level * 200.0;
  }

  FactoryGate nearestGate(Point2 point) =>
      (gates.toList()..sort(
            (a, b) =>
                a.point.distance(point).compareTo(b.point.distance(point)),
          ))
          .first;
}

enum MerchantState { atShop, toFactory, loading, toShop }

class TradeOrder {
  final int id, merchantId;
  final double quantity, unitPrice;
  double pending, inTransit = 0, delivered = 0, cancelled = 0;
  TradeOrder(this.id, this.merchantId, this.quantity, this.unitPrice)
    : pending = quantity;
  bool get complete => pending < 1e-7 && inTransit < 1e-7;
}

class CargoLot {
  final TradeOrder order;
  final double quantity;
  CargoLot(this.order, this.quantity);
}

class Merchant {
  final int id;
  final Point2 shop, dock;
  final Inventory cargo = Inventory(Resource.gold, GameBalance.brokerCapacity);
  final List<CargoLot> manifest = [];
  MerchantState state = MerchantState.atShop;
  double progress = 0, loadingAge = 0;
  Merchant(this.id, this.shop, this.dock);
  Point2 get point => shop.towards(dock, progress);
  String get label => '${id + 1}번 중개인';
}

class TradeService {
  final MiningFactory factory;
  final double basePrice;
  final List<Merchant> merchants = [
    Merchant(0, const Point2(.08, .50), const Point2(.464, .535)),
    Merchant(1, const Point2(.92, .50), const Point2(.536, .535)),
  ];
  final List<TradeOrder> orders = [];
  double revenue = 0, deliveredGold = 0;
  TradeService(this.factory, this.basePrice);
  double price(int id, double elapsed) =>
      basePrice *
      (1 + .25 * sin(elapsed / 24) + .08 * sin(elapsed / 7)) *
      (1 + .14 * sin(elapsed / 31 + (id == 0 ? 0 : pi)));
  double get reserved => orders.fold(0, (sum, o) => sum + o.pending);
  double get available => max(0, factory.gold.amount - reserved);
  double pendingFor(int id) => orders
      .where((o) => o.merchantId == id)
      .fold(0.0, (sum, o) => sum + o.pending);
  TradeOrder? placeOrder(int merchantId, double quantity, double elapsed) {
    if (merchantId < 0 ||
        merchantId >= merchants.length ||
        !quantity.isFinite ||
        quantity <= 1e-7 ||
        quantity > available + 1e-7) {
      return null;
    }
    final order = TradeOrder(
      orders.length,
      merchantId,
      min(quantity, available),
      price(merchantId, elapsed),
    );
    orders.add(order);
    return order;
  }

  bool split(double first, double second, double elapsed) {
    if (!first.isFinite ||
        !second.isFinite ||
        first < 0 ||
        second < 0 ||
        first + second > available + 1e-7 ||
        first + second < 1e-7) {
      return false;
    }
    if (first > 0) placeOrder(0, first, elapsed);
    if (second > 0) placeOrder(1, second, elapsed);
    return true;
  }

  double cancelPending(int id) {
    var cancelled = 0.0;
    for (final order in orders.where((o) => o.merchantId == id)) {
      cancelled += order.pending;
      order.cancelled += order.pending;
      order.pending = 0;
    }
    return cancelled;
  }

  void update(double dt) {
    for (final merchant in merchants) {
      final route = max(.01, merchant.shop.distance(merchant.dock));
      switch (merchant.state) {
        case MerchantState.atShop:
          if (pendingFor(merchant.id) > 1e-7) {
            merchant.state = MerchantState.toFactory;
          }
        case MerchantState.toFactory:
          merchant.progress = min(
            1,
            merchant.progress + dt * GameBalance.brokerSpeed / route,
          );
          if (merchant.progress >= 1) {
            merchant.state = MerchantState.loading;
            merchant.loadingAge = 0;
          }
        case MerchantState.loading:
          var budget = dt * GameBalance.brokerLoadPerSecond;
          for (final order in orders.where(
            (o) => o.merchantId == merchant.id && o.pending > 1e-7,
          )) {
            final n = factory.gold.transferTo(
              merchant.cargo,
              min(budget, order.pending),
            );
            if (n > 0) {
              order.pending -= n;
              order.inTransit += n;
              merchant.manifest.add(CargoLot(order, n));
              budget -= n;
            }
            if (budget <= 1e-7 || merchant.cargo.free < 1e-7) break;
          }
          merchant.loadingAge += dt;
          if (merchant.cargo.free < 1e-7 ||
              pendingFor(merchant.id) < 1e-7 ||
              merchant.loadingAge >= GameBalance.partialLoadWait) {
            if (merchant.cargo.amount > 0) {
              merchant.state = MerchantState.toShop;
            } else if (pendingFor(merchant.id) < 1e-7) {
              merchant.state = MerchantState.toShop;
            }
          }
        case MerchantState.toShop:
          merchant.progress = max(
            0,
            merchant.progress - dt * GameBalance.brokerSpeed / route,
          );
          if (merchant.progress <= 0) {
            for (final lot in merchant.manifest) {
              lot.order.inTransit -= lot.quantity;
              lot.order.delivered += lot.quantity;
              revenue += lot.quantity * lot.order.unitPrice;
              deliveredGold += lot.quantity;
            }
            merchant.manifest.clear();
            merchant.cargo.take(merchant.cargo.amount);
            merchant.state = MerchantState.atShop;
          }
      }
    }
  }
}
