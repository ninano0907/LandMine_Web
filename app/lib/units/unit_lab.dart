import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'actions.dart';
import 'characters/engineer.dart';
import 'characters/shotgun.dart';
import 'combat/ranged_unit.dart';
import 'game_unit.dart';
import '../resources/mineral_deposit.dart';
import '../world/unit_lab_world.dart';
import 'unit_kind.dart';
import 'upgrades.dart';
import 'rendering/unit_sprites.dart';
import 'rendering/unit_lab_painter.dart';

/// A sandbox for testing each character independently from maps and game rules.
class UnitLab extends StatefulWidget {
  const UnitLab({super.key});
  @override
  State<UnitLab> createState() => _UnitLabState();
}

class _UnitLabState extends State<UnitLab> with SingleTickerProviderStateMixin {
  static const field = Size(800, 480);
  late UnitLabWorld world;
  double factoryElapsed = 0;
  final upgrades = UnitUpgrades();
  final sprites = UnitSprites();
  UnitKind kind = UnitKind.engineer;
  late GameUnit unit;
  late final Ticker ticker;
  Duration previous = Duration.zero;
  bool selected = false;
  bool paused = false;
  TrainingSetup targetSetup = TrainingSetup.eightDirections;
  String? orderHint;

  @override
  void initState() {
    super.initState();
    reset();
    sprites.addListener(refreshSprites);
    sprites.load();
    ticker = createTicker((elapsed) {
      final seconds = (elapsed - previous).inMicroseconds / 1000000;
      previous = elapsed;
      if (!paused) {
        setState(() {
          final dt = seconds.clamp(0.0, 0.1);
          factoryElapsed += dt;
          if (unit.needsUpdate) unit.update(dt);
        });
      }
    })..start();
  }

  void refreshSprites() {
    if (mounted) setState(() {});
  }

  @override
  void reassemble() {
    super.reassemble();
    sprites.load();
  }

  void reset() {
    world = UnitLabWorld();
    factoryElapsed = 0;
    world.configureTargets(targetSetup);
    unit = kind.spawn(
      kind == UnitKind.engineer ? UnitLabWorld.spawn : UnitLabWorld.combatSpawn,
      upgrades,
      grid: world.grid,
    );
    orderHint = null;
    unit.facing = 3 * math.pi / 4;
    selected = false;
    paused = false;
  }

  void command(Offset point) {
    final body = Rect.fromLTWH(
      unit.position.x - 30,
      unit.position.y - 68,
      60,
      82,
    );
    MineralDeposit? hitMineral;
    for (final deposit in world.deposits.where((d) => !d.depleted)) {
      final mineral = Offset(deposit.position.x, deposit.position.y);
      if (Rect.fromLTWH(
        mineral.dx - 38,
        mineral.dy - 58,
        76,
        76,
      ).contains(point)) {
        hitMineral = deposit;
        break;
      }
    }
    setState(() {
      final current = unit;
      if (selected && current is RangedUnit) {
        for (final target in world.targets) {
          if (Rect.fromLTWH(
            target.position.x - 22,
            target.position.y - 52,
            44,
            66,
          ).contains(point)) {
            paused = false;
            orderHint = current.fireAt(target, nearby: world.targets)
                ? null
                : target.alive
                ? '사거리 밖입니다. 표적 가까이 이동하세요.'
                : '표적을 초기화해 주세요.';
            return;
          }
        }
      }
      if (selected && current is EngineerUnit && hitMineral != null) {
        paused = false;
        current.gather(hitMineral, world.commandCenter);
      } else if (selected &&
          current is EngineerUnit &&
          world.commandCenter.contains(math.Point(point.dx, point.dy))) {
        paused = false;
        current.returnCargo(world.commandCenter);
      } else if (body.contains(point)) {
        selected = true;
      } else if (selected) {
        orderHint = null;
        unit.moveTo(
          math.Point(
            point.dx.clamp(unit.radius, field.width - unit.radius).toDouble(),
            point.dy.clamp(unit.radius, field.height - unit.radius).toDouble(),
          ),
        );
      }
    });
  }

  String get motionLabel {
    final current = unit;
    if (current is EngineerUnit) {
      if (current.delivering) return '금 운반 중';
      if (current.gatheringPhase == GatheringPhase.mining) {
        return '채굴 ${current.strikes}/3';
      }
    }
    return orderHint ?? unit.action.label;
  }

  void perform(UnitAction action) => setState(() {
    if (unit.perform(action)) paused = false;
  });

  void mineNearest() {
    final current = unit;
    if (current is! EngineerUnit) return;
    final available = world.deposits.where((d) => !d.depleted).toList();
    if (available.isEmpty) return;
    available.sort(
      (a, b) => current.position
          .distanceTo(a.position)
          .compareTo(current.position.distanceTo(b.position)),
    );
    paused = false;
    current.gather(available.first, world.commandCenter);
  }

