import 'dart:math';
import 'content.dart';
import 'geometry.dart';
import 'economy.dart';

class Scout {
  final int id, depositId;
  final Point2 hint;
  final double duration;
  double age = 0;
  final Point2 start;
  Point2 point;
  Scout(this.id, this.depositId, this.hint, this.duration, {Point2? origin})
    : start = origin ?? MapGeometry.factoryCenter,
      point = origin ?? MapGeometry.factoryCenter;
  bool get found => age >= duration;
}

class Survey {
  final Point2 point;
  final double radius;
  const Survey(this.point, this.radius);
}

class OreDeposit {
  final int id;
  final MineralSpec mineral;
  final Point2 point;
  final double total;
  double remaining;
  OreDeposit(this.id, this.mineral, this.point, this.total) : remaining = total;
  double get radius => .045 + sqrt(total) / 600;
  bool contains(Point2 p) => point.distance(p) <= radius + 1e-9;
}

class Worker {
  final int id;
  int? shaftId;
  double arrivesAt = 0;
  Worker(this.id);
}

class MineShaft {
  final OreDeposit deposit;
  final MineStorage storage = MineStorage();
  final List<Worker> workforce = [];
  bool discovered = false;
  Point2? exposedPoint;
  MineShaft(int id, MineralSpec mineral, Point2 point, double total)
    : deposit = OreDeposit(id, mineral, point, total);
  int get id => deposit.id;
  MineralSpec get mineral => deposit.mineral;
  Point2 get point => deposit.point;
  double get total => deposit.total;
  double get remaining => deposit.remaining;
  double get radius => deposit.radius;
  double get stock => storage.ore.amount;
  int get workers => workforce.length;
  List<double> get workerArrivals =>
      workforce.map((w) => w.arrivesAt).toList(growable: false);
  bool contains(Point2 point) => deposit.contains(point);
  Point2 get railPort {
    final p = exposedPoint ?? point;
    return Point2(p.x, min(.985, p.y + .065 / MapGeometry.scale));
  }

  Point2 get storagePoint {
    final p = exposedPoint ?? point;
    return Point2(
      (p.x - .055 / (MapGeometry.aspect * MapGeometry.scale))
          .clamp(.01, .99)
          .toDouble(),
      (p.y + .025 / MapGeometry.scale).clamp(.01, .99).toDouble(),
    );
  }
}

typedef Deposit = MineShaft;

enum CartState { waitingForRoute, outbound, loading, inbound, unloading }

class Cart {
  final int id, depositId;
  int level = 1;
  final Inventory hold = Inventory(
    Resource.ore,
    GameBalance.cartCapacities.first,
  );
  double progress = 0, loadWait = 0;
  CartState state = CartState.waitingForRoute;
  Cart(this.depositId, {this.id = 0});
  double get cargo => hold.amount;
  double get capacity => hold.capacity;
  bool get returning =>
      state == CartState.inbound || state == CartState.unloading;
  String get status => switch (state) {
    CartState.waitingForRoute => '레일 대기',
    CartState.outbound => '갱도 이동',
    CartState.loading => '원석 적재',
    CartState.inbound => '공장 복귀',
    CartState.unloading => '하역 / 창고 대기',
  };
  bool get canUpgrade => level < 3;
  double get upgradeCost =>
      canUpgrade ? GameBalance.cartUpgradeCosts[level - 1] : 0;
  void upgrade() {
    if (canUpgrade) {
      level++;
      hold.capacity = GameBalance.cartCapacities[level - 1];
    }
  }
}
