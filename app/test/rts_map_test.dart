import 'package:flutter_test/flutter_test.dart';
import 'package:mine_path/rts/mission_map.dart';
import 'package:mine_path/rts/screen.dart';

void main() {
  test('four starts and mineral sites are inside traversable terrain', () {
    expect(MissionMap.starts.length, 4);
    for (final start in MissionMap.starts) {
      expect(Terrain.blocked(start), isFalse);
    }
    final minerals = MissionMap.minerals(1);
    expect(minerals, isNotEmpty);
    for (final point in minerals) {
      expect(point.dx, inInclusiveRange(12, 1788));
      expect(point.dy, inInclusiveRange(12, 1188));
      expect(Terrain.blocked(point), isFalse,
          reason: 'Mineral must not spawn inside an impassable cliff: $point');
    }
  });

  test('all four starts have equal local mineral counts', () {
    final minerals = MissionMap.minerals(1);
    final counts = MissionMap.starts.map((start) =>
      minerals.where((p) => (p-start).distance < 350).length).toList();
    expect(counts.toSet().length, 1, reason: 'Each faction needs equal starting resources');
  });

  test('pathfinder connects all starting positions', () {
    for (final from in MissionMap.starts) {
      for (final to in MissionMap.starts) {
        if (from == to) continue;
        expect(Terrain.route(from, to), isNotEmpty,
            reason: 'Unreachable faction start: $from -> $to');
      }
    }
  });
}
