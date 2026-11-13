import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

/// Isolated four-competitor map sampling. This does not implement bot AI or
/// change gameplay balance; it measures whether independently seeded maps vary.
void main() {
  test('player and three bots receive reproducible independent maps', () {
    for (var round = 0; round < 100; round++) {
      final games = List.generate(
        4,
        (competitor) => MiningGame(
          stage: stages.first,
          seed: round * 4 + competitor,
        ),
      );
      expect(games.length, 4);
      for (var competitor = 0; competitor < 4; competitor++) {
        final replay = MiningGame(
          stage: stages.first,
          seed: round * 4 + competitor,
        );
        expect(
          games[competitor].deposits.map((d) => d.remaining).toList(),
          replay.deposits.map((d) => d.remaining).toList(),
          reason: 'round $round competitor $competitor',
        );
      }
    }
  });

  test('independent competitor maps can have different ore reserves', () {
    var variedRounds = 0;
    for (var round = 0; round < 100; round++) {
      final totals = List.generate(4, (competitor) {
        final game = MiningGame(
          stage: stages.first,
          seed: round * 4 + competitor,
        );
        return game.deposits.fold<double>(
          0,
          (sum, deposit) => sum + deposit.remaining,
        );
      });
      if (totals.toSet().length > 1) variedRounds++;
    }
    expect(variedRounds, greaterThan(0));
  });
}
