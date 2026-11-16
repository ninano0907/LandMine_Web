import 'dart:math' as math;
import '../game_unit.dart';
import '../stats.dart';
import '../actions.dart';
import '../animation.dart';
import '../mineral_targets.dart';
import '../../resources/mineral_deposit.dart';
import '../../buildings/command_center.dart';

enum GatheringPhase { none, approaching, mining, delivering }

class EngineerUnit extends GameUnit {
  EngineerUnit({required super.position, required super.upgrades, super.grid})
    : super(stats: const UnitStats(speed: emptySpeed));

  static const emptySpeed = 100.0;
  static const loadedSpeed = 70.0;
  static const strikesPerLoad = 3;
  static const mineralsPerLoad = 5;
  math.Point<double>? _mineral;
  MineralDeposit? _source;
  CommandCenter? _home;
  GatheringPhase _phase = GatheringPhase.none;
  int _cargo = 0;
  int _strikes = 0;
  double _miningElapsed = 0;
  int get cargo => _cargo;
  bool get hasCargo => _cargo > 0;
  @override
  double get speed => hasCargo ? loadedSpeed : stats.speed;
  int get strikes => _strikes;
  GatheringPhase get gatheringPhase => _phase;
  bool get delivering => _phase == GatheringPhase.delivering;
  @override
  String get label => '일꾼';
  @override
  int get colorValue => 0xffffc107;
  @override
  bool get canUpgradeAttack => false;
  @override
  math.Point<double>? get workTarget => _mineral;
  @override
  Map<UnitAction, UnitActionSpec> get actions => {
    ...super.actions,
    UnitAction.move: UnitActionSpec(
      UnitMotion.walk,
      cycleSeconds: (2 / 3) * emptySpeed / speed,
    ),
    UnitAction.gather: const UnitActionSpec(UnitMotion.mine),
    UnitAction.repair: const UnitActionSpec(UnitMotion.repair),
    UnitAction.build: const UnitActionSpec(UnitMotion.repair),
  };

  /// Visual-only gathering remains available for isolated animation tests.
  void gatherAt(math.Point<double> mineral) {
    if (!alive) return;
    stop();
    _mineral = mineral;
    approachMineral();
  }

  void gather(MineralDeposit source, CommandCenter home) {
    if (!alive) return;
    stop();
    _source = source;
    _home = home;
    _mineral = source.position;
    if (_cargo > 0) {
      beginDelivery();
    } else {
      approachMineral();
    }
  }

  void returnCargo(CommandCenter home) {
    if (!alive || _cargo == 0) return;
    _home = home;
    beginDelivery();
  }

  void approachMineral() {
    final target = _mineral;
    if (target == null || (_source?.depleted ?? false)) {
      stop();
      return;
    }
    final candidates = [
      miningApproach(position, target),
      for (var i = 0; i < 8; i++)
        math.Point(
          target.x + math.cos(i * math.pi / 4) * miningStandOff,
          target.y + math.sin(i * math.pi / 4) * miningStandOff,
        ),
    ];
    candidates.sort(
      (a, b) => position.distanceTo(a).compareTo(position.distanceTo(b)),
    );
    final reserved = _source?.miningPosition(this);
    if (reserved != null) candidates.insert(0, reserved);
    for (final candidate in candidates) {
      final source = _source;
      if (source != null && !source.reserveMiningPosition(this, candidate)) {
        continue;
      }
      if (travelTo(candidate)) {
        _phase = GatheringPhase.approaching;
        if (moving) {
          startAction(UnitAction.move);
        } else {
          onArrival();
        }
        return;
      }
      source?.releaseMiningPosition(this);
    }
    stop();
  }

  void beginDelivery() {
    final home = _home;
    if (home == null) {
      stop();
      return;
    }
    final points = home.dropOffPoints(
      radius,
    )..sort((a, b) => position.distanceTo(a).compareTo(position.distanceTo(b)));
    for (final point in points) {
      if (travelTo(point)) {
        _phase = GatheringPhase.delivering;
        if (moving) {
          startAction(UnitAction.move);
        } else {
          onArrival();
        }
        return;
      }
    }
    stop(); // Carrying minerals are preserved if no route is available.
  }

  @override
  void cancelWork() {
    _source?.releaseMiningPosition(this);
    _mineral = null;
    _source = null;
    _home = null;
    _phase = GatheringPhase.none;
    _strikes = 0;
    _miningElapsed = 0;
    // Manual stop/move must never discard already mined cargo.
  }

  @override
  void onArrival() {
    if (delivering) {
      _home!.deposit(_cargo);
      _cargo = 0;
      if (_source != null && !_source!.depleted) {
        approachMineral();
      } else {
        stop();
      }
      return;
    }
    final target = _mineral;
    if (target == null) {
      super.onArrival();
      return;
    }
    facing = math.atan2(target.y - position.y, target.x - position.x);
    _phase = GatheringPhase.mining;
    _strikes = 0;
    _miningElapsed = 0;
    startAction(UnitAction.gather);
  }

  @override
  void onActionTick(double seconds) {
    if (_phase != GatheringPhase.mining || _source == null) return;
    _miningElapsed += seconds;
    final cycle = actions[UnitAction.gather]!.cycleSeconds;
    // Frame 5 is the low pickaxe impact in each eight-frame mining cycle.
    while (_strikes < strikesPerLoad &&
        _miningElapsed + 1e-9 >= (_strikes + 5 / 8) * cycle) {
      _strikes++;
    }
    if (_strikes == strikesPerLoad) {
      _cargo += _source!.take(mineralsPerLoad);
      if (_cargo > 0) {
        beginDelivery();
      } else {
        stop();
      }
    }
  }
}
