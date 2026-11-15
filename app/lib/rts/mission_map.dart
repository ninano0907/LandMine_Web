import 'dart:ui';

/// Deterministic, rotationally symmetric resource layout for RTS missions.
/// Four starts share equal local resources; contested sites sit between them.
class MissionMap {
  const MissionMap._();
  static const world = Size(1800, 1200);
  static const starts = <Offset>[
    Offset(360, 260), Offset(1440, 260),
    Offset(360, 940), Offset(1440, 940),
  ];
  static List<Offset> minerals(int mission, {int variant = 0}) {
    final seed = (mission.clamp(1, 30) * 37 + variant * 101);
    final shift = (seed % 5 - 2) * 12.0;
    final sites = <Offset>[];
    for (final start in starts) {
      final sx = start.dx < 900 ? 1.0 : -1.0;
      final sy = start.dy < 600 ? 1.0 : -1.0;
      for (var i = 0; i < 8; i++) {
        sites.add(Offset(start.dx + sx * (95 + (i % 4) * 27),
            start.dy + sy * (60 + (i ~/ 4) * 38)));
      }
      for (var i = 0; i < 5; i++) {
        sites.add(Offset(start.dx + sx * (245 + (i % 3) * 25),
            start.dy + sy * (120 + (i ~/ 3) * 45)));
      }
    }
    // Contested expansions are mirrored around both world axes.
    for (final x in [760.0 + shift, 1040.0 - shift]) {
      for (final y in [410.0, 790.0]) {
        for (var i = 0; i < 5; i++) {
          sites.add(Offset(x + (i % 3 - 1) * 22, y + (i ~/ 3) * 30));
        }
      }
    }
    return sites;
  }
}
