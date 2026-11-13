import 'dart:math';
import 'content.dart';
import 'geometry.dart';
import 'economy.dart';
import 'entities.dart';
import 'rail_network.dart';
import 'systems.dart';
export 'geometry.dart';
export 'economy.dart';
export 'entities.dart';
export 'rail_network.dart';

enum Upgrade { workers, speed, scanner, storage, processing }

/// Application coordinator: entities own their state; systems own each flow.
class MiningGame {
  static const mapAspect = MapGeometry.aspect, mapScale = MapGeometry.scale;
  static const entrance = MapGeometry.factoryCenter;
  static const scoutCost = 100.0, scanCost = 12.0, workerCost = 75.0;
  final EpisodeSpec episode;
  final StageSpec stage;
  final MiningFactory factory = MiningFactory();
  late final RailNetwork network;
  late final TradeService trade;
  final ProductionSystem production = ProductionSystem();
  final TransportSystem transport = TransportSystem();
  late final List<MineShaft> deposits;
  final List<Survey> surveys = [];
  final List<Cart> carts = [];
  final List<Scout> scouts = [];
  final List<Worker> workers = [];
  final Map<Upgrade, int> levels = {for (final u in Upgrade.values) u: 0};
  late final Random _random;
  double elapsed = 0, spending = 0;
  bool paused = false, finished = false;
  int saleMarket = 0;
  String message = '탐사인을 고용해 원석을 찾고, 공장에서 가공한 금을 중개인에게 판매하세요.';
  MiningGame({required this.stage, this.episode = handEra, int? seed}) {
    network = RailNetwork(factory.gates);
    trade = TradeService(factory, episode.minerals.first.price);
    final random = Random(seed ?? stage.seed);
    _random = Random((seed ?? stage.seed) + 719);
    deposits = [
      MineShaft(0, episode.minerals.first, const Point2(.46, .42), 450),
    ];
    for (var i = 1; i < stage.deposits; i++) {
      Point2 point = Point2(
        .08 + random.nextDouble() * .84,
        .08 + random.nextDouble() * .84,
      );
      for (
        var retry = 0;
        retry < 100 &&
            (deposits.any((d) => d.point.distance(point) < .14) ||
                entrance.distance(point) < .26);
        retry++
      ) {
        point = Point2(
          .08 + random.nextDouble() * .84,
          .08 + random.nextDouble() * .84,
        );
      }
      deposits.add(
        MineShaft(
          i,
          episode.minerals[i % episode.minerals.length],
          point,
          180 + random.nextInt(240).toDouble(),
        ),
      );
    }
  }
  bool get active => !paused && !finished;
  bool get canCommand => !finished;
  double get revenue => trade.revenue;
  double get cash => stage.startingCash + revenue - spending;
  double get profit => revenue - spending;
  bool get cleared => profit >= stage.targetProfit;
  double get timeLeft => max(0, stage.seconds - elapsed);
  List<TrackNode> get trackNodes => network.nodes;
  List<TrackSegment> get trackSegments => network.segments;
  List<Rail> get rails => network.routes;
  int get purchasedWorkers => workers.length;
  int get availableWorkers => workers.where((w) => w.shaftId == null).length;
  int get totalWorkers => workers.length - availableWorkers;
  int get searchingScouts => scouts.where((s) => !s.found).length;
  double get surveyRadius => episode.scanRadius;
  double get capacity => 50;
  double get speed => episode.cartSpeed * (1 + levels[Upgrade.speed]! * .3);
  double get workerRate =>
      episode.workerRate * (1 + levels[Upgrade.workers]! * .35);
  double get stored => factory.gold.amount;
  double get rawStored => factory.rawOre.amount;
  double get storageCapacity => factory.gold.capacity;
  Map<String, double> get inventory => Map.unmodifiable({'gold': stored});
  Map<String, double> get sold =>
      Map.unmodifiable({'gold': trade.deliveredGold});
  Deposit deposit(int id) => deposits.firstWhere((d) => d.id == id);
  Rail? railFor(int id) => network.routeFor(id);
  bool _pay(double price) {
    if (!canCommand || cash + 1e-7 < price) {
      message = '자금이 부족하거나 작업이 종료되었어요.';
      return false;
    }
    spending += price;
    return true;
  }

