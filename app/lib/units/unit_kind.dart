import 'dart:math';
import 'characters/engineer.dart';
import 'characters/soldier.dart';
import 'characters/cavalry.dart';
import 'characters/shotgun.dart';
import 'game_unit.dart';
import 'upgrades.dart';
import '../world/grid_map.dart';

enum UnitKind {
  engineer('일꾼'),
  soldier('보병'),
  shotgun('산탄병'),
  cavalry('기마병');

  const UnitKind(this.label);
  final String label;

  GameUnit spawn(
    Point<double> position,
    UnitUpgrades upgrades, {
    GridMap? grid,
  }) => switch (this) {
    UnitKind.engineer => EngineerUnit(
      position: position,
      upgrades: upgrades,
      grid: grid,
    ),
    UnitKind.soldier => SoldierUnit(
      position: position,
      upgrades: upgrades,
      grid: grid,
    ),
    UnitKind.shotgun => ShotgunUnit(
      position: position,
      upgrades: upgrades,
      grid: grid,
    ),
    UnitKind.cavalry => CavalryUnit(
      position: position,
      upgrades: upgrades,
      grid: grid,
    ),
  };
}
