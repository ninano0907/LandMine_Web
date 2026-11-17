import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/frontier/screen.dart';
import '../tool/frontier_checks.dart';

void main() {
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
      expect(find.text('황금의 철마'), findsOneWidget);
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
