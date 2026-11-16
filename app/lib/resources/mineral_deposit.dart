import 'dart:math';

class MineralDeposit {
  MineralDeposit(this.position, {int amount = 1500}) : remaining = amount {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
  }
  final Point<double> position;
  int remaining;
  bool get depleted => remaining == 0;
  int take(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    final result = min(amount, remaining);
    remaining -= result;
    return result;
  }
}
