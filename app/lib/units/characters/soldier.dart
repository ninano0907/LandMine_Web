import '../combat/ranged_unit.dart';
import '../stats.dart';

class SoldierUnit extends RangedUnit {
  SoldierUnit({required super.position, required super.upgrades, super.grid})
    : super(stats: const UnitStats(attackRange: 145));

  @override
  String get label => '보병';
  @override
  int get colorValue => 0xff40c4ff;
}
