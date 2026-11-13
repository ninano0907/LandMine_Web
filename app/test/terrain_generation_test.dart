import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/content.dart';
import 'package:mine_path/mining/simulation.dart';
import 'package:mine_path/mining/terrain.dart';
import 'package:mine_path/mining/geometry.dart';

void main() {
  test('terrain is reproducible for the same map seed', () {
    final a = TerrainMap.generate(42);
    final b = TerrainMap.generate(42);
    expect(a.riverY, b.riverY);
    expect(a.riverBend, b.riverBend);
    expect(a.riverPhase, b.riverPhase);
    expect(a.mountains.length, b.mountains.length);
    for (var i = 0; i < a.mountains.length; i++) {
      expect(a.mountains[i].center.x, b.mountains[i].center.x);
      expect(a.mountains[i].center.y, b.mountains[i].center.y);
    }
  });

  test('factory and generated deposits stay off river and mountains', () {
    for (final seed in [1, 42, 101, 202, 303, 404, 505, 999]) {
      final game = MiningGame(stage: stages.last, seed: seed);
      expect(game.terrain.blocked(MapGeometry.factoryCenter), isFalse);
      for (final mine in game.deposits) {
        expect(game.terrain.blocked(mine.point), isFalse);
      }
    }
  });

  test('a segment that crosses the river is blocked', () {
    final terrain = TerrainMap.generate(42);
    final x = .04;
    final y = terrain.riverCenterY(x);
    expect(terrain.crossesObstacle(Point2(x, y - .09), Point2(x, y + .09)),
        isTrue);
  });
  test('bridge and tunnel research gates terrain crossing', () {
    final t = TerrainMap.generate(42);
    final x = .04;
    final y = t.riverCenterY(x);
    final game = MiningGame(stage: stages.first, seed: 42);
    expect(game.bridgeUnlocked, isFalse);
    expect(game.tunnelUnlocked, isFalse);
    final upgraded = MiningGame(
      stage: stages.first,
      seed: 42,
      bridgeUnlocked: true,
      tunnelUnlocked: true,
    );
    expect(upgraded.bridgeUnlocked, isTrue);
    expect(upgraded.tunnelUnlocked, isTrue);
    expect(
      t.crossings(Point2(x, y - .09), Point2(x, y + .09)).river,
      isTrue,
    );
  });

}
