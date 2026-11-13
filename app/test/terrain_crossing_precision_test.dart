import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/geometry.dart';
import 'package:mine_path/mining/terrain.dart';

void main() {
  test('short conveyor crossing a river is always detected', () {
    for (var seed = 0; seed < 100; seed++) {
      final terrain = TerrainMap.generate(seed);
      final y = terrain.riverCenterY(.5);
      final from = Point2(.5, y - .04);
      final to = Point2(.5, y + .04);
      expect(terrain.isRiver(from), isFalse, reason: 'seed $seed');
      expect(terrain.isRiver(to), isFalse, reason: 'seed $seed');
      expect(terrain.crossings(from, to).river, isTrue, reason: 'seed $seed');
      expect(terrain.crossesObstacle(from, to), isTrue, reason: 'seed $seed');
    }
  });

  test('a zero-length sample still detects terrain at its point', () {
    final terrain = TerrainMap.generate(17);
    final p = Point2(.5, terrain.riverCenterY(.5));
    expect(terrain.crossings(p, p).river, isTrue);
    expect(terrain.crossesObstacle(p, p), isTrue);
  });
}
