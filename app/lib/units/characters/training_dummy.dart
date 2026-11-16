import '../game_unit.dart';
import '../stats.dart';
import '../actions.dart';
import '../animation.dart';

/// Stationary target for the isolated shooting lab, never a selectable army unit.
class TrainingDummy extends GameUnit {
  TrainingDummy({required super.position, required super.upgrades})
    : super(stats: const UnitStats());
  @override
  String get label => '훈련 표적';
  @override
  int get colorValue => 0xffc59a69;
  @override
  bool get canUpgradeAttack => false;
  @override
  bool get canUpgradeDefense => false;
  @override
  Map<UnitAction, UnitActionSpec> get actions => const {
    UnitAction.stop: UnitActionSpec(UnitMotion.idle),
  };
}
