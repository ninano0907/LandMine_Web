import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/mining/terrain.dart';
import 'package:mine_path/mining/geometry.dart';

void main() {
  test('generated mountains leave the curved river unobstructed', () {
    for (var seed = 0; seed < 100; seed++) {
      final terrain = TerrainMap.generate(seed);
      for (final mountain in terrain.mountains) {
        // Every point along the river must remain outside the mountain.
        for (var i = 0; i <= 100; i++) {
          final x = i / 100;
          final riverPoint = Point2(x, terrain.riverCenterY(x));
          expect(
            mountain.contains(riverPoint),
            isFalse,
            reason: 'seed $seed mountain at ${mountain.center} intersects river',
          );
        }
      }
    }
  });
}
