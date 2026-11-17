// Socket-free model, mesh animation and mobile interaction checks.
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/main.dart';
import 'package:mine_path/frontier/robot_3d.dart';
import 'package:mine_path/frontier/screen.dart';
import 'package:mine_path/frontier/simulation.dart';
import 'package:mine_path/frontier/defense.dart';
import 'package:mine_path/frontier/painter.dart';
import 'frontier_checks.dart';

Future<void> main() async {
  try {
    for (final check in frontierChecks.entries) {
      check.value();
      stdout.writeln('PASS: ${check.key}');
    }
    final binding = AutomatedTestWidgetsFlutterBinding();
    await binding.runAsync(() async {
      await RobotModel.load();
    });
    for (final size in [
      const Size(844, 390),
      const Size(667, 375),
      const Size(390, 844),
    ]) {
      final key = GlobalKey();
      await binding.runTest(
        () async {
          await binding.setSurfaceSize(size);
          final game = FrontierGame(seed: 1);
          runApp(
            RepaintBoundary(
              key: key,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                home: FrontierScreen(initialGame: game),
              ),
            ),
          );
          await binding.pump();
          await binding.pump(const Duration(milliseconds: 100));
          verify(binding.takeException() == null, 'Initial layout at $size');
          Future<void> tapFinder(Finder finder) async {
            final box = finder.evaluate().single.renderObject! as RenderBox;
            final at = box.localToGlobal(box.size.center(Offset.zero));
            binding.handlePointerEvent(
              PointerDownEvent(pointer: 1, position: at),
            );
            binding.handlePointerEvent(
              PointerUpEvent(pointer: 1, position: at),
            );
            await binding.pump();
          }

          Future<void> tap(String value) => tapFinder(find.text(value));
          await tap('방어 봇 배치');
          await binding.pump(const Duration(milliseconds: 350));
          await tap('탑 1번 광맥');
          await binding.pump(const Duration(milliseconds: 350));
          await tapFinder(find.byKey(const ValueKey('deploy-bot')));
          await binding.pump(const Duration(milliseconds: 350));
          verify(game.defense.veins.first.bot != null, 'Deployment through UI');
          verify(
            find.text('탑 1/3').evaluate().length == 1,
            'Lane status updates',
          );
          // Independent pointers must permit moving and firing together.
          final stick =
              find
                      .byKey(const ValueKey('hero-stick'))
                      .evaluate()
                      .single
                      .renderObject!
                  as RenderBox;
          final stickPoint = stick.localToGlobal(const Offset(70, 44));
          final attackBox =
              find.text('공격').evaluate().single.renderObject! as RenderBox;
          final attackPoint = attackBox.localToGlobal(
            attackBox.size.center(Offset.zero),
          );
          final hero = game.defense.hero;
          final original = hero.position;
          game.defense.enemies.add(
            FieldEnemy(
              id: 99999,
              position: hero.position + const Offset(180, 0),
              attack: EnemyAttack.gun,
              maxHp: 100,
              lane: 1,
            )..cooldown = 100,
          );
          final foe = game.defense.enemies.last;
          binding.handlePointerEvent(
            PointerDownEvent(pointer: 11, position: stickPoint),
          );
          binding.handlePointerEvent(
            PointerDownEvent(pointer: 12, position: attackPoint),
          );
          advance(game, .4);
          await binding.pump();
          verify(
            hero.position.dx > original.dx && foe.hp < 100,
            'Move and fire with two fingers',
          );
          binding.handlePointerEvent(
            PointerUpEvent(pointer: 12, position: attackPoint),
          );
          binding.handlePointerEvent(
            PointerUpEvent(pointer: 11, position: stickPoint),
          );
          await binding.pump();
          verify(
            !hero.firing && hero.input == Offset.zero,
            'Release cancels held controls',
          );
          await tap('구르기');
          verify(game.defense.hero.rolling > 0, 'Roll button works');
          await binding.pump();
          verify(
            binding.takeException() == null,
            'Interaction layout at $size',
          );
          final boundary =
              key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
          await binding.runAsync(() async {
            final image = await boundary.toImage(pixelRatio: 2);
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File(
              '/private/tmp/frontier-${size.width.toInt()}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          runApp(const SizedBox());
          await binding.pump();
        },
        () {},
        description: 'Deployment and mobile controls $size',
      );
      binding.postTest();
      stdout.writeln('PASS: layout and controls $size');
    }
    // Full app entry still points to the new battlefield.
    await binding.runTest(
      () async {
        runApp(const MiningApp());
        await binding.pump();
        verify(find.text('방어 봇 배치').evaluate().length == 1, 'App entry');
        runApp(const SizedBox());
        await binding.pump();
      },
      () {},
      description: 'App entry',
    );
    binding.postTest();
    // Render real 3D animation frames, not a static concept image.
    await binding.runAsync(() async {
      final model = RobotModel.cached!;
      final performance = Stopwatch()..start();
      for (final clip in ['Idle', 'Walk', 'Mine']) {
        for (var frame = 0; frame < 16; frame++) {
          final recorder = ui.PictureRecorder();
          final c = Canvas(recorder);
          c.drawColor(const Color(0xffe7d2a8), BlendMode.src);
          final paint = Paint()
            ..color = const Color(0x33533d27)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
          c.drawOval(const Rect.fromLTWH(160, 285, 450, 130), paint);
          model.paint(
            c,
            const Offset(380, 350),
            clip: clip,
            poseTime: frame / 8,
            modelScale: 1.7,
          );
          final picture = recorder.endRecording();
          final image = await picture.toImage(760, 500);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File(
            '/private/tmp/frontier-robot-$clip-$frame.png',
          ).writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
          picture.dispose();
        }
      }
      stdout.writeln(
        'PASS: 48 3D frames rendered in ${performance.elapsedMilliseconds} ms',
      );
      final preview = FrontierGame(seed: 1)..wave = 3;
      preview.defense.updateCampSpawns(3);
      final camp = preview.defense.camps.first;
      camp.discovered = true;
      preview.defense.hero.position = camp.position + const Offset(150, 60);
      preview.defense.tick(.1);
      preview.defense.hazards.add(
        Hazard(
          HazardKind.blast,
          camp.position,
          preview.defense.hero.position,
          1.15,
          24,
        ),
      );
      final recorder = ui.PictureRecorder();
      final c = Canvas(recorder);
      FrontierPainter(
        preview,
        camp.position - const Offset(440, 240),
        1,
      ).paint(c, const Size(880, 500));
      final picture = recorder.endRecording();
      final image = await picture.toImage(880, 500);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/private/tmp/frontier-rescue-camp.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
      picture.dispose();
    });
    stdout.writeln('FRONTIER CHECKS PASSED');
    exit(0);
  } catch (error, stack) {
    stderr.writeln('FRONTIER CHECK FAILED: $error\n$stack');
    exit(1);
  }
}
