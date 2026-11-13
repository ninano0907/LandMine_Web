import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/main.dart';
import 'package:mine_path/mining/mining_world.dart';
import 'package:mine_path/mining/hud_widgets.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

MiningGame fixture() => MiningGame(
  stage: const StageSpec(
    1,
    'fixture',
    seed: 101,
    deposits: 4,
    seconds: 600,
    startingCash: 10000,
    targetProfit: 100,
  ),
);
void main() {
  test('inventory transfer is bounded and resource types cannot mix', () {
    final a = Inventory(Resource.ore, 100)..put(80),
        b = Inventory(Resource.ore, 50),
        gold = Inventory(Resource.gold, 100);
    expect(a.transferTo(b, 100), 50);
    expect(a.amount, 30);
    expect(b.amount, 50);
    expect(a.transferTo(gold, 20), 0);
    expect(a.transferTo(a, 20), 0);
    expect(a.amount + b.amount, 80);
  });
  test(
    'surveyor converts once and each shaft storage has three independent levels',
    () {
      final g = fixture();
      g.hireScout();
      final scout = g.scouts.single, d = g.deposit(scout.depositId);
      g.tick(scout.duration + 5);
      expect(d.workers, 1);
      expect(g.purchasedWorkers, 1);
      expect(g.availableWorkers, 0);
      expect(d.stock, greaterThan(0));
      expect(g.rails, isEmpty);
      expect(g.stored, 0);
      g.tick(180);
      expect(d.stock, 100);
      final remaining = d.remaining;
      g.tick(10);
      expect(d.remaining, remaining);
      expect(g.upgradeMineStorage(d.id), isTrue);
      expect(d.storage.capacity, 200);
      g.tick(10);
      expect(d.stock, greaterThan(100));
      expect(g.upgradeMineStorage(d.id), isTrue);
      expect(d.storage.capacity, 300);
      expect(g.upgradeMineStorage(d.id), isFalse);
      expect(g.deposits.firstWhere((m) => m.id != d.id).storage.capacity, 100);
      expect(g.purchasedWorkers, 1);
      g.buyWorker();
      expect(g.availableWorkers, 1);
      g.assignWorker(d.id);
      expect(d.workers, 2);
      g.removeWorker(d.id);
      expect(g.availableWorkers, 1);
    },
  );
  test('cart 200 fills completely and partial loads cannot wait forever', () {
    final g = fixture();
    final mine = g.deposits.first;
    g.scan(mine.point);
    g.upgradeMineStorage(mine.id);
    g.upgradeMineStorage(mine.id);
    mine.deposit.remaining -= 300;
    mine.storage.ore.put(300);
    expect(g.connect(mine.id), isTrue);
    final cart = g.carts.single;
    expect(cart.capacity, 50);
    g.upgradeCart(cart.id);
    expect(cart.capacity, 100);
    g.upgradeCart(cart.id);
    expect(cart.capacity, 200);
    expect(g.upgradeCart(cart.id), isFalse);
    cart.state = CartState.loading;
    cart.progress = 1;
    // Finish the route first, then isolate an uninterrupted loading operation.
    for (final s in g.trackSegments) {
      s.construction = 1;
    }
    g.tick(10.2);
    expect(cart.cargo, closeTo(200, .001));
    expect(cart.returning, isTrue);
    g.tick(120);
    expect(g.factory.refinery.consumedOre, closeTo(300, .001));
    expect(g.stored, closeTo(150, .001));
    expect(mine.stock, 0);
  });
  test('refinery converts only raw ore and blocks on a full gold vault', () {
    final factory = MiningFactory();
    factory.rawOre.put(20);
    factory.refinery.update(1, factory.rawOre, factory.gold);
    expect(factory.rawOre.amount, 17);
    expect(factory.gold.amount, 1.5);
    expect(factory.refinery.consumedOre, 3);
    factory.gold.put(factory.gold.free);
    factory.refinery.update(100, factory.rawOre, factory.gold);
    expect(factory.rawOre.amount, 17);
  });
  test('full factory storage blocks carts without dropping ore', () {
    final g = fixture();
    g.scan(g.deposits.first.point);
    g.connect(0);
    for (final segment in g.trackSegments) {
      segment.construction = 1;
    }
    final cart = g.carts.single
      ..state = CartState.unloading
      ..progress = 0;
    cart.hold.put(50);
    g.factory.rawOre.put(500);
    g.factory.gold.put(300);
    g.tick(10);
    expect(cart.cargo, 50);
    expect(cart.state, CartState.unloading);
    expect(g.rawStored, 500);
    g.factory.gold.take(100);
    g.tick(31);
    expect(cart.cargo, closeTo(0, .001));
    expect(
      g.rawStored + cart.cargo + g.factory.refinery.consumedOre,
      closeTo(550, .001),
    );
    expect(g.stored, closeTo(200 + g.factory.refinery.producedGold, .001));
  });
  test(
    'four gates create independent factory roots and reject body crossings',
    () {
      final g = fixture();
      g.deposits.clear();
      const points = [
        Point2(.5, .2),
        Point2(.8, .5),
        Point2(.5, .8),
        Point2(.2, .5),
      ];
      for (var i = 0; i < 4; i++) {
        g.deposits.add(MineShaft(i, handEra.minerals.first, points[i], 500));
        g.scan(points[i]);
        expect(g.connect(i), isTrue);
        expect(g.railFor(i)!.gateId, i);
      }
      expect(g.trackNodes.where((n) => n.parentId == null).length, 4);
      final cash = g.cash;
      expect(g.buildTrack(0, const Point2(.5, .7)), isFalse);
      expect(g.cash, cash);
    },
  );
  test('rails branch at junctions but cannot cross or overlap', () {
    final g = fixture();
    expect(g.buildTrack(0, const Point2(.35, .3)), isTrue);
    expect(g.buildTrack(4, const Point2(.65, .3)), isTrue);
    expect(g.buildTrack(0, const Point2(.65, .4)), isTrue);
    final cash = g.cash;
    expect(g.buildTrack(6, const Point2(.5, .2)), isFalse);
    expect(g.cash, cash);
    expect(g.trackSegments.length, 3);
    expect(g.buildTrack(4, const Point2(.2, .2)), isTrue);
    expect(
      g.buildTrack(
        0,
        g.factory.gates[0].point.towards(const Point2(.35, .3), .5),
      ),
      isFalse,
    );
  });
  test(
    'sale allocation reserves gold; loaded cargo is immutable and paid only at the shop',
    () {
      final g = fixture();
      g.factory.gold.put(100);
      expect(g.splitSale(80, 40), isFalse);
      expect(g.trade.orders, isEmpty);
      expect(g.splitSale(60, 40), isTrue);
      expect(g.trade.reserved, 100);
      expect(g.orderSale(1, 1), isFalse);
      expect(g.revenue, 0);
      g.tick(12);
      expect(g.revenue, 0);
      g.tick(10);
      expect(g.revenue, 0);
      final cargo = g.trade.merchants[0].cargo.amount;
      expect(cargo, greaterThan(0));
      final pending = g.trade.pendingFor(0);
      expect(g.cancelSale(0), closeTo(pending, .00001));
      expect(g.trade.merchants[0].cargo.amount, cargo);
      final free = g.trade.available;
      expect(g.orderSale(1, free), isTrue);
      g.tick(110);
      expect(g.trade.deliveredGold, closeTo(100, .001));
      expect(g.stored, closeTo(0, .001));
      final invoices = g.trade.orders.fold(
        0.0,
        (sum, o) => sum + o.delivered * o.unitPrice,
      );
      expect(g.revenue, closeTo(invoices, .001));
      expect(
        g.trade.orders.every(
          (o) =>
              (o.quantity - o.pending - o.inTransit - o.delivered - o.cancelled)
                  .abs() <
              .00001,
        ),
        isTrue,
      );
      final time = g.elapsed;
      g.paused = true;
      g.tick(100);
      expect(g.elapsed, time);
      g.paused = false;
      g.finishEarly();
      final cash = g.cash;
      g.tick(10);
      expect(g.cash, cash);
      expect(g.orderSale(0, 1), isFalse);
    },
  );
  for (final size in [const Size(844, 390), const Size(1024, 768)]) {
    testWidgets('buy scout, allocate workforce and draw rail at $size', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(size);
      addTearDown(() => tester.binding.setSurfaceSize(null));
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MiningApp());
      final field = find.byWidgetPredicate((w) => w is GameWidget<MiningWorld>);
      final scene = (tester.widget(field) as GameWidget<MiningWorld>).game!;
      for (var i = 0; i < 20 && !scene.isLoaded; i++) {
        await tester.pump(const Duration(milliseconds: 10));
      }
      expect(scene.isLoaded, isTrue);
      expect(scene.field.size.x, 3000);
      expect(scene.field.size.y, 1200);
      expect(scene.simulation.episode.minerals.single.id, 'gold');
      expect(MiningGame.entrance.x, .5);
      expect(MiningGame.entrance.y, .5);
      final mapRect = tester.getRect(field);
      expect(mapRect.bottom, size.height);
      final factory = scene.screenPosition(MiningGame.entrance);
      expect(factory.x, closeTo(mapRect.width / 2, .01));
      expect(factory.y, closeTo(mapRect.height / 2, .01));
      expect(find.byKey(const ValueKey('pan')), findsNothing);
      expect(find.byKey(const ValueKey('zoom-in')), findsNothing);
      expect(find.byKey(const ValueKey('map-home')), findsNothing);
      expect(find.text('◀ 마을'), findsNothing);
      final focal = Offset(
        mapRect.left + mapRect.width * .6,
        mapRect.top + mapRect.height * .65,
      );
      final zoom = scene.camera.viewfinder.zoom;
      final left = await tester.startGesture(
        focal - const Offset(45, 0),
        pointer: 1,
      );
      final right = await tester.startGesture(
        focal + const Offset(45, 0),
        pointer: 2,
      );
      await left.moveTo(focal - const Offset(80, 0));
      await right.moveTo(focal + const Offset(80, 0));
      await tester.pump();
      expect(scene.camera.viewfinder.zoom, greaterThan(zoom));
      final spreadZoom = scene.camera.viewfinder.zoom;
      final xBeforePan = scene.camera.viewfinder.position.x;
      await left.moveBy(const Offset(-40, -20));
      await right.moveBy(const Offset(-40, -20));
      await tester.pump();
      expect(scene.camera.viewfinder.position.x, greaterThan(xBeforePan));
      await left.moveTo(focal + const Offset(-40, -20) - const Offset(45, 0));
      await right.moveTo(focal + const Offset(-40, -20) + const Offset(45, 0));
      await tester.pump();
      expect(scene.camera.viewfinder.zoom, lessThan(spreadZoom));
      await left.up();
      await right.up();
      await tester.pump();
      expect(scene.simulation.trackSegments, isEmpty);
      expect(scene.simulation.surveys, isEmpty);
      scene.resetCamera();
      await tester.pump();

      expect(
        tester.getRect(find.byKey(const ValueKey('scout'))).top,
        lessThan(20),
      );
      await tester.tap(find.byKey(const ValueKey('scout')));
      await tester.pump();
      final scout = scene.simulation.scouts.single;
      scene.simulation.tick(scout.duration + 5);
      scene.update(.1);
      await tester.pump();
      final d = scene.simulation.deposit(scout.depositId);
      expect(d.workers, 1);
      expect(scene.simulation.rails, isEmpty);
      await tester.tap(find.byKey(const ValueKey('hire')));
      await tester.pump();
      expect(scene.simulation.availableWorkers, 1);
      final badge = find.byKey(ValueKey('entrance-${d.id}'));
      expect(tester.getSize(badge).width, lessThan(50));
      expect(tester.getSize(badge).height, lessThanOrEqualTo(24));
      await tester.tap(badge);
      await tester.pump();
      expect(tester.getSize(badge).width, lessThan(40));
      expect(tester.getSize(badge).height, lessThanOrEqualTo(50));
      await tester.tap(find.byKey(ValueKey('assign-${d.id}')));
      await tester.pump();
      expect(d.workers, 2);
      await tester.tap(find.byKey(ValueKey('remove-${d.id}')));
      await tester.pump();
      expect(d.workers, 1);
      expect(scene.simulation.availableWorkers, 1);
      final number = find.byKey(ValueKey('workers-${d.id}'));
      final numberCenter = tester.getCenter(number);
      final up = await tester.startGesture(numberCenter);
      await up.moveTo(numberCenter - const Offset(0, 20));
      await up.moveBy(const Offset(0, -15));
      await up.up();
      await tester.pump();
      expect(d.workers, 2);
      final down = await tester.startGesture(tester.getCenter(number));
      await down.moveBy(const Offset(0, 20));
      await down.moveBy(const Offset(0, 15));
      await down.up();
      await tester.pump();
      expect(d.workers, 1);
      Offset canvasPoint(Point2 p) {
        final screen = scene.screenPosition(p);
        final rect = tester.getRect(field);
        return Offset(rect.left + screen.x, rect.top + screen.y);
      }

      await tester.tap(find.byKey(ValueKey('mine-storage-${d.id}')));
      await tester.pump(const Duration(milliseconds: 300));
      final storageUpgrade = find.textContaining('용량 200으로 강화');
      await tester.ensureVisible(storageUpgrade);
      await tester.tap(storageUpgrade);
      await tester.pump();
      expect(d.storage.capacity, 200);
      await tester.tap(find.widgetWithText(FrontierButton, '닫기'));
      await tester.pump(const Duration(milliseconds: 300));
      final holes = scene.simulation.surveys.length;
      await tester.tap(find.byKey(const ValueKey('dig')));
      await tester.pump();
      await tester.tapAt(canvasPoint(d.exposedPoint!));
      await tester.pump();
      expect(scene.simulation.surveys.length, holes + 1);
      expect(scene.simulation.exposedFraction(d), lessThan(1));
      await tester.tap(find.byKey(const ValueKey('rail')));
      await tester.pump();

      final source = scene
          .simulation
          .factory
          .gates[scene.simulation.bestGateFor(d.id)]
          .point;
      final railBudget = scene.simulation.cash;
      final railFinger = await tester.startGesture(
        canvasPoint(source),
        pointer: 7,
      );
      await railFinger.moveBy(const Offset(30, 0));
      final cameraFinger = await tester.startGesture(
        canvasPoint(source) + const Offset(0, 65),
        pointer: 8,
      );
      await cameraFinger.moveBy(const Offset(0, 25));
      await railFinger.up();
      await cameraFinger.up();
      await tester.pump();
      expect(scene.simulation.trackSegments, isEmpty);
      expect(scene.simulation.cash, railBudget);
      scene.resetCamera();
      await tester.pump();
      final gate =
          scene.simulation.factory.gates[scene.simulation.bestGateFor(d.id)];
      final middle = switch (gate.direction) {
        GateDirection.north => Point2(gate.point.x, gate.point.y - .06),
        GateDirection.east => Point2(gate.point.x + .025, gate.point.y),
        GateDirection.south => Point2(gate.point.x, gate.point.y + .06),
        GateDirection.west => Point2(gate.point.x - .025, gate.point.y),
      };
      await tester.dragFrom(
        canvasPoint(source),
        canvasPoint(middle) - canvasPoint(source),
      );
      await tester.pump();
      expect(scene.simulation.trackSegments.length, 1);
      await tester.dragFrom(
        canvasPoint(middle),
        canvasPoint(d.railPort) - canvasPoint(middle),
      );
      await tester.pump();
      expect(scene.simulation.railFor(d.id), isNotNull);
      expect(
        scene.simulation.railFor(d.id)!.end.distance(d.railPort),
        lessThan(.000001),
      );
      expect(scene.simulation.railFor(d.id)!.ready, isFalse);
      expect(scene.simulation.carts.single.progress, 0);
      expect(scene.simulation.stored, 0);
      // Both axes use one orthographic scale: excavation footprints are circles.
      final origin = scene.screenPosition(const Point2(.5, .5));
      final dx = scene.screenPosition(
        const Point2(.5 + .05 / MiningGame.mapAspect, .5),
      );
      final dy = scene.screenPosition(const Point2(.5, .55));
      expect((dx - origin).length, closeTo((dy - origin).length, .001));
      await tester.tap(find.byTooltip('수레 1 업그레이드'));
      await tester.pump(const Duration(milliseconds: 300));
      final cartUpgrade = find.widgetWithText(FrontierButton, '강화 \$250');
      await tester.ensureVisible(cartUpgrade);
      await tester.tap(cartUpgrade);
      await tester.pump();
      expect(scene.simulation.carts.single.capacity, 100);
      await tester.tap(find.widgetWithText(FrontierButton, '닫기'));
      await tester.pump(const Duration(milliseconds: 300));
      scene.simulation.factory.gold.put(100);
      scene.update(.1);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('broker-0')));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.ensureVisible(find.byKey(const ValueKey('sell-half')));
      await tester.tap(find.byKey(const ValueKey('sell-half')));
      await tester.pump();
      final confirm = find.byKey(const ValueKey('confirm-sale'));
      await tester.ensureVisible(confirm);
      await tester.tap(confirm);
      await tester.pump(const Duration(milliseconds: 300));
      expect(scene.simulation.trade.orders.length, 2);
      expect(
        scene.simulation.trade.orders.every((o) => o.quantity == 50),
        isTrue,
      );
      expect(scene.simulation.revenue, 0);
      scene.simulation.tick(100);
      scene.update(.1);
      await tester.pump();
      expect(scene.simulation.trade.deliveredGold, closeTo(100, .001));
      expect(scene.simulation.revenue, greaterThan(0));
      await tester.tap(find.byTooltip('탐사인 0 업그레이드'));
      await tester.pump();
      expect(find.text('탐사 속도 1'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.settings));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('광산 마을'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('광산 마을'), findsOneWidget);
      expect(find.text('작업장'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
