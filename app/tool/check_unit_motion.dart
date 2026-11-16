import 'dart:math';
import 'dart:io';
import 'package:mine_path/units/animation.dart';
import 'package:mine_path/units/direction.dart';
import 'package:mine_path/units/mineral_targets.dart';
import 'package:mine_path/units/movement.dart';

void check(bool condition, String description) {
  if (!condition) throw StateError(description);
}

void main() {
  for (var direction = 0; direction < 8; direction++) {
    final angle = direction * pi / 4;
    check(
      directionRow(angle) == direction,
      'Positive facing maps to correct row',
    );
    check(
      directionRow(angle - 2 * pi) == direction,
      'Negative facing maps to correct row',
    );
  }
  check(directionRow(2 * pi) == 0, 'Full turn wraps to east');
  const origin = Point(400.0, 250.0);
  check(mineralTargets.length == 8, 'Eight mineral click targets');
  final facings = <int>{};
  for (final target in mineralTargets) {
    facings.add(directionRow(atan2(target.y - origin.y, target.x - origin.x)));
    final approach = miningApproach(origin, target);
    check(
      (approach.distanceTo(target) - 58).abs() < 0.000001,
      'Stop outside each crystal',
    );
    check(
      approach.distanceTo(origin) < target.distanceTo(origin),
      'Approach stays on the near side',
    );
  }
  for (var i = 0; i < mineralTargets.length; i++) {
    final mineral = mineralTargets[i];
    final approach = miningApproach(origin, mineral);
    final miningFacing = atan2(mineral.y - approach.y, mineral.x - approach.x);
    check(
      directionRow(miningFacing) == i,
      'Mining must face target $i after arrival',
    );
  }
  check(facings.length == 8, 'Minerals cover all eight facings');
  check(miningApproach(origin, origin) == origin, 'Overlapping target is safe');
  check(
    miningApproach(const Point(420.0, 250.0), origin) ==
        const Point(420.0, 250.0),
    'Already close enough stays still',
  );
  final animation = UnitAnimation();
  animation.update(10);
  check(animation.frame == 0 && animation.row == 0, 'Idle must remain still');
  for (final motion in [UnitMotion.walk, UnitMotion.mine, UnitMotion.repair]) {
    animation.play(motion);
    check(animation.frame == 0, 'New action starts at frame zero');
    final period = 8 / animation.framesPerSecond;
    for (var i = 1; i <= 80; i++) {
      animation.update(period / 80);
      check(
        animation.frame >= 0 && animation.frame < 8,
        'Frame stays in sheet',
      );
    }
    check(
      animation.frame == 0 || animation.frame == 7,
      'Cycle wraps at boundary',
    );
    animation.play(UnitMotion.idle);
  }
  animation.play(UnitMotion.mine);
  check(animation.row == 1, 'Mining uses the pickaxe row');
  animation.update(0.25);
  check(animation.frame == 2, 'Mining runs at eight frames per second');
  animation.play(UnitMotion.repair);
  check(
    animation.row == 2 && animation.frame == 0,
    'Repair resets to wrench row',
  );
  animation.update(double.nan);
  animation.update(-1);
  check(animation.frame == 0, 'Invalid time is ignored');

  final unit = UnitMovement(
    position: const Point(0.0, 0.0),
    speed: 140,
    radius: 16,
  );
  unit.moveTo(const Point(140.0, 0.0));
  unit.update(0.5);
  check(unit.position.x == 70, 'Movement uses the configured speed');
  unit.update(1);
  check(unit.position.x == 140 && !unit.moving, 'Arrival cannot overshoot');
  unit.moveTo(const Point(200.0, 0.0));
  unit.stop();
  unit.update(1);
  check(unit.position.x == 140 && !unit.moving, 'Work can stop travel');
  stdout.writeln(
    'PASS: animation rows, frame timing, loops, transitions, movement and stop.',
  );
}
