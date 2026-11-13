import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/competitor_map_benchmark.dart';
import 'package:mine_path/mining/content.dart';

void main() {
  test('four competitors have separate deterministic mine samples', () {
    final first = sampleCompetitorMaps(stage: stages.first, rounds: 20);
    final replay = sampleCompetitorMaps(stage: stages.first, rounds: 20);
    expect(first, hasLength(20));
    for (var round = 0; round < first.length; round++) {
      expect(first[round].competitors, hasLength(4));
      expect(
        first[round].competitors.map((c) => c.competitor).toList(),
        [0, 1, 2, 3],
      );
      for (var i = 0; i < 4; i++) {
        final sample = first[round].competitors[i];
        expect(sample.depositCount, stages.first.deposits);
        expect(sample.oreReserve, greaterThan(0));
        expect(sample.oreReserve, replay[round].competitors[i].oreReserve);
      }
      expect(first[round].reserveSpread, greaterThanOrEqualTo(0));
    }
    expect(first.any((round) => round.reserveSpread > 0), isTrue);
  });

  test('empty sample and invalid round count are handled', () {
    expect(sampleCompetitorMaps(stage: stages.first, rounds: 0), isEmpty);
    expect(
      () => sampleCompetitorMaps(stage: stages.first, rounds: -1),
      throwsArgumentError,
    );
  });
}