  bool hireScout() {
    if (!canCommand || searchingScouts >= 3) return false;
    final assigned = scouts.map((s) => s.depositId).toSet();
    final candidates =
        deposits
            .where(
              (d) =>
                  !d.discovered && d.remaining > 0 && !assigned.contains(d.id),
            )
            .toList()
          ..sort(
            (a, b) => entrance
                .distance(a.point)
                .compareTo(entrance.distance(b.point)),
          );
    if (candidates.isEmpty) {
      message = '새로운 탐사 후보가 없어요.';
      return false;
    }
    if (!_pay(scoutCost)) return false;
    final d = candidates.first, angle = _random.nextDouble() * pi * 2;
    final hint = Point2(
      d.point.x + cos(angle) * .025 / (mapAspect * mapScale),
      d.point.y + sin(angle) * .025 / mapScale,
    );
    final origin = factory.nearestGate(hint).point;
    scouts.add(
      Scout(
        scouts.length,
        d.id,
        hint,
        5 + origin.distance(hint) / .045,
        origin: origin,
      ),
    );
    return true;
  }

  bool buyWorker() {
    if (!_pay(workerCost)) return false;
    workers.add(Worker(workers.length));
    return true;
  }

  bool assignWorker(int id) {
    final mine = deposit(id);
    if (!canCommand ||
        !mine.discovered ||
        mine.remaining <= 1e-7 ||
        mine.workers >= 8 ||
        availableWorkers == 0) {
      return false;
    }
    final worker = workers.firstWhere((w) => w.shaftId == null);
    worker.shaftId = id;
    worker.arrivesAt =
        elapsed +
        factory
                .nearestGate(mine.exposedPoint!)
                .point
                .distance(mine.exposedPoint!) /
            .1;
    mine.workforce.add(worker);
    return true;
  }

  bool removeWorker(int id) {
    final mine = deposit(id);
    if (!canCommand || mine.workforce.isEmpty) return false;
    mine.workforce.removeLast().shaftId = null;
    return true;
  }

  bool hire(int id) => assignWorker(id);
  bool visible(Point2 point) =>
      surveys.any((s) => s.point.distance(point) <= s.radius);
  double exposedFraction(Deposit mine) {
    var shown = 0, total = 0;
    for (var y = -5; y <= 5; y++) {
      for (var x = -5; x <= 5; x++) {
        final p = Point2(
          mine.point.x + x * mine.radius / (5 * mapAspect * mapScale),
          mine.point.y + y * mine.radius / (5 * mapScale),
        );
        if (!mine.contains(p)) continue;
        total++;
        if (visible(p)) shown++;
      }
    }
    return total == 0 ? 0 : shown / total;
  }

  bool scan(Point2 point) {
    if (!canCommand ||
        !point.x.isFinite ||
        !point.y.isFinite ||
        point.x < 0 ||
        point.x > 1 ||
        point.y < 0 ||
        point.y > 1) {
      return false;
    }
    if (surveys.any(
          (s) => s.point.distance(point) < .008 && s.radius >= surveyRadius,
        ) ||
        !_pay(scanCost)) {
      return false;
    }
    surveys.add(Survey(point, surveyRadius));
    for (final mine in deposits) {
      final distance = mine.point.distance(point);
      if (distance >= mine.radius + surveyRadius) continue;
      mine.discovered = true;
      mine.exposedPoint ??= distance <= mine.radius
          ? point
          : mine.point.towards(
              point,
              ((max(0.0, distance - surveyRadius) +
                          min(distance, mine.radius)) /
                      2) /
                  distance,
            );
    }
    return true;
  }

  Point2 snapTrackEnd(Point2 point) {
    final mines =
        deposits
            .where((d) => d.discovered && d.railPort.distance(point) < .055)
            .toList()
          ..sort(
            (a, b) => a.railPort
                .distance(point)
                .compareTo(b.railPort.distance(point)),
          );
    return mines.isEmpty ? point : mines.first.railPort;
  }

  double trackPrice(int fromId, Point2 end) =>
      20 +
      trackNodes[fromId].point.distance(snapTrackEnd(end)) * stage.railCost;
  bool trackWouldCross(int fromId, Point2 end) =>
      fromId < 0 ||
      fromId >= trackNodes.length ||
      network.crosses(fromId, snapTrackEnd(end));
  bool buildTrack(int fromId, Point2 target) {
    if (!canCommand ||
        fromId < 0 ||
        fromId >= trackNodes.length ||
        !target.x.isFinite ||
        !target.y.isFinite ||
        target.x < 0 ||
        target.x > 1 ||
        target.y < 0 ||
        target.y > 1) {
      return false;
    }
    final end = snapTrackEnd(target);
    if (trackNodes[fromId].point.distance(end) < .025 ||
        trackNodes.any((n) => n.point.distance(end) < .015)) {
      return false;
    }
    if (trackWouldCross(fromId, end)) {
      message = '레일 교차·겹침과 공장 관통은 불가능해요.';
      return false;
    }
    MineShaft? linked;
    for (final mine in deposits) {
      if (mine.discovered && mine.railPort.distance(end) < .001) {
        linked = mine;
        break;
      }
    }
    if (linked != null && railFor(linked.id) != null) return false;
    if (!_pay(trackPrice(fromId, end))) return false;
    final node = network.extend(fromId, end);
    if (linked != null) {
      network.attachMine(linked.id, node);
      carts.add(Cart(linked.id, id: carts.length));
    }
    return true;
  }

