import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'simulation.dart';
import 'defense.dart';

const sand = Color(0xffe8c88c);
const ink = Color(0xff513d30);
const brass = Color(0xffd8a650);
const teal = Color(0xff447e77);

class FrontierPainter extends CustomPainter {
  // Temporary shared visual: all actors use the miner walk atlas.
  // 8 directions (rows) x 8 frames (columns), loaded once in FrontierScreen.
  static ui.Image? testMinerSprite;

  void testMiner(Canvas canvas, Offset at, {double width = 48, double height = 60}) {
    final image = testMinerSprite;
    if (image == null) {
      final fallbackPaint = Paint()..color = const Color(0xffc3944e);
      canvas.drawOval(Rect.fromCenter(center: at + Offset(0, -height / 2),
          width: width * .7, height: height * .85), fallbackPaint);
      return;
    }
    final cellW = image.width / 8.0;
    final cellH = image.height / 8.0;
    final frame = (game.elapsed * 9).floor() % 8;
    const southRow = 2;
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(frame * cellW, southRow * cellH, cellW, cellH),
      Rect.fromLTWH(at.dx - width / 2, at.dy - height, width, height),
      Paint()..filterQuality = FilterQuality.low,
    );
  }
  FrontierPainter(this.game, this.camera, this.zoom);
  final FrontierGame game;
  final Offset camera;
  final double zoom;
  final p = Paint()..isAntiAlias = true;
  void oval(Canvas c, Offset at, double w, double h, Color color) {
    p
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawOval(Rect.fromCenter(center: at, width: w, height: h), p);
  }

  void box(Canvas c, Rect rect, Color color, [double radius = 8]) {
    p
      ..color = color
      ..style = PaintingStyle.fill;
    c.drawRRect(RRect.fromRectAndRadius(rect, Radius.circular(radius)), p);
  }

  void shadedBox(Canvas c, Rect rect, Color color, [double radius = 8]) {
    final shape = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    p
      ..color = const Color(0x253c3024)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    c.drawRRect(shape.shift(const Offset(2, 3)), p);
    p.maskFilter = null;
    p.color = Colors.white;
    p.shader = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(color, const Color(0xffffecc6), .28)!,
        color,
        Color.lerp(color, const Color(0xff293d35), .24)!,
      ],
      stops: const [0, .4, 1],
    ).createShader(rect);
    c.drawRRect(shape, p);
    p.shader = null;
    p
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = const Color(0x55604a30);
    c.drawRRect(shape, p);
    p.style = PaintingStyle.fill;
    line(
      c,
      Offset(rect.left + radius, rect.top + 2),
      Offset(rect.right - radius, rect.top + 2),
      const Color(0x66fff0c8),
      1,
    );
  }

  void shadedOval(Canvas c, Offset at, double w, double h, Color color) {
    final rect = Rect.fromCenter(center: at, width: w, height: h);
    p.color = Colors.white;
    p.shader = RadialGradient(
      center: const Alignment(-.4, -.5),
      radius: 1,
      colors: [
        Color.lerp(color, const Color(0xffffedcc), .35)!,
        color,
        Color.lerp(color, const Color(0xff493b2c), .3)!,
      ],
      stops: const [0, .45, 1],
    ).createShader(rect);
    c.drawOval(rect, p);
    p.shader = null;
  }

  void line(Canvas c, Offset a, Offset b, Color color, double width) {
    p
      ..color = color
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    c.drawLine(a, b, p);
    p.style = PaintingStyle.fill;
  }

  void text(
    Canvas c,
    String value,
    Offset at, {
    double size = 13,
    Color color = ink,
  }) {
    final t = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w800,
          shadows: const [Shadow(color: Color(0x88fff2cf), blurRadius: 3)],
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    t.paint(c, at - Offset(t.width / 2, 0));
  }

  @override
  void paint(Canvas c, Size size) {
    c.drawColor(const Color(0xffc99c64), BlendMode.src);
    c.save();
    c.scale(zoom);
    c.translate(-camera.dx, -camera.dy);
    final visible = Rect.fromLTWH(
      camera.dx - 220,
      camera.dy - 220,
      size.width / zoom + 440,
      size.height / zoom + 440,
    );
    box(c, Offset.zero & FrontierGame.world, sand, 0);
    // Soft sandy patches replace the old tiled military battlefield.
    final rng = math.Random(19);
    for (var i = 0; i < 460; i++) {
      final at = Offset(rng.nextDouble() * 3600, rng.nextDouble() * 2400);
      final r = 20 + rng.nextDouble() * 100;
      if (!visible.contains(at)) continue;
      final patch = Rect.fromCenter(
        center: at,
        width: r * 2.6,
        height: r * 1.4,
      );
      p.color = Colors.white;
      p.shader = const RadialGradient(
        colors: [Color(0x187c9661), Color(0x007c9661)],
      ).createShader(patch);
      c.drawOval(patch, p);
      p.shader = null;
      if (i % 3 == 0) {
        line(c, at, at + const Offset(12, -2), const Color(0x447e714a), 2);
        line(
          c,
          at + const Offset(4, 3),
          at + const Offset(18, 2),
          const Color(0x337e714a),
          1.5,
        );
      }
    }
    for (final route in DefenseWorld.paths) {
      final road = Path()..addPolygon(route, false);
      p
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 94
        ..color = const Color(0x227c5835);
      c.drawPath(road, p);
      p
        ..strokeWidth = 76
        ..color = const Color(0xffe3be7e);
      c.drawPath(road, p);
      p
        ..strokeWidth = 52
        ..color = const Color(0x33f4d9a5);
      c.drawPath(road, p);
      p.style = PaintingStyle.fill;
    }
    oval(c, DefenseWorld.home, 220, 130, const Color(0x446e7651));
    text(c, '아군 본부 · 7시', DefenseWorld.home + const Offset(0, 85), size: 16);
    oval(c, DefenseWorld.enemyHome, 210, 120, const Color(0x448b4631));
    text(
      c,
      '적 진입로 · 1시',
      DefenseWorld.enemyHome + const Offset(0, -90),
      size: 16,
      color: const Color(0xffa34932),
    );
    // A disused railway cuts across the frontier.
    for (var x = 100.0; x < 3500; x += 25) {
      final y = 2100 - x * .13;
      if (!visible.inflate(100).contains(Offset(x, y))) continue;
      line(
        c,
        Offset(x, y - 14),
        Offset(x + 5, y + 14),
        const Color(0xff9b7855),
        5,
      );
    }
    line(
      c,
      const Offset(100, 2079),
      const Offset(3500, 1637),
      const Color(0xff918c76),
      3,
    );
    line(
      c,
      const Offset(100, 2093),
      const Offset(3500, 1651),
      const Color(0xff918c76),
      3,
    );
    final decor = math.Random(71);
    for (var i = 0; i < 230; i++) {
      final at = Offset(
        90 + decor.nextDouble() * 3420,
        90 + decor.nextDouble() * 2220,
      );
      final type = i % 5;
      if (!visible.contains(at) ||
          game.sites.take(1).any((s) => (s.position - at).distance < 220) ||
          game.defense.veins.any((v) => (v.position - at).distance < 145) ||
          DefenseWorld.campCandidates.any((v) => (v - at).distance < 150) ||
          game.defense.jungle.any((v) => (v.position - at).distance < 130) ||
          DefenseWorld.paths.any(
            (route) => List.generate(
              route.length - 1,
              (j) => DefenseWorld.segmentDistance(at, route[j], route[j + 1]),
            ).any((d) => d < 65),
          )) {
        continue;
      }
      if (type == 0) {
        cactus(c, at, .7 + decor.nextDouble() * .6);
      } else if (type == 1) {
        rock(c, at, 35 + decor.nextDouble() * 28);
      } else if (type == 2) {
        oval(c, at + const Offset(2, 4), 40, 16, const Color(0x227c6139));
        for (var j = 0; j < 5; j++) {
          oval(
            c,
            at + Offset((j - 2) * 7.0, -(j % 2) * 8.0),
            20,
            22,
            const Color(0xff9ba765),
          );
        }
      } else if (type == 3) {
        oval(c, at, 10, 5, const Color(0xffc19b62));
      } else {
        rock(c, at, 15);
      }
    }
    for (final site in game.sites.take(1)) {
      if (!visible.contains(site.position)) continue;
      goldSite(c, site);
    }
    for (final vein in game.defense.veins) {
      if (!visible.contains(vein.position)) continue;
      c.save();
      c.translate(vein.position.dx, vein.position.dy);
      c.scale(.6);
      c.translate(-vein.position.dx, -vein.position.dy);
      final site = GoldSite(
        '${DefenseWorld.laneNames[vein.lane]} ${vein.depth + 1}',
        vein.position,
      )..remaining = vein.ore;
      goldSite(c, site);
      c.restore();
      if (vein.bot == null) {
        text(
          c,
          '＋ 봇 배치',
          vein.position + const Offset(0, 65),
          size: 12,
          color: const Color(0xff93692f),
        );
      }
    }
    for (final camp in game.defense.camps) {
      if (!camp.discovered || !visible.contains(camp.position)) continue;
      rescueCamp(c, camp);
    }
    hazards(c);
    if (game.moving) {
      final path = Path()
        ..moveTo(game.robot.dx, game.robot.dy)
        ..lineTo(game.destination!.position.dx, game.destination!.position.dy);
      p
        ..color = const Color(0x6673613e)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3;
      c.drawPath(path, p);
      p.style = PaintingStyle.fill;
    }
    final actors = <({double y, VoidCallback draw})>[
      (y: game.robot.dy, draw: () => machine(c)),
      for (final unit in game.crew)
        (
          y: unit.position.dy,
          draw: () => cowboy(c, unit.position, false, unit.hp),
        ),
      for (final unit in game.raiders)
        (
          y: unit.position.dy,
          draw: () => cowboy(c, unit.position, true, unit.hp),
        ),
      for (final site in game.defense.veins)
        if (site.bot != null && visible.contains(site.bot!.position))
          (y: site.bot!.position.dy, draw: () => defenseBot(c, site)),
      for (final enemy in game.defense.enemies)
        if (visible.contains(enemy.position) &&
            (enemy.campId == null ||
                game.defense.camps
                    .firstWhere((camp) => camp.id == enemy.campId)
                    .discovered))
          (y: enemy.position.dy, draw: () => fieldEnemy(c, enemy)),
      for (final unit in game.defense.companions)
        if (unit.lane != null &&
            visible.contains(game.defense.companionPosition(unit)))
          (
            y: game.defense.companionPosition(unit).dy,
            draw: () => companion(c, unit),
          ),
      if (game.defense.hero.alive)
        (y: game.defense.hero.position.dy, draw: () => playerHero(c)),
    ]..sort((a, b) => a.y.compareTo(b.y));
    for (final actor in actors) {
      actor.draw();
    }
    for (final shot in game.shots) {
      line(
        c,
        shot.from,
        shot.to,
        shot.hostile ? const Color(0xffed875a) : const Color(0xfffff7b3),
        2.5,
      );
      oval(c, shot.to, 7, 7, const Color(0xffffe2a0));
    }
    for (final trace in game.defense.traces) {
      line(
        c,
        trace.from + const Offset(0, -20),
        trace.to + const Offset(0, -20),
        trace.friendly ? const Color(0xffffebaa) : const Color(0xffee8062),
        2,
      );
    }
    if (game.repairPulse > 0) {
      p
        ..color = Color.fromRGBO(118, 234, 190, game.repairPulse * .7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4;
      c.drawOval(
        Rect.fromCenter(
          center: game.robot,
          width: 240 + (1 - game.repairPulse) * 100,
          height: 140 + (1 - game.repairPulse) * 60,
        ),
        p,
      );
      p.style = PaintingStyle.fill;
    }
    c.restore();
  }

  void cactus(Canvas c, Offset at, double s) {
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(s);
    oval(c, const Offset(5, 3), 42, 17, const Color(0x227d6848));
    line(c, Offset.zero, const Offset(0, -53), const Color(0xff5a8c6b), 15);
    line(
      c,
      const Offset(-2, -23),
      const Offset(-22, -23),
      const Color(0xff5a8c6b),
      11,
    );
    line(
      c,
      const Offset(-22, -23),
      const Offset(-22, -39),
      const Color(0xff5a8c6b),
      11,
    );
    line(
      c,
      const Offset(2, -35),
      const Offset(19, -35),
      const Color(0xff5a8c6b),
      10,
    );
    line(
      c,
      const Offset(19, -35),
      const Offset(19, -49),
      const Color(0xff5a8c6b),
      10,
    );
    line(
      c,
      const Offset(-3, -5),
      const Offset(-3, -50),
      const Color(0xff8fb27a),
      3,
    );
    oval(c, const Offset(1, -59), 8, 6, const Color(0xffeab285));
    c.restore();
  }

  void rock(Canvas c, Offset at, double s) {
    oval(c, at + Offset(4, s * .12), s * 1.5, s * .55, const Color(0x227a5639));
    final path = Path()
      ..moveTo(at.dx - s * .65, at.dy)
      ..lineTo(at.dx - s * .5, at.dy - s * .5)
      ..quadraticBezierTo(at.dx, at.dy - s, at.dx + s * .45, at.dy - s * .5)
      ..lineTo(at.dx + s * .7, at.dy)
      ..quadraticBezierTo(at.dx, at.dy + s * .25, at.dx - s * .65, at.dy);
    p.color = const Color(0xffb68159);
    c.drawPath(path, p);
    line(
      c,
      at + Offset(-s * .35, -s * .45),
      at + Offset(s * .2, -s * .57),
      const Color(0xffd6a474),
      s * .13,
    );
  }

  static const _seams = <List<Offset>>[
    [
      Offset(-178, 21),
      Offset(-145, 10),
      Offset(-122, 17),
      Offset(-99, -3),
      Offset(-70, 2),
      Offset(-40, -18),
      Offset(-15, -6),
      Offset(9, -15),
      Offset(36, 3),
      Offset(68, -5),
      Offset(92, 10),
      Offset(123, 0),
      Offset(151, 13),
      Offset(179, 6),
    ],
    [
      Offset(-99, -3),
      Offset(-110, -22),
      Offset(-98, -39),
      Offset(-118, -54),
      Offset(-104, -70),
    ],
    [
      Offset(-40, -18),
      Offset(-27, -39),
      Offset(-5, -46),
      Offset(-12, -66),
      Offset(9, -78),
    ],
    [
      Offset(36, 3),
      Offset(49, -22),
      Offset(73, -31),
      Offset(66, -53),
      Offset(91, -64),
    ],
    [
      Offset(-70, 2),
      Offset(-62, 26),
      Offset(-38, 35),
      Offset(-46, 53),
      Offset(-24, 69),
    ],
    [
      Offset(9, -15),
      Offset(0, 15),
      Offset(19, 30),
      Offset(13, 52),
      Offset(37, 77),
    ],
    [Offset(92, 10), Offset(103, 29), Offset(126, 32), Offset(138, 53)],
  ];

  Path seamPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }
    return path;
  }

  Path seamRibbon(List<Offset> points, double width) {
    final left = <Offset>[], right = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      final previous = points[i == 0 ? 0 : i - 1];
      final next = points[i == points.length - 1 ? i : i + 1];
      final d = next - previous;
      final normal = Offset(-d.dy, d.dx) / d.distance;
      final w = (i == 0 || i == points.length - 1)
          ? .08
          : width * (.68 + .28 * math.sin(i * 2.7));
      left.add(points[i] + normal * w);
      right.add(points[i] - normal * w * (.7 + .2 * math.cos(i * 4)));
    }
    return Path()..addPolygon([...left, ...right.reversed], true);
  }

  void goldSite(Canvas c, GoldSite site) {
    c.save();
    c.translate(site.position.dx, site.position.dy);
    final richness = (site.remaining / 600).clamp(0.0, 1.0);
    final live = site.remaining > 0;
    final pulse = .86 + math.sin(game.elapsed * 1.5 + site.position.dx) * .14;
    // All geometry lies flush with the ground: no rock pile, cliff or plinth.
    final ground = Path()
      ..moveTo(-191, 16)
      ..lineTo(-157, -19)
      ..lineTo(-123, -25)
      ..lineTo(-135, -61)
      ..lineTo(-99, -83)
      ..lineTo(-63, -64)
      ..lineTo(-26, -91)
      ..lineTo(21, -91)
      ..lineTo(45, -67)
      ..lineTo(91, -81)
      ..lineTo(111, -41)
      ..lineTo(154, -21)
      ..lineTo(190, 3)
      ..lineTo(174, 32)
      ..lineTo(155, 65)
      ..lineTo(106, 58)
      ..lineTo(57, 89)
      ..lineTo(11, 91)
      ..lineTo(-32, 78)
      ..lineTo(-66, 63)
      ..lineTo(-106, 45)
      ..lineTo(-154, 50)
      ..close();
    p.color = Colors.white;
    p.shader = RadialGradient(
      colors: [
        live ? const Color(0xffbc9c6b) : const Color(0xffb09a77),
        const Color(0x00c9ae7e),
      ],
    ).createShader(const Rect.fromLTWH(-220, -115, 440, 230));
    c.drawPath(ground, p);
    p.shader = null;
    // Fine polygonal hairline fractures join the main branching seam.
    final rng = math.Random(site.position.dx.toInt());
    for (var i = 0; i < _seams.length; i++) {
      final points = _seams[i];
      for (var j = 1; j < points.length - 1; j++) {
        final at = points[j];
        final tip =
            at +
            Offset(
              (rng.nextDouble() - .5) * 30,
              (j.isEven ? 1 : -1) * (10 + rng.nextDouble() * 13),
            );
        line(
          c,
          at + const Offset(0, 1),
          tip + const Offset(0, 1),
          const Color(0xfff1d39a),
          1.7,
        );
        line(c, at, tip, const Color(0xffa18358), 1);
      }
      final path = seamPath(points);
      final cut = seamRibbon(points, i == 0 ? 6 : 3.8);
      p
        ..style = PaintingStyle.fill
        ..color = const Color(0xffe7c68b);
      c.save();
      c.translate(0, 1.2);
      c.drawPath(cut, p);
      c.restore();
      p.color = const Color(0xff78603f);
      c.drawPath(cut, p);
      p.color = const Color(0xff4e432e);
      c.drawPath(seamRibbon(points, i == 0 ? 4 : 2.5), p);
      if (live) {
        final power = (.35 + richness * .65) * pulse;
        p
          ..style = PaintingStyle.stroke
          ..color = Color.fromRGBO(255, 185, 57, .48 * power)
          ..strokeWidth = i == 0 ? 22 : 12
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9);
        c.drawPath(path, p);
        p
          ..maskFilter = null
          ..strokeWidth = i == 0 ? 3 : 1.4;
        p.color = Colors.white;
        p.shader = LinearGradient(
          colors: [
            const Color(0xffd58c26),
            Color.fromRGBO(255, 235, 151, power),
            const Color(0xfffff5cf),
            Color.fromRGBO(255, 209, 91, power),
            const Color(0xffc99032),
          ],
          stops: const [0, .25, .5, .8, 1],
        ).createShader(const Rect.fromLTWH(-180, -80, 360, 160));
        p.style = PaintingStyle.fill;
        c.drawPath(seamRibbon(points, i == 0 ? 2.1 : 1.2), p);
        p.shader = null;
        p
          ..style = PaintingStyle.stroke
          ..color = Color.fromRGBO(255, 250, 213, .85 * power)
          ..strokeWidth = i == 0 ? .9 : .5;
        c.drawPath(path, p);
      }
      p
        ..style = PaintingStyle.fill
        ..maskFilter = null;
    }
    // Sun-shaft light is emitted upward from cracks, with a bright narrow root
    // and translucent spreading tips. Its base never floats above the seam.
    if (live) {
      for (var i = 0; i < 11; i++) {
        final origin = _seams.first[1 + i];
        final phase = game.elapsed * .65 + i * 2.13;
        final strength = (.45 + .55 * richness) * (.68 + math.sin(phase) * .22);
        final height =
            (i % 3 == 0 ? 108.0 : 68.0) + (math.sin(phase * .6) + 1) * 13;
        final lean = (i % 2 == 0 ? -1 : 1) * (8.0 + i % 4 * 3);
        final ray = Path()
          ..moveTo(origin.dx - 2, origin.dy)
          ..lineTo(origin.dx + lean - 13, origin.dy - height)
          ..quadraticBezierTo(
            origin.dx + lean,
            origin.dy - height - 10,
            origin.dx + lean + 13,
            origin.dy - height,
          )
          ..lineTo(origin.dx + 2, origin.dy)
          ..close();
        p.color = Colors.white;
        p.shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color.fromRGBO(255, 237, 167, .55 * strength),
                Color.fromRGBO(255, 222, 137, .23 * strength),
                const Color(0x00fff0be),
              ],
              stops: const [0, .28, 1],
            ).createShader(
              Rect.fromLTWH(
                origin.dx - 28,
                origin.dy - height - 10,
                56,
                height + 10,
              ),
            );
        c.drawPath(ray, p);
        p.shader = null;
        // The luminous core is thinner than the surrounding golden shaft.
        final core = Path()
          ..moveTo(origin.dx - 1, origin.dy)
          ..lineTo(origin.dx + lean - 2, origin.dy - height * .86)
          ..lineTo(origin.dx + lean + 2, origin.dy - height * .86)
          ..lineTo(origin.dx + 1, origin.dy)
          ..close();
        p.color = Colors.white;
        p.shader =
            LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                Color.fromRGBO(255, 255, 220, .7 * strength),
                const Color(0x00fff8cf),
              ],
            ).createShader(
              Rect.fromLTWH(origin.dx - 20, origin.dy - height, 40, height),
            );
        c.drawPath(core, p);
        p.shader = null;
        oval(c, origin, 6, 3, const Color(0xfffff1b3));
        final rise = (game.elapsed * .23 + i * .137) % 1;
        final spark =
            origin + Offset(math.sin(i * 7.0 + rise) * 9, -12 - rise * height);
        p
          ..color = Color.fromRGBO(255, 242, 187, (1 - rise) * .7 * strength)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
        c.drawCircle(spark, 3, p);
        p.maskFilter = null;
        oval(
          c,
          spark,
          1.8,
          2.6,
          Color.fromRGBO(255, 255, 228, (1 - rise) * strength),
        );
      }
    }
    // A compact side caption stays clear of the machine and its front escort.
    box(c, const Rect.fromLTWH(200, -17, 128, 39), const Color(0xccf7e6be), 7);
    text(c, site.name, const Offset(264, -11), size: 11);
    text(
      c,
      live ? '${site.remaining.ceil()} G' : '채굴 완료',
      const Offset(264, 4),
      size: 10,
      color: const Color(0xff9a7137),
    );
    c.restore();
  }

  void cowboy(Canvas c, Offset at, bool hostile, double hp) {
    testMiner(c, at);
    if (hp < 100) {
      final top = at + const Offset(0, -65);
      box(c, Rect.fromCenter(center: top, width: 42, height: 4), ink, 2);
      box(c, Rect.fromLTWH(top.dx - 20, top.dy - 1, 40 * (hp / 100).clamp(0, 1), 2),
          hostile ? const Color(0xffd66e4a) : const Color(0xffd4bf83), 1);
    }
  }

  void defenseBot(Canvas c, DefenseVein site) {
    final bot = site.bot!;
    final at = bot.position;
    testMiner(c, at, width: 74, height: 90);
    final top = at + const Offset(0, -95);
    box(c, Rect.fromCenter(center: top, width: 64, height: 4), ink, 2);
    box(c, Rect.fromLTWH(top.dx - 31, top.dy - 1,
        62 * (bot.hp / bot.maxHp).clamp(0, 1), 2),
        const Color(0xffe4c271), 1);
    text(c, '${DefenseWorld.laneNames[site.lane]} Lv.${bot.level}',
        top + const Offset(0, -15), size: 10);
  }

  void rescueCamp(Canvas c, RescueCamp camp) {
    final at = camp.position;
    oval(c, at, 145, 88, const Color(0x33876747));
    if (camp.rescued) {
      text(
        c,
        '구출 완료',
        at + const Offset(0, 45),
        size: 12,
        color: const Color(0xff7b7752),
      );
      return;
    }
    for (final x in [-45.0, 45.0]) {
      line(c, at + Offset(x, 14), at + Offset(x, -45), ink, 5);
    }
    for (var i = 0; i < 6; i++) {
      line(
        c,
        at + Offset(-43 + i * 17.0, 13),
        at + Offset(-43 + i * 17.0, -41),
        const Color(0xff939081),
        3,
      );
    }
    line(
      c,
      at + const Offset(-45, -42),
      at + const Offset(45, -42),
      const Color(0xffa69a7d),
      5,
    );
    cowboy(c, at + const Offset(0, 8), false, 100);
    final guards = game.defense.guardsLeft(camp);
    text(
      c,
      guards > 0 ? '구조 신호 · 경비 $guards명' : '다가가서 구출',
      at + const Offset(0, 47),
      size: 12,
      color: guards > 0 ? const Color(0xffa35b3b) : const Color(0xff967025),
    );
  }

  void fieldEnemy(Canvas c, FieldEnemy enemy) {
    final scale = enemy.boss ? 1.55 : 1.0;
    c.save();
    c.translate(enemy.position.dx, enemy.position.dy);
    c.scale(scale);
    cowboy(c, Offset.zero, true, enemy.hp / enemy.maxHp * 100);
    if (enemy.attack != EnemyAttack.gun) {
      shadedOval(c, const Offset(-14, -18), 12, 13, const Color(0xff524739));
      oval(c, const Offset(-14, -23), 4, 4, const Color(0xffe4ac54));
    }
    c.restore();
    box(
      c,
      Rect.fromLTWH(
        enemy.position.dx - 22,
        enemy.position.dy - (enemy.boss ? 84 : 58),
        44,
        4,
      ),
      ink,
      2,
    );
    box(
      c,
      Rect.fromLTWH(
        enemy.position.dx - 21,
        enemy.position.dy - (enemy.boss ? 83 : 57),
        42 * (enemy.hp / enemy.maxHp).clamp(0, 1),
        2,
      ),
      const Color(0xffd66e4a),
      1,
    );
    if (enemy.boss) {
      text(
        c,
        '구출 경비대장',
        enemy.position + const Offset(0, -104),
        size: 12,
        color: const Color(0xffa64d32),
      );
    }
  }

  void companion(Canvas c, RescuedCompanion unit) {
    final at = game.defense.companionPosition(unit);
    oval(c, at, 40, 17, const Color(0x44e8b650));
    c.save();
    c.translate(at.dx, at.dy);
    c.scale(1.22);
    cowboy(c, Offset.zero, false, 100);
    c.restore();
    text(
      c,
      unit.name,
      at + const Offset(0, -72),
      size: 10,
      color: const Color(0xff8e5e28),
    );
  }

  void playerHero(Canvas c) {
    final hero = game.defense.hero;
    final at = hero.position;
    p
      ..style = PaintingStyle.stroke
      ..color = const Color(0xfff8df89)
      ..strokeWidth = 2;
    c.drawOval(Rect.fromCenter(center: at, width: 44, height: 22), p);
    p.style = PaintingStyle.fill;
    c.save();
    c.translate(at.dx, at.dy);
    if (hero.rolling > 0) {
      for (var i = 1; i < 4; i++) {
        oval(
          c,
          hero.rollDirection * (-i * 12.0),
          27,
          12,
          Color.fromRGBO(226, 187, 112, .18 / i),
        );
      }
      c.translate(0, -20);
      c.rotate(
        (1 - hero.rolling / .28) *
            math.pi *
            2 *
            (hero.rollDirection.dx < 0 ? -1 : 1),
      );
      c.translate(0, 20);
    }
    c.scale(1.15);
    cowboy(c, Offset.zero, false, hero.hp / hero.maxHp * 100);
    c.restore();
    text(
      c,
      '보안관 Lv.${hero.level}',
      at + const Offset(0, -77),
      size: 11,
      color: const Color(0xff805527),
    );
    if (hero.goal != null) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = const Color(0xaaffeeaa);
      c.drawOval(Rect.fromCenter(center: hero.goal!, width: 24, height: 12), p);
      p.style = PaintingStyle.fill;
    }
  }

  void hazards(Canvas c) {
    for (final h in game.defense.hazards) {
      final progress = (1 - h.remaining / h.duration).clamp(0.0, 1.0);
      if (h.kind == HazardKind.gun) {
        if (!h.impacted) {
          line(
            c,
            h.from + const Offset(0, -20),
            game.defense.hero.position,
            const Color(0x77c9563b),
            1.2,
          );
        }
      } else if (h.kind == HazardKind.blast) {
        oval(c, h.target, h.radius * 2, h.radius * 2, const Color(0x22c65332));
        p
          ..style = PaintingStyle.stroke
          ..strokeWidth = h.impacted ? 5 : 2
          ..color = h.impacted
              ? const Color(0xffffb856)
              : const Color(0xffbc5237);
        c.drawCircle(h.target, h.radius, p);
        if (!h.impacted) {
          c.drawArc(
            Rect.fromCircle(center: h.target, radius: h.radius),
            -math.pi / 2,
            progress * math.pi * 2,
            false,
            p..strokeWidth = 5,
          );
        }
        p.style = PaintingStyle.fill;
        text(
          c,
          h.impacted ? '' : '${h.remaining.toStringAsFixed(1)}초',
          h.target + const Offset(0, -8),
          size: 12,
          color: const Color(0xffb44c30),
        );
      } else if (h.kind == HazardKind.rolling) {
        oval(
          c,
          h.position + const Offset(3, 3),
          22,
          12,
          const Color(0x55774c2b),
        );
        shadedOval(
          c,
          h.position + const Offset(0, -8),
          23,
          23,
          const Color(0xff645144),
        );
        line(
          c,
          h.position + const Offset(0, -20),
          h.position + const Offset(5, -27),
          const Color(0xffb68441),
          2,
        );
        oval(
          c,
          h.position + const Offset(5, -28),
          5,
          5,
          const Color(0xffffd17a),
        );
        if (h.impacted) oval(c, h.position, 80, 60, const Color(0x55f3a74e));
      } else {
        line(
          c,
          h.from,
          h.target,
          h.impacted ? const Color(0xffe1b260) : const Color(0x55c35639),
          h.radius * 2,
        );
        if (!h.impacted) line(c, h.from, h.target, const Color(0xffb75a3c), 2);
      }
    }
  }

  void machine(Canvas c) {
    final at = game.robot + FrontierGame.drillContact;
    // Large miner placeholder instead of per-frame 3D geometry rendering.
    testMiner(c, at, width: 150, height: 190);
    final bar = at + const Offset(0, -204);
    box(c, Rect.fromCenter(center: bar, width: 100, height: 6),
        const Color(0xff5b4939), 3);
    box(c, Rect.fromLTWH(bar.dx - 48, bar.dy - 1,
        96 * (game.hull / 1200).clamp(0, 1), 2),
        const Color(0xffd4bf83), 1);
    text(c, '철마 01 (테스트 스프라이트)',
        bar + const Offset(0, -20), size: 12);
  }

  @override
  bool shouldRepaint(covariant FrontierPainter oldDelegate) => true;
}

