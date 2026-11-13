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

  test('mountain crossing is detected even with clear endpoints', () {
    for (var seed = 0; seed < 100; seed++) {
      final terrain = TerrainMap.generate(seed);
      for (final mountain in terrain.mountains) {
        final from = Point2(mountain.center.x - mountain.radius - .01,
            mountain.center.y);
        final to = Point2(mountain.center.x + mountain.radius + .01,
            mountain.center.y);
        expect(terrain.isMountain(from), isFalse, reason: 'seed $seed');
        expect(terrain.isMountain(to), isFalse, reason: 'seed $seed');
        expect(terrain.crossings(from, to).mountain, isTrue,
            reason: 'seed $seed');
        expect(terrain.crossesObstacle(from, to), isTrue,
            reason: 'seed $seed');
      }
    }
  });

  test('crossings report the correct obstacle type at its center', () {
    for (var seed = 0; seed < 100; seed++) {
      final terrain = TerrainMap.generate(seed);
      final riverPoint = Point2(.5, terrain.riverCenterY(.5));
      expect(terrain.crossings(riverPoint, riverPoint).river, isTrue,
          reason: 'seed $seed');
      expect(terrain.crossings(riverPoint, riverPoint).mountain, isFalse,
          reason: 'seed $seed');
      for (final mountain in terrain.mountains) {
        final result = terrain.crossings(mountain.center, mountain.center);
        expect(result.mountain, isTrue, reason: 'seed $seed');
        expect(result.river, isFalse, reason: 'seed $seed');
      }
    }
  });
  test('factory center stays clear of generated terrain', () {
    for (var seed = 0; seed < 100; seed++) {
      final terrain = TerrainMap.generate(seed);
      const center = MapGeometry.factoryCenter;
      expect(terrain.blocked(center), isFalse, reason: 'seed $seed');
      final crossing = terrain.crossings(center, center);
      expect(crossing.river, isFalse, reason: 'seed $seed');
      expect(crossing.mountain, isFalse, reason: 'seed $seed');
    }
  });
}
