import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Deterministic, rotationally balanced layouts for 3 chapters of 10 missions.
/// This is map-planning data; the RTS renderer and AI will consume it later.
class MissionMapPlan {
  const MissionMapPlan({
    required this.mission,
    required this.seed,
    required this.starts,
    required this.naturals,
    required this.contested,
    required this.central,
    required this.chokeWidth,
  });

  final int mission;
  final int seed;
  final List<Offset> starts;
  final List<Offset> naturals;
  final List<Offset> contested;
  final List<Offset> central;
  final double chokeWidth;

  int get chapter => (mission - 1) ~/ 10 + 1;

  /// Quarter-turn symmetry keeps the four starting positions equivalent.
  static MissionMapPlan generate(int mission, {int replay = 0}) {
    if (mission < 1 || mission > 30) {
      throw RangeError.range(mission, 1, 30, 'mission');
    }
    final seed = mission * 7919 + replay * 104729;
    final random = math.Random(seed);
    const center = Offset(900, 600);
    // The world is 1800x1200, so use an ellipse-preserving quarter turn:
    // normalize coordinates before rotating to avoid edge imbalance.
    Offset symmetric(Offset normalized, int turn) {
      final x = normalized.dx;
      final y = normalized.dy;
      switch (turn % 4) {
        case 0: return Offset(center.dx + x * 900, center.dy + y * 600);
        case 1: return Offset(center.dx - y * 900, center.dy + x * 600);
        case 2: return Offset(center.dx - x * 900, center.dy - y * 600);
        default: return Offset(center.dx + y * 900, center.dy - x * 600);
      }
    }

    List<Offset> four(Offset normalized) =>
        List<Offset>.generate(4, (i) => symmetric(normalized, i));

    // Every player receives the same home-to-natural distance and ore budget.
    final starts = four(const Offset(-0.66, -0.64));
    final naturals = four(const Offset(-0.40, -0.39));

    // Shared expansions vary by mission/replay, always as symmetric sets.
    final angle = -0.24 + random.nextDouble() * 0.48;
    final distance = 0.64 + random.nextDouble() * 0.08;
    final contested = four(Offset(-distance, angle));
    final central = <Offset>[
      Offset(center.dx + (random.nextDouble() - 0.5) * 70,
          center.dy + (random.nextDouble() - 0.5) * 45),
    ];

    final chapter = (mission - 1) ~/ 10 + 1;
    final chokeWidth = (chapter == 1 ? 140.0 : chapter == 2 ? 105.0 : 75.0)
        + random.nextInt(3) * 10;
    return MissionMapPlan(
      mission: mission,
      seed: seed,
      starts: starts,
      naturals: naturals,
      contested: contested,
      central: central,
      chokeWidth: chokeWidth,
    );
  }
}
