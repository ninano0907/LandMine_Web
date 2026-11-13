import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

/// Read-only competitor map benchmark. Never changes gameplay or player saves.
class CompetitorMapSample {
  final int competitor;
  final double oreReserve;
  final int depositCount;
  const CompetitorMapSample(this.competitor, this.oreReserve, this.depositCount);
}

class CompetitorRoundSample {
  final int round;
  final List<CompetitorMapSample> competitors;
  const CompetitorRoundSample(this.round, this.competitors);

  double get minimumReserve => competitors
      .map((c) => c.oreReserve)
      .reduce((a, b) => a < b ? a : b);
  double get maximumReserve => competitors
      .map((c) => c.oreReserve)
      .reduce((a, b) => a > b ? a : b);
  double get reserveSpread => maximumReserve - minimumReserve;
}

/// Samples player (index 0) and three bots (indices 1..3) with distinct seeds.
/// This measures map luck only, not bot skill or projected profits.
List<CompetitorRoundSample> sampleCompetitorMaps({
  required StageSpec stage,
  int rounds = 100,
  int startingSeed = 0,
}) {
  if (rounds < 0) throw ArgumentError.value(rounds, 'rounds');
  return List.generate(rounds, (round) {
    final competitors = List.generate(4, (index) {
      final seed = startingSeed + round * 4 + index;
      final game = MiningGame(stage: stage, seed: seed);
      final reserve = game.deposits.fold<double>(
        0, (total, mine) => total + mine.remaining,
      );
      return CompetitorMapSample(index, reserve, game.deposits.length);
    });
    return CompetitorRoundSample(round, competitors);
  });
}