  void shootNearest() {
    final current = unit;
    if (current is! RangedUnit) return;
    final alive = world.targets.where((target) => target.alive).toList()
      ..sort(
        (a, b) => current.position
            .distanceTo(a.position)
            .compareTo(current.position.distanceTo(b.position)),
      );
    if (alive.isEmpty) {
      orderHint = '표적을 초기화해 주세요.';
      return;
    }
    paused = false;
    orderHint = current.fireAt(alive.first, nearby: world.targets)
        ? null
        : '사거리 밖입니다.';
  }

  void changeTargets(TrainingSetup setup) => setState(() {
    targetSetup = setup;
    reset();
    selected = true;
  });

  @override
  void dispose() {
    ticker.dispose();
    sprites.removeListener(refreshSprites);
    sprites.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xff101b24),
    body: SafeArea(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 36, 12, 8),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  '유닛 액션 테스트',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '보관 금 ${world.commandCenter.storedMinerals}',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
                for (final option in UnitKind.values)
                  ChoiceChip(
                    label: Text(option.label),
                    selected: kind == option,
                    onSelected: (_) => setState(() {
                      kind = option;
                      reset();
                    }),
                  ),
                OutlinedButton(
                  onPressed: () => setState(() => paused = !paused),
                  child: Text(paused ? '재개' : '일시정지'),
                ),
                OutlinedButton(
                  onPressed: () => setState(reset),
                  child: const Text('초기화'),
                ),
              ],
            ),
          ),
          if (sprites.error != null)
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  sprites.error!,
                  style: const TextStyle(color: Colors.orangeAccent),
                ),
                TextButton(
                  onPressed: sprites.load,
                  child: const Text('이미지 재시도'),
                ),
              ],
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              unit is RangedUnit
                  ? '유닛 선택 → 바닥 클릭으로 이동 · 표적 클릭으로 연속 사격 · 이동/정지하면 사격 중단'
                  : '일꾼 선택 → 금광석 클릭 · 곡괭이질 3회 → 운반·입고 → 자동 반복',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          Expanded(
            child: Center(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FittedBox(
                  child: SizedBox(
                    width: field.width,
                    height: field.height,
                    child: GestureDetector(
                      key: const ValueKey('unit-lab-field'),
                      behavior: HitTestBehavior.opaque,
                      onTapDown: (event) => command(event.localPosition),
                      child: CustomPaint(
                        painter: UnitLabPainter(
                          unit,
                          selected,
                          sprites,
                          unit is RangedUnit ? [] : world.deposits,
                          world.commandCenter,
                          (factoryElapsed * 5).floor() % 4,
                          unit is RangedUnit ? world.targets : [],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                if (!selected)
                  const Text(
                    '캐릭터를 클릭하면 기능 버튼이 표시됩니다.',
                    style: TextStyle(color: Colors.white70),
                  ),
                if (selected) ...[
                  FilledButton(
                    onPressed: () => setState(() {
                      unit.stop();
                    }),
                    child: const Text('정지 / 대기'),
                  ),
                  if (unit is RangedUnit) ...[
                    FilledButton(
                      onPressed: () => setState(shootNearest),
                      child: const Text('사격'),
                    ),
                    OutlinedButton(
                      onPressed: () =>
                          changeTargets(TrainingSetup.eightDirections),
                      child: const Text('8방향 표적'),
                    ),
                    if (unit is ShotgunUnit) ...[
                      OutlinedButton(
                        onPressed: () =>
                            changeTargets(TrainingSetup.closeSingle),
                        child: const Text('근거리 1기'),
                      ),
                      OutlinedButton(
                        onPressed: () => changeTargets(TrainingSetup.farGroup),
                        child: const Text('원거리 3기'),
                      ),
                    ],
                  ],
                  if (unit.supports(UnitAction.gather))
                    FilledButton(
                      onPressed: () => setState(mineNearest),
                      child: const Text('채굴'),
                    ),
                  for (final action in [UnitAction.repair, UnitAction.build])
                    if (unit.supports(action))
                      FilledButton(
                        onPressed: () => perform(action),
                        child: Text(action.label),
                      ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              '${kind.label} · ${paused ? "일시정지" : motionLabel} '
              '· 위치 ${unit.position.x.toStringAsFixed(1)}, ${unit.position.y.toStringAsFixed(1)} '
              '${unit is EngineerUnit ? "· ${(unit as EngineerUnit).hasCargo ? "찬 배낭" : "빈 배낭"} · 금 ${(unit as EngineerUnit).cargo} " : ""}'
              '${unit is RangedUnit ? "· 발사 ${(unit as RangedUnit).shotsFired} · 적중 ${(unit as RangedUnit).lastHits.length}기 · 피해 ${(unit as RangedUnit).lastHits.values.fold(0, (sum, value) => sum + value)} " : ""}'
              '· 체력 ${unit.health}/${unit.stats.maxHealth} '
              '· 공격 ${unit.attackPower} · 방어 ${unit.defense} '
              '· 속도 ${unit.speed.toInt()} /초 '
              '· 방향 ${(unit.facing * 180 / math.pi).toStringAsFixed(0)}°',
              style: const TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    ),
  );
}
