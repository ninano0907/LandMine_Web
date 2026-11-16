import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Moving parts in the fixed 1672x941, wide, southwest-facing factory artwork.
/// No structure or image anchor moves between animation phases.
void paintFactoryAnimation(Canvas canvas, int frame) {
  final phase = frame % 4;
  final paint = Paint();
  const hub = Offset(1088, 708);
  paint
    ..color = const Color(0xff66584b)
    ..strokeWidth = 8;
  for (var i = 0; i < 8; i++) {
    final angle = i * math.pi / 4 + phase * math.pi / 16;
    canvas.drawLine(
      hub,
      hub + Offset(math.cos(angle) * 43, math.sin(angle) * 56),
      paint,
    );
  }
  canvas.drawCircle(hub, 12, paint..color = const Color(0xffb58f66));
  canvas.drawCircle(hub, 5, paint..color = const Color(0xff4b3b30));
  final stroke = [0.0, 9.0, 0.0, -9.0][phase];
  paint
    ..strokeWidth = 8
    ..color = const Color(0xffbdab94);
  canvas.drawLine(Offset(1207, 717 + stroke), const Offset(1207, 753), paint);
  canvas.drawRect(
    Rect.fromLTWH(1198, 709 + stroke, 18, 10),
    paint..color = const Color(0xff80684c),
  );
  // Ore follows the belt's diagonal world orientation, not a screen-horizontal line.
  for (var i = 0; i < 5; i++) {
    final t = (i / 5 + phase / 20) % 1;
    final x = 370 + 530 * t, y = 430 + 222 * t;
    final nugget = Path()
      ..moveTo(x, y)
      ..lineTo(x + 13, y + 5)
      ..lineTo(x + 5, y + 13)
      ..lineTo(x - 10, y + 6)
      ..close();
    canvas.drawPath(nugget, paint..color = const Color(0xffbc8a2b));
    canvas.drawCircle(
      Offset(x + 2, y + 4),
      4,
      paint..color = const Color(0xffffdb6d),
    );
  }
  for (var i = 0; i < 3; i++) {
    final x = 401.0 + i * 13;
    final h = [10.0, 16.0, 13.0, 20.0][(phase + i) % 4];
    final flame = Path()
      ..moveTo(x, 306)
      ..quadraticBezierTo(x - 3, 299, x + 5, 306 - h)
      ..quadraticBezierTo(x + 5, 298, x + 11, 306)
      ..close();
    canvas.drawPath(
      flame,
      paint
        ..color = i.isEven ? const Color(0xffffa51e) : const Color(0xffffd956),
    );
  }
  paint
    ..style = PaintingStyle.stroke
    ..strokeWidth = 7
    ..strokeCap = StrokeCap.round
    ..color = const Color(0xffbadde0);
  canvas.drawPath(
    Path()
      ..moveTo(1259, 813)
      ..quadraticBezierTo(1258 + phase * 1.5, 824, 1257, 833),
    paint,
  );
  paint
    ..strokeWidth = 3
    ..color = const Color(0xffe5eecc);
  canvas.drawOval(
    Rect.fromCenter(
      center: const Offset(1257, 835),
      width: 18 + phase * 5,
      height: 5.0 + phase,
    ),
    paint,
  );
  paint.style = PaintingStyle.fill;
  for (var i = 0; i < 4; i++) {
    final age = (i + phase / 4) / 4;
    paint.color = Color.fromRGBO(118, 111, 101, (1 - age) * .6);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(1407 + age * 35, 555 - age * 90),
        width: 26 + age * 40,
        height: 17 + age * 26,
      ),
      paint,
    );
  }
}
