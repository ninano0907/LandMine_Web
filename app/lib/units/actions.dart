import 'animation.dart';
import 'stats.dart';

enum UnitAction {
  move('이동'),
  stop('정지 / 대기'),
  attack('공격'),
  gather('금 채굴'),
  repair('수리'),
  build('건설');

  const UnitAction(this.label);
  final String label;
}

class UnitActionSpec {
  const UnitActionSpec(
    this.motion, {
    this.cycleSeconds = UnitDefaults.workCycle,
    this.loop = true,
    this.frames = 8,
  }) : assert(cycleSeconds > 0),
       assert(frames > 0);

  final UnitMotion motion;
  final double cycleSeconds;
  final bool loop;
  final int frames;
  double get framesPerSecond => frames / cycleSeconds;
}
