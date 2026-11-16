import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../game_unit.dart';
import '../animation.dart';
import '../direction.dart';
import '../characters/engineer.dart';
import '../characters/soldier.dart';
import '../characters/shotgun.dart';
import '../combat/ranged_unit.dart';
import 'unit_sprites.dart';
import 'factory_animation.dart';
import '../../buildings/command_center.dart';
import '../../buildings/barracks.dart';
import '../../resources/mineral_deposit.dart';

class UnitLabPainter extends CustomPainter {
  const UnitLabPainter(
    this.unit,
    this.selected,
    this.sprites,
    this.minerals,
    this.commandCenter,
    this.factoryFrame,
    this.targets, {
    this.units = const [],
    this.barracks,
    this.barracksSelected = false,
  });
  final List<GameUnit> units;
  final Barracks? barracks;
  final bool barracksSelected;
  final List<GameUnit> targets;
  final CommandCenter commandCenter;
  final int factoryFrame;
  final GameUnit unit;
  final bool selected;
  final UnitSprites sprites;
  final List<MineralDeposit> minerals;
  Offset? get miningTarget {
    final target = unit.workTarget;
    return target == null ? null : Offset(target.x, target.y);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0xff23333c);
    canvas.drawRect(Offset.zero & size, paint);
    paint
      ..color = const Color(0xff30454f)
      ..strokeWidth = 1;
    for (var x = 0.0; x <= size.width; x += commandCenter.grid.tileSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (var y = 0.0; y <= size.height; y += commandCenter.grid.tileSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
    paintMineralBank(canvas);
    paintShootingRange(canvas);
    paintTargets(canvas);
    final characters = [
      ...(units.isEmpty ? [unit] : units),
    ]..sort((a, b) => a.position.y.compareTo(b.position.y));
    var buildingPainted = false;
    for (final character in characters) {
      if (!buildingPainted &&
          character.position.y >= commandCenter.top + commandCenter.height) {
        paintCommandCenter(canvas);
        paintBarracks(canvas);
        buildingPainted = true;
      }
      UnitLabPainter(
        character,
        selected && identical(character, unit),
        sprites,
        minerals,
        commandCenter,
        factoryFrame,
        const [],
      ).paintCharacter(canvas, Paint());
    }
    if (!buildingPainted) {
      paintCommandCenter(canvas);
      paintBarracks(canvas);
    }
  }

  void paintBarracks(Canvas canvas) {
    final building = barracks;
    if (building == null) return;
    final area = Rect.fromLTWH(
      building.left,
      building.top,
      building.width,
      building.height,
    );
    if (barracksSelected) {
      canvas.drawRect(
        area,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = Colors.lightGreenAccent,
      );
    }
    final image = sprites[UnitSprites.barracksAsset];
    if (image != null) {
      final width = building.width * 1.2;
      final height = width * image.height / image.width;
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        Rect.fromLTWH(
          area.center.dx - width / 2,
          area.bottom - height + 4,
          width,
          height,
        ),
        Paint()..filterQuality = FilterQuality.none,
      );
    } else {
      canvas.drawRect(
        area.deflate(6),
        Paint()..color = const Color(0xff6c7562),
      );
    }
    final label = TextPainter(
      text: const TextSpan(
        text: '훈련소 · 보병 / 산탄병',
        style: TextStyle(color: Colors.amberAccent, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(area.left, area.bottom + 5));
  }

  void paintMineralBank(Canvas canvas) {
    final active = minerals.where((deposit) => !deposit.depleted).toList();
    if (active.isEmpty) return;
    Rect tileBounds(MineralDeposit deposit) => Rect.fromLTWH(
      deposit.position.x - MineralDeposit.width / 2,
      deposit.position.y - MineralDeposit.height + MineralDeposit.bottomOffset,
      MineralDeposit.width,
      MineralDeposit.height,
    );
    double ridge(double x) =>
        12 + math.sin(x * 0.036) * 7 + math.sin(x * 0.091) * 3;
    Path cliffTile(MineralDeposit deposit) {
      final rect = tileBounds(deposit);
      final path = Path()..moveTo(rect.left, rect.bottom);
      for (var x = rect.left; x <= rect.right; x += 4) {
        path.lineTo(x, rect.top + ridge(x));
      }
      path.lineTo(rect.right, rect.bottom);
      return path..close();
    }

    var bank = cliffTile(active.first);
    for (final deposit in active.skip(1)) {
      bank = Path.combine(PathOperation.union, bank, cliffTile(deposit));
    }
    final bounds = bank.getBounds();
    canvas.drawPath(
      bank.shift(const Offset(0, 5)),
      Paint()..color = const Color(0x65000000),
    );
    canvas.drawPath(
      bank,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xffa4a294), Color(0xff827f74), Color(0xff50574e)],
        ).createShader(bounds),
    );
    canvas.save();
    canvas.clipPath(bank);
    // Long irregular vertical faces give the connected mass its cliff silhouette.
    for (var i = 0; i < 100; i++) {
      final x = bounds.left + i * 7.0;
      if (x > bounds.right) break;
      final bend = math.sin(i * 2.3) * 4;
      final face = Path()
        ..moveTo(x, bounds.top - 5)
        ..lineTo(x + 5, bounds.top - 5)
        ..lineTo(x + 3 + bend, bounds.center.dy)
        ..lineTo(x + 8 + bend, bounds.bottom)
        ..lineTo(x + bend, bounds.bottom)
        ..lineTo(x - 2 + bend, bounds.center.dy)
        ..close();
      canvas.drawPath(
        face,
        Paint()
          ..color = i % 3 == 0
              ? const Color(0x668b8b7e)
              : const Color(0x55505249),
      );
      final crack = Path()
        ..moveTo(x + 2, bounds.top + (i % 4) * 5)
        ..lineTo(x + bend, bounds.center.dy - 7)
        ..lineTo(x - 2 + bend, bounds.center.dy + 9)
        ..lineTo(x + 3 + bend, bounds.bottom);
      canvas.drawPath(
        crack,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = i % 5 == 0 ? 2.2 : 0.8
          ..color = const Color(0x99606455),
      );
      if (i % 9 == 3) {
        canvas.drawPath(
          crack,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 0.45
            ..color = const Color(0xffc3a361),
        );
      }
    }
    // Vegetation hugs the ridge instead of covering the exposed rock wall.
    for (final deposit in active) {
      final rect = tileBounds(deposit);
      final crown = Path()..moveTo(rect.left, rect.top + ridge(rect.left));
      for (var x = rect.left; x <= rect.right; x += 4) {
        crown.lineTo(x, rect.top + ridge(x));
      }
      for (var x = rect.right; x >= rect.left; x -= 4) {
        crown.lineTo(x, rect.top + ridge(x) + 7 + math.sin(x * .17) * 3);
      }
      crown.close();
      canvas.drawPath(crown, Paint()..color = const Color(0xff435c37));
      for (var x = rect.left + 3; x < rect.right; x += 9) {
        canvas.drawCircle(
          Offset(x, rect.top + ridge(x) + 3),
          2 + (math.sin(x) + 1),
          Paint()..color = const Color(0xff617343),
        );
      }
    }
    // Small dark patches and ledges break up the vertical pillars naturally.
    for (var i = 0; i < 58; i++) {
      final x = bounds.left + i * 11.3;
      final y = bounds.top + 28 + (i * 19 % 49);
      canvas.drawLine(
        Offset(x, y),
        Offset(x + 4 + i % 5, y - 2),
        Paint()
          ..color = const Color(0x66626955)
          ..strokeWidth = 1.2,
      );
    }
    canvas.restore();
    for (final deposit in active) {
      if (Offset(deposit.position.x, deposit.position.y) == miningTarget) {
        canvas.drawOval(
          Rect.fromCenter(
            center: Offset(deposit.position.x, deposit.position.y),
            width: 54,
            height: 10,
          ),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5
            ..color = const Color(0x99e0bf67),
        );
      }
    }
  }

  void paintShootingRange(Canvas canvas) {
    final current = unit;
    if (current is! RangedUnit) return;
    if (selected && current is ShotgunUnit) {
      final origin = Offset(current.position.x, current.position.y);
      final arc = current.spread.arc;
      final cone = Path()
        ..moveTo(origin.dx, origin.dy)
        ..arcTo(
          Rect.fromCircle(center: origin, radius: current.stats.attackRange),
          current.facing - arc / 2,
          arc,
          false,
        )
        ..close();
      canvas.drawPath(cone, Paint()..color = const Color(0x25ffd36a));
    }
    if (current.animation.motion == UnitMotion.attack &&
        current.animation.frame <= 1) {
      final from = Offset(current.position.x, current.position.y - 30);
      for (final target in current.lastHits.keys) {
        canvas.drawLine(
          from,
          Offset(target.position.x, target.position.y - 27),
          Paint()
            ..color = const Color(0xbbffdc91)
            ..strokeWidth = 1,
        );
      }
    }
  }

  void paintTargets(Canvas canvas) {
    for (final target in targets) {
      final x = target.position.x, y = target.position.y;
      final paint = Paint()..color = const Color(0xff79583c);
      canvas.drawRect(Rect.fromLTWH(x - 4, y - 31, 8, 32), paint);
      canvas.drawOval(
        Rect.fromCenter(center: Offset(x, y - 29), width: 28, height: 34),
        paint
          ..color = target.alive
              ? const Color(0xffd9be8b)
              : const Color(0xff62594a),
      );
      canvas.drawCircle(
        Offset(x, y - 29),
        9,
        paint..color = const Color(0xffa14230),
      );
      canvas.drawCircle(
        Offset(x, y - 29),
        4,
        paint..color = const Color(0xffefddad),
      );
      canvas.drawRect(
        Rect.fromLTWH(x - 17, y - 52, 34, 4),
        paint..color = Colors.black54,
      );
      canvas.drawRect(
        Rect.fromLTWH(
          x - 17,
          y - 52,
          34 * target.health / target.stats.maxHealth,
          4,
        ),
        paint..color = Colors.lightGreenAccent,
      );
      final label = TextPainter(
        text: TextSpan(
          text: '${target.health}',
          style: const TextStyle(color: Colors.white70, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      label.paint(canvas, Offset(x - label.width / 2, y + 4));
    }
  }

  void paintCommandCenter(Canvas canvas) {
    final area = Rect.fromLTWH(
      commandCenter.left,
      commandCenter.top,
      commandCenter.width,
      commandCenter.height,
    );
    final paint = Paint()..color = const Color(0x554c3826);
    canvas.drawRect(area, paint);
    paint
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..color = const Color(0xffa78c55);
    canvas.drawRect(area, paint);
    final image = sprites[UnitSprites.factoryAsset];
    if (image != null) {
      // Visual proportions are independent of the fixed logical 4x3 footprint.
      final width = commandCenter.width * 1.5;
      final height = width * image.height / image.width;
      final destination = Rect.fromLTWH(
        area.center.dx - width / 2,
        area.bottom - height + 4,
        width,
        height,
      );
      canvas.drawImageRect(
        image,
        Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
        destination,
        Paint()..filterQuality = FilterQuality.none,
      );
      canvas.save();
      canvas.translate(destination.left, destination.top);
      canvas.scale(width / image.width);
      paintFactoryAnimation(canvas, factoryFrame);
      canvas.restore();
    } else {
      canvas.drawRect(
        area.deflate(6),
        Paint()..color = const Color(0xff795331),
      );
    }
    final label = TextPainter(
      text: TextSpan(
        text:
            '커맨드 센터 · ${commandCenter.area.width}×${commandCenter.area.height}칸',
        style: TextStyle(color: Colors.amberAccent, fontSize: 11),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    label.paint(canvas, Offset(area.left, area.bottom + 5));
  }

  void paintCharacter(Canvas canvas, Paint paint) {
    final current = unit;
    final smallWorker = current is EngineerUnit || current is RangedUnit;
    if (smallWorker) {
      canvas.save();
      canvas.translate(unit.position.x, unit.position.y);
      canvas.scale(0.5);
      canvas.translate(-unit.position.x, -unit.position.y);
    }
    paintBody(canvas, paint);
    if (current is EngineerUnit &&
        current.hasCargo &&
        (sprites[UnitSprites.carryAsset] == null ||
            current.animation.motion == UnitMotion.repair)) {
      final x = current.position.x + 20, y = current.position.y - 21;
      canvas.drawPath(
        Path()
          ..moveTo(x, y - 9)
          ..lineTo(x + 7, y)
          ..lineTo(x, y + 8)
          ..lineTo(x - 7, y)
          ..close(),
        Paint()..color = Colors.amberAccent,
      );
    }
    if (smallWorker) canvas.restore();
  }

  void paintBody(Canvas canvas, Paint paint) {
    final position = Offset(unit.position.x, unit.position.y);
    if (unit.destination case final target?) {
      final end = Offset(target.x, target.y);
      paint
        ..color = Colors.white38
        ..style = PaintingStyle.stroke;
      canvas.drawLine(position, end, paint);
      canvas.drawCircle(end, 8, paint);
    }
    if (selected) {
      paint
        ..color = Colors.lightGreenAccent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      canvas.drawOval(
        Rect.fromCenter(center: position, width: 44, height: 32),
        paint,
      );
    }
    final motion = unit.animation.motion;
    final frame = unit.animation.frame;
    final current = unit;
    if (current is EngineerUnit) {
      final requested = switch (motion) {
        UnitMotion.mine => UnitSprites.mineAsset,
        UnitMotion.repair => UnitSprites.workAsset,
        _ => current.hasCargo ? UnitSprites.carryAsset : UnitSprites.walkAsset,
      };
      var sprite = sprites[requested];
      var imageFrame = motion == UnitMotion.idle || motion == UnitMotion.attack
          ? 0
          : frame;
      var imageRow = directionRow(unit.facing);
      var columns = 8;
      var rows = 8;
      if (sprite == null) {
        sprite = sprites[UnitSprites.walkAsset];
        imageFrame = 0;
      }
      if (sprite == null) {
        sprite = sprites[UnitSprites.idleAsset];
        columns = 1;
        rows = 1;
        imageFrame = 0;
        imageRow = 0;
      }
      if (sprite != null) {
        final cellWidth = sprite.width / columns;
        final cellHeight = sprite.height / rows;
        const spriteSize = 72.0;
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(
            imageFrame * cellWidth,
            imageRow * cellHeight,
            cellWidth,
            cellHeight,
          ),
          Rect.fromLTWH(
            position.dx - spriteSize / 2,
            position.dy - spriteSize + 5,
            spriteSize,
            spriteSize,
          ),
          Paint()..filterQuality = FilterQuality.none,
        );
        return;
      }
      // Keep a visible placeholder even when every image is unavailable.
    }
    if (current is RangedUnit) {
      final shotgun = current is ShotgunUnit;
      final walking = shotgun
          ? UnitSprites.shotgunWalkAsset
          : UnitSprites.pistolWalkAsset;
      final firing = shotgun
          ? UnitSprites.shotgunFireAsset
          : UnitSprites.pistolFireAsset;
      final attacking = motion == UnitMotion.attack;
      final sprite = sprites[attacking ? firing : walking] ?? sprites[walking];
      if (sprite != null) {
        final imageFrame =
            motion == UnitMotion.idle || (attacking && sprites[firing] == null)
            ? 0
            : frame;
        final columns = shotgun && (!attacking || sprites[firing] == null)
            ? 7
            : 8;
        final width = sprite.width / columns, height = sprite.height / 8;
        final displayWidth = 72.0 * width / height;
        canvas.drawImageRect(
          sprite,
          Rect.fromLTWH(
            imageFrame * width,
            directionRow(unit.facing) * height,
            width,
            height,
          ),
          Rect.fromLTWH(
            position.dx - displayWidth / 2,
            position.dy - 67,
            displayWidth,
            72,
          ),
          Paint()..filterQuality = FilterQuality.none,
        );
        return;
      }
    }
    canvas.save();
    canvas.translate(position.dx, position.dy);
    canvas.rotate(unit.facing);
    paint
      ..style = PaintingStyle.fill
      ..color = Colors.black38;
    canvas.drawCircle(const Offset(3, 4), unit.radius, paint);
    paint.color = Color(unit.colorValue);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset.zero, width: 28, height: 24),
        const Radius.circular(6),
      ),
      paint,
    );
    paint.color = const Color(0xff15232c);
    canvas.drawCircle(const Offset(7, -5), 3, paint);
    canvas.drawCircle(const Offset(7, 5), 3, paint);
    if (unit is SoldierUnit) {
      paint
        ..color = Colors.white70
        ..strokeWidth = 5;
      canvas.drawLine(const Offset(10, 0), const Offset(23, 0), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant UnitLabPainter oldDelegate) => true;
}
