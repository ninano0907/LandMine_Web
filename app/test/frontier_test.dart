import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mine_path/frontier/simulation.dart';
import 'package:mine_path/frontier/screen.dart';
import 'package:mine_path/frontier/painter.dart';
import '../tool/frontier_checks.dart';

void main() {
  testWidgets('hero movement advances on each display frame', (tester) async {
    final game = FrontierGame();
    await tester.pumpWidget(
      MaterialApp(home: FrontierScreen(initialGame: game)),
    );
    await tester.pump();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    var previousX = game.defense.hero.position.dx;
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      final currentX = game.defense.hero.position.dx;
      expect(currentX - previousX, closeTo(195 * .016, .001));
      previousX = currentX;
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.pump(const Duration(milliseconds: 16));
    expect(game.defense.hero.position.dx, previousX);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('camera pans without rebuilding the map or HUD', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FrontierScreen()));
    await tester.pump();
    final map = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is FrontierPainter,
    );
    final painter = tester.widget<CustomPaint>(map).painter! as FrontierPainter;
    final topBar = tester.widget(find.textContaining('황금의 철마'));
    final start = painter.camera;
    final gesture = await tester.startGesture(tester.getCenter(map));
    // Cross the drag threshold, then send incremental camera movement.
    await gesture.moveBy(const Offset(-30, 0));
    await gesture.moveBy(const Offset(-20, -10));
    expect(painter.camera.dx, greaterThan(start.dx));
    final afterPan = painter.camera;
    await gesture.moveBy(const Offset(-10, 0));
    expect(painter.camera.dx, greaterThan(afterPan.dx));
    expect(identical(tester.widget<CustomPaint>(map).painter, painter), isTrue);
    expect(
      identical(tester.widget(find.textContaining('황금의 철마')), topBar),
      isTrue,
    );
    await gesture.up();
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('follow camera advances between HUD updates', (tester) async {
    final game = FrontierGame();
    await tester.pumpWidget(
      MaterialApp(home: FrontierScreen(initialGame: game)),
    );
    await tester.pump();
    final map = find.byWidgetPredicate(
      (widget) => widget is CustomPaint && widget.painter is FrontierPainter,
    );
    // Keep a delegate reference: its camera must stay current even when no
    // widget rebuild replaces it.
    final painter = tester.widget<CustomPaint>(map).painter! as FrontierPainter;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    var previousCamera = painter.camera.dx;
    for (var frame = 0; frame < 4; frame++) {
      await tester.pump(const Duration(milliseconds: 16));
      expect(painter.camera.dx - previousCamera, closeTo(195 * .016, .001));
      previousCamera = painter.camera.dx;
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.pumpWidget(const SizedBox());
  });

  for (final entry in frontierChecks.entries) {
    test(entry.key, entry.value);
  }
  for (final size in [
    const Size(844, 390),
    const Size(667, 375),
    const Size(390, 844),
  ]) {
    testWidgets('mobile deployment and hero controls at $size', (tester) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(const MaterialApp(home: FrontierScreen()));
      expect(find.textContaining('황금의 철마'), findsOneWidget);
      expect(find.text('공격'), findsOneWidget);
      expect(find.text('구르기'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('방어 봇 배치'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      final firstVein = find.text('탑 1번 광맥');
      await tester.ensureVisible(firstVein);
      await tester.pump();
      await tester.tap(firstVein);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      await tester.tap(find.byKey(const ValueKey('deploy-bot')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      expect(find.text('탑 1/3'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
