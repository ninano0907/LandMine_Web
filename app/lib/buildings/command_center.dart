import 'dart:math';
import 'building.dart';

class CommandCenter extends Building {
  CommandCenter({
    required super.grid,
    required super.column,
    required super.row,
    super.id = 'command-center',
  }) : super(spec: definition);
  static const definition = BuildingSpec(label: '커맨드 센터', width: 4, height: 3);
  int _storedMinerals = 0;
  int get storedMinerals => _storedMinerals;
  void deposit(int amount) {
    if (amount < 0) throw ArgumentError.value(amount, 'amount');
    _storedMinerals += amount;
  }

  /// Unloading happens around the perimeter; the decorative door is not a portal.
  List<Point<double>> dropOffPoints(double radius) {
    final gap = radius + 8;
    return [
      for (var x = 0; x < area.width; x++) ...[
        Point(left + (x + .5) * grid.tileSize, top - gap),
        Point(left + (x + .5) * grid.tileSize, top + height + gap),
      ],
      for (var y = 0; y < area.height; y++) ...[
        Point(left - gap, top + (y + .5) * grid.tileSize),
        Point(left + width + gap, top + (y + .5) * grid.tileSize),
      ],
    ];
  }
}
