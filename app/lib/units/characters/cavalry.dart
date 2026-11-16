import '../game_unit.dart';
import '../stats.dart';

/// Initial movement tuning only; dedicated artwork is not available yet.
class CavalryUnit extends GameUnit {
  CavalryUnit({required super.position, required super.upgrades, super.grid})
    : super(stats: const UnitStats(speed: 180));

  @override
  String get label => '기마병';
  @override
  int get colorValue => 0xffce93d8;
}
