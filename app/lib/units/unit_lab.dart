import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'actions.dart';
import 'characters/engineer.dart';
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
  late GameUnit unit;
  final units = <GameUnit>[];
  late final Ticker ticker;
  Duration previous = Duration.zero;
  bool selected = false;
  bool paused = false;
  bool barracksSelected = false;
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
          for (final current in units) {
            if (current.needsUpdate) current.update(dt);
          }
          final recruit = world.barracks.update(dt, upgrades, units);
          if (recruit != null) units.add(recruit);
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
    barracksSelected = false;
    units
      ..clear()
      ..addAll([
        for (final position in UnitLabWorld.workerSpawns)
          UnitKind.engineer.spawn(position, upgrades, grid: world.grid)
            ..facing = 3 * math.pi / 4,
      ]);
    unit = units.first;
    orderHint = null;
    selected = false;
    paused = false;
  }

  void command(Offset point) {
    // Prefer the frontmost character when sprite hit boxes overlap.
    final hitUnits = units.where((candidate) {
      final scale = candidate is EngineerUnit || candidate is RangedUnit
          ? 0.5
          : 1.0;
      return Rect.fromLTWH(
        candidate.position.x - 26 * scale,
        candidate.position.y - 60 * scale,
        52 * scale,
        74 * scale,
      ).contains(point);
    }).toList()..sort((a, b) => b.position.y.compareTo(a.position.y));
    if (hitUnits.isNotEmpty) {
      setState(() {
        unit = hitUnits.first;
        barracksSelected = false;
        selected = true;
        orderHint = null;
      });
      return;
    }
    if (world.barracks.contains(math.Point(point.dx, point.dy))) {
      setState(() {
        barracksSelected = true;
        selected = false;
      });
      return;
    }
    MineralDeposit? hitMineral;
    final clickableDeposits = world.deposits.where((d) => !d.depleted).toList()
      ..sort((a, b) => b.position.y.compareTo(a.position.y));
    for (final deposit in clickableDeposits) {
      final mineral = Offset(deposit.position.x, deposit.position.y);
      if (Rect.fromLTWH(
        mineral.dx - MineralDeposit.width / 2,
        mineral.dy - MineralDeposit.height + MineralDeposit.bottomOffset,
        MineralDeposit.width,
        MineralDeposit.height,
      ).contains(point)) {
        hitMineral = deposit;
        break;
      }
    }
    setState(() {
      final current = unit;
      if (selected && current is EngineerUnit && hitMineral != null) {
        paused = false;
        current.gather(hitMineral, world.commandCenter);
      } else if (selected &&
          current is EngineerUnit &&
          world.commandCenter.contains(math.Point(point.dx, point.dy))) {
        paused = false;
        current.returnCargo(world.commandCenter);
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

  void train(UnitKind kind) => setState(() {
    world.barracks.enqueue(kind);
    barracksSelected = true;
    selected = false;
    paused = false;
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
                  '본진 · 훈련소',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '보관 금 ${world.commandCenter.storedMinerals} · 병력 ${units.whereType<RangedUnit>().length}기',
                  style: const TextStyle(color: Colors.cyanAccent),
                ),
                OutlinedButton(
                  onPressed: () => setState(() {
                    unit = units.firstWhere((unit) => unit is EngineerUnit);
                    selected = true;
                    barracksSelected = false;
                  }),
                  child: const Text('일꾼'),
                ),
                for (final option in [UnitKind.soldier, UnitKind.shotgun])
                  FilledButton(
                    key: ValueKey('train-${option.name}'),
                    onPressed: () => train(option),
                    child: Text('${option.label} 생산'),
                  ),
                const OutlinedButton(
                  onPressed: null,
                  child: Text('기마병 · 마구간 필요'),
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
              '보병·산탄병 생산 → 훈련소에서 3초 후 출병 · 유닛 선택 → 바닥 클릭으로 이동 · 일꾼은 광물 클릭으로 채굴',
              style: const TextStyle(color: Colors.white70),
            ),
          ),
          if (barracksSelected || world.barracks.queue.isNotEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  Text(
                    world.barracks.queue.isEmpty
                        ? '훈련소 · 보병 또는 산탄병 생산을 선택하세요.'
                        : '훈련 중: ${world.barracks.queue.first.label} · ${(world.barracks.progress * 100).floor()}% · 대기 ${world.barracks.queue.length - 1}기',
                    style: const TextStyle(color: Colors.amberAccent),
                  ),
                  if (world.barracks.queue.isNotEmpty)
                    LinearProgressIndicator(value: world.barracks.progress),
                ],
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
                          world.deposits,
                          world.commandCenter,
                          (factoryElapsed * 5).floor() % 4,
                          const [],
                          units: units,
                          barracks: world.barracks,
                          barracksSelected: barracksSelected,
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
              '${unit.label} · ${paused ? "일시정지" : motionLabel} '
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
