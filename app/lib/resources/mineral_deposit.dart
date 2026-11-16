import 'dart:math';

class MineralDeposit {
  MineralDeposit(this.position, {int amount = 1500}) : remaining = amount {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
  }
  // A connected 2x2 tile of rock; position is its bottom-center anchor.
  static const width = 80.0;
  static const height = 80.0;
  static const bottomOffset = 2.0;
  final Point<double> position;
  int remaining;
  final _miningPositions = <Object, Point<double>>{};

  Point<double>? miningPosition(Object worker) => _miningPositions[worker];

  bool reserveMiningPosition(Object worker, Point<double> point) {
    if (_miningPositions.entries.any(
      (entry) =>
          !identical(entry.key, worker) && entry.value.distanceTo(point) < 18,
    )) {
      return false;
    }
    _miningPositions[worker] = point;
    return true;
  }

  void releaseMiningPosition(Object worker) => _miningPositions.remove(worker);

  bool get depleted => remaining == 0;
  int take(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    final result = min(amount, remaining);
    remaining -= result;
    return result;
  }
}