  int bestGateFor(int id) => factory.nearestGate(deposit(id).railPort).id;
  double railPrice(int id) => trackPrice(bestGateFor(id), deposit(id).railPort);
  bool connect(int id) =>
      deposit(id).discovered &&
      buildTrack(bestGateFor(id), deposit(id).railPort);
  bool buyCart(int id) {
    if (!canCommand ||
        railFor(id) == null ||
        carts.where((c) => c.depositId == id).length >= 4 ||
        !_pay(120)) {
      return false;
    }
    carts.add(Cart(id, id: carts.length));
    return true;
  }

  bool upgradeMineStorage(int id) {
    final storage = deposit(id).storage;
    if (!storage.canUpgrade || !_pay(storage.upgradeCost)) return false;
    storage.upgrade();
    return true;
  }

  bool upgradeCart(int id) {
    final cart = carts.firstWhere((c) => c.id == id);
    if (!cart.canUpgrade || !_pay(cart.upgradeCost)) return false;
    cart.upgrade();
    return true;
  }

  int maxUpgradeLevel(Upgrade kind) => kind == Upgrade.processing ? 3 : 4;
  double upgradePrice(Upgrade kind) => switch (kind) {
    Upgrade.workers => 180.0 + levels[kind]! * 150,
    Upgrade.speed => 180.0 + levels[kind]! * 140,
    Upgrade.scanner => 120.0 + levels[kind]! * 100,
    Upgrade.storage => 150.0 + levels[kind]! * 120,
    Upgrade.processing => 220.0 + levels[kind]! * 220,
  };
  bool upgrade(Upgrade kind) {
    if (levels[kind]! >= maxUpgradeLevel(kind) || !_pay(upgradePrice(kind))) {
      return false;
    }
    levels[kind] = levels[kind]! + 1;
    if (kind == Upgrade.storage) factory.expand(levels[kind]!);
    if (kind == Upgrade.processing) factory.refinery.level = levels[kind]!;
    return true;
  }

  double price(MineralSpec mineral) => trade.price(0, elapsed);
  double marketPrice(MineralSpec mineral, int market) =>
      trade.price(market, elapsed);
  bool orderSale(int id, double quantity) =>
      canCommand && trade.placeOrder(id, quantity, elapsed) != null;
  bool splitSale(double first, double second) =>
      canCommand && trade.split(first, second, elapsed);
  double cancelSale(int id) => canCommand ? trade.cancelPending(id) : 0;
  double sell(String id) {
    if (!canCommand || id != 'gold') return 0;
    final amount = trade.available;
    return orderSale(saleMarket, amount) ? amount : 0;
  }

  void sellAll() => sell('gold');
  void tick(double seconds) {
    if (!active || !seconds.isFinite || seconds <= 0) return;
    var remaining = min(seconds, timeLeft);
    while (remaining > 1e-7) {
      final dt = min(.1, remaining);
      _step(dt);
      remaining -= dt;
    }
    if (timeLeft < 1e-7) {
      elapsed = stage.seconds;
      finished = true;
      message = '작업 종료. 가게까지 도착한 금만 수익에 포함됩니다.';
    }
  }

  void _step(double dt) {
    elapsed = min(stage.seconds, elapsed + dt);
    for (final scout in scouts) {
      if (scout.found) continue;
      scout.age = min(
        scout.duration,
        scout.age + dt * (1 + levels[Upgrade.scanner]! * .25),
      );
      final t = scout.age / scout.duration,
          p = scout.start.towards(scout.hint, t);
      scout.point = Point2(
        p.x + sin(t * pi * 6) * .012 / mapScale * (1 - t),
        p.y,
      );
      if (scout.found) {
        scout.point = scout.hint;
        final mine = deposit(scout.depositId);
        mine.discovered = true;
        mine.exposedPoint ??= scout.hint;
        surveys.add(Survey(scout.hint, .023));
        final worker = Worker(workers.length)
          ..shaftId = mine.id
          ..arrivesAt = elapsed;
        workers.add(worker);
        mine.workforce.add(worker);
      }
    }
    network.update(dt);
    production.update(deposits, elapsed, dt, workerRate);
    transport.update(carts, deposits, network, factory, dt, speed);
    factory.refinery.update(dt, factory.rawOre, factory.gold);
    trade.update(dt);
  }

  void finishEarly() {
    if (canCommand) {
      finished = true;
      message = '작업을 마쳤어요.';
    }
  }
}
