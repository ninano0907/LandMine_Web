/// Action clock; frame counts are configured per animation atlas.
enum UnitMotion { idle, walk, mine, repair, attack }

class UnitAnimation {
  UnitMotion motion = UnitMotion.idle;
  double elapsed = 0;
  double? _customFramesPerSecond;
  int _frameCount = 8;
  int get frameCount => _frameCount;

  int get row => switch (motion) {
    UnitMotion.idle || UnitMotion.walk || UnitMotion.attack => 0,
    UnitMotion.mine => 1,
    UnitMotion.repair => 2,
  };
  double get framesPerSecond =>
      _customFramesPerSecond ?? (motion == UnitMotion.walk ? 12 : 8);
  int get frame => motion == UnitMotion.idle
      ? 0
      : (elapsed * framesPerSecond).floor() % _frameCount;

  void play(UnitMotion value, {double? framesPerSecond, int frames = 8}) {
    assert(frames > 0);
    if (value == motion &&
        framesPerSecond == _customFramesPerSecond &&
        frames == _frameCount) {
      return;
    }
    _customFramesPerSecond = framesPerSecond;
    _frameCount = frames;
    motion = value;
    elapsed = 0;
  }

  void update(double seconds) {
    if (seconds.isFinite && seconds > 0 && motion != UnitMotion.idle) {
      elapsed = (elapsed + seconds) % (_frameCount / framesPerSecond);
    }
  }
}
