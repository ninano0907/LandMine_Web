import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';

void main() {
  test('generated mines leave a clear zone around the factory', () {
    for (final seed in [1, 42, 101, 202, 303, 404, 505, 999]) {
      final game = MiningGame(stage: stages.last, seed: seed);
      expect(game.deposits.length, stages.last.deposits);
      for (final mine in game.deposits) {
        expect(MiningGame.entrance.distance(mine.point), greaterThanOrEqualTo(.31));
        for (final other in game.deposits) {
          if (mine.id == other.id) continue;
          expect(mine.point.distance(other.point), greaterThanOrEqualTo(.16));
        }
      }
    }
  });

  test('explicit map seeds stay reproducible for testing', () {
    final a = MiningGame(stage: stages.first, seed: 123);
    final b = MiningGame(stage: stages.first, seed: 123);
    for (var i = 0; i < a.deposits.length; i++) {
      expect(a.deposits[i].point.x, b.deposits[i].point.x);
      expect(a.deposits[i].point.y, b.deposits[i].point.y);
    }
  });
}