class FrontierMiniMap extends CustomPainter {
  FrontierMiniMap(this.game, this.camera, this.viewport);
  final FrontierGame game;
  final Offset camera;
  final Size viewport;
  @override
  void paint(Canvas c, Size size) {
    c.drawColor(const Color(0xffd0b37e), BlendMode.src);
    c.save();
    c.scale(size.width / 3600, size.height / 2400);
    final p = Paint();
    for (final route in DefenseWorld.paths) {
      p
        ..style = PaintingStyle.stroke
        ..strokeWidth = 45
        ..color = const Color(0xffefcf92);
      c.drawPath(Path()..addPolygon(route, false), p);
      p.style = PaintingStyle.fill;
    }
    for (final site in game.defense.veins) {
      c.drawCircle(
        site.position,
        site.bot == null ? 40 : 57,
        p
          ..color = site.bot == null
              ? const Color(0xffeed28a)
              : const Color(0xff806343),
      );
    }
    for (final enemy in game.defense.enemies) {
      if (enemy.campId != null &&
          !game.defense.camps
              .firstWhere((camp) => camp.id == enemy.campId)
              .discovered) {
        continue;
      }
      c.drawCircle(enemy.position, 25, p..color = const Color(0xffb9503d));
    }
    for (final camp in game.defense.camps.where(
      (c) => c.discovered && !c.rescued,
    )) {
      c.drawCircle(camp.position, 58, p..color = const Color(0xffa787b3));
    }
    c.drawCircle(DefenseWorld.home, 80, p..color = const Color(0xff8d9b6c));
    c.drawCircle(
      DefenseWorld.enemyHome,
      75,
      p..color = const Color(0xffa8503b),
    );
    c.drawCircle(
      game.defense.hero.position,
      65,
      p..color = const Color(0xfffff6cf),
    );
    c.drawCircle(game.robot, 40, p..color = const Color(0xffad8550));
    p
      ..color = const Color(0xfffff3c4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 20;
    c.drawRect(camera & viewport, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant FrontierMiniMap oldDelegate) => true;
}
