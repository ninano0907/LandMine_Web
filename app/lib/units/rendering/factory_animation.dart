import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Moving equipment in the fixed 1536x1024 cutaway gold washing factory.
void paintFactoryAnimation(Canvas canvas, int frame) {
  final phase = frame % 4;
  final paint = Paint();
  const hub = Offset(1029, 549);
  // Rotating spokes remain inside the painted flywheel rim.
  paint
    ..color = const Color(0x99866a50)
    ..strokeWidth = 6;
  for (var i = 0; i < 6; i++) {
    final angle = i * math.pi / 3 + phase * math.pi / 12;
    canvas.drawLine(
      hub,
      hub + Offset(math.cos(angle) * 64, math.sin(angle) * 79),
      paint,
    );
  }
  canvas.drawCircle(hub, 10, paint..color = const Color(0xffb38d63));
  final stroke = [0.0, 7.0, 0.0, -7.0][phase];
  canvas.drawLine(
    Offset(1239, 492 + stroke),
    const Offset(1239, 542),
    paint
      ..color = const Color(0xffb8a48a)
      ..strokeWidth = 8,
  );
  // Ore enters the building from the lower-left end of the conveyor.
  for (var i = 0; i < 7; i++) {
    final t = (i / 7 + phase / 28) % 1;
    final position = Offset.lerp(
      const Offset(155, 869),
      const Offset(485, 566),
      t,
    )!;
    canvas.drawOval(
      Rect.fromCenter(center: position, width: 12, height: 8),
      paint..color = const Color(0xffbda276),
    );
    canvas.drawCircle(
      position + const Offset(-2, -1),
      2,
      paint..color = const Color(0xffe0bf68),
    );
  }
  // Highlights follow the water across the riffle tables and through each drop.
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = 3
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xaad4eff0);
  for (var i = 0; i < 5; i++) {
    final t = (i / 5 + phase / 20) % 1;
    final water = Offset.lerp(
      const Offset(835, 459),
      const Offset(807, 529),
      t,
    )!;
    canvas.drawLine(water, water + const Offset(-5, 10), paint);
    final ripple = Offset(680 + i * 43.0 + phase * 3, 647 - i * 10.0);
    canvas.drawLine(ripple, ripple + const Offset(13, -4), paint);
    final lower = Offset(741 + i * 45.0 + phase * 3, 739 - i * 10.0);
    canvas.drawLine(lower, lower + const Offset(12, -4), paint);
  }
  for (var i = 0; i < 3; i++) {
    final y = 846 + ((i * 17 + phase * 7) % 61);
    canvas.drawLine(
      Offset(1170 + i * 5.0, y.toDouble()),
      Offset(1174 + i * 5.0, y + 12.0),
      paint,
    );
  }
  paint.style = PaintingStyle.fill;
  // Both rear brick chimneys emit smoke in the selected compact design.
  for (final chimney in [const Offset(278, 162), const Offset(1205, 130)]) {
    for (var i = 0; i < 4; i++) {
      final age = (i + phase / 4) / 4;
      paint.color = Color.fromRGBO(125, 124, 116, (1 - age) * .4);
      canvas.drawOval(
        Rect.fromCenter(
          center: chimney + Offset(age * 29, -age * 77),
          width: 32 + age * 33,
          height: 16 + age * 22,
        ),
        paint,
      );
    }
  }
}
