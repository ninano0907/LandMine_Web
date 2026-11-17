import 'dart:math' as math;
import 'dart:ui';
import 'defense.dart';

class GoldSite {
  GoldSite(this.name, this.position);
  final String name;
  final Offset position;
  double remaining = 600;

  // The whole exposed seam can be tapped, including its branching edges.
  bool contains(Offset point) {
    final d = point - position;
    return d.dx * d.dx / (195 * 195) + d.dy * d.dy / (100 * 100) <= 1;
  }

  Offset get dockingPoint => position - FrontierGame.drillContact;
}

class Gunner {
  Gunner(this.position);
  Offset position;
  double hp = 100;
  double cooldown = 0;
}

class Raider {
  Raider(this.position, this.hp, this.speed);
  Offset position;
  double hp;
  final double speed;
  double cooldown = 0;
}

class Shot {
  Shot(this.from, this.to, this.hostile);
  final Offset from, to;
  final bool hostile;
  double life = .13;
}

/// A mobile-first escort defense. Gold is earned only by the walking mine.
class FrontierGame {
  static const world = Size(3600, 2400);
  static const goal = 1500;
  static const finalWave = 12;
  static const startingGold = 480;
  final DefenseWorld defense;
  static const drillContact = Offset(19, 51);
  static const maxCrew = 10;
  final random = math.Random(42);
  final sites = <GoldSite>[
    GoldSite('본부 대광맥', const Offset(620, 1850)),
    GoldSite('선인장 골짜기', const Offset(1180, 1640)),
    GoldSite('붉은 협곡', const Offset(2320, 650)),
    GoldSite('철마 고원', const Offset(3040, 1150)),
    GoldSite('황금 분지', const Offset(2320, 1800)),
    GoldSite('먼지바람 광산', const Offset(1280, 1780)),
    GoldSite('오래된 철길', const Offset(520, 1420)),
  ];
  Offset robot = const Offset(620, 650);
  GoldSite? destination;
  final crew = <Gunner>[];
  final raiders = <Raider>[];
  final shots = <Shot>[];
  double hull = 1200;
  double gold = startingGold.toDouble();
  double extracted = 0;
  double elapsed = 0;
  double robotWalkTime = 0;
  double robotMineTime = 0;
  double waveIn = 20;
  double recruitment = 0;
  double repairCooldown = 0;
  double repairPulse = 0;
  int wave = 0;
  int weaponLevel = 1;
  bool paused = false;
  bool won = false;
  bool lost = false;

  FrontierGame({int? seed})
    : defense = DefenseWorld(seed: seed, populateJungle: true) {
    sites.first.remaining = 3000;
    destination = sites.first;
    robot = sites.first.dockingPoint;
    for (var i = 0; i < 4; i++) {
      crew.add(Gunner(robot + formation(i, 4)));
    }
  }

  bool get finished => won || lost;
  bool get moving =>
      destination != null && (destination!.dockingPoint - robot).distance > .01;
  bool get mining =>
      !moving && destination != null && destination!.remaining > 0 && !finished;
  int get upgradeCost => 100 + weaponLevel * 60;
  String get status => moving
      ? '금광으로 이동 중 · 호위 중'
      : mining
      ? '드릴 가동 · 자동 채굴 중'
      : '금광 고갈 · 다음 금광을 선택하세요';
  static Offset formation(int i, int count) {
    final angle = -math.pi / 2 + i * math.pi * 2 / count;
    return Offset(math.cos(angle) * 150, math.sin(angle) * 100 + 24);
  }

  void travel(GoldSite site) {
    if (!finished && !paused && site.remaining > 0) destination = site;
  }

  bool hire() {
    if (finished ||
        paused ||
        gold < 75 ||
        recruitment > 0 ||
        crew.length >= maxCrew) {
      return false;
    }
    gold -= 75;
    recruitment = 4;
    return true;
  }

  bool upgrade() {
    if (finished || paused || weaponLevel >= 5 || gold < upgradeCost) {
      return false;
    }
    gold -= upgradeCost;
    weaponLevel++;
    return true;
  }

  bool repair() {
    if (finished || paused || repairCooldown > 0 || gold < 60 || hull >= 1200) {
      return false;
    }
    gold -= 60;
    hull = math.min(1200, hull + 300);
    for (final unit in crew) {
      unit.hp = math.min(100, unit.hp + 45);
    }
    repairCooldown = 18;
    repairPulse = 1;
    return true;
  }

  bool deployBot(DefenseVein site) {
    if (paused ||
        finished ||
        gold < DefenseWorld.botCost ||
        !defense.deploy(site)) {
      return false;
    }
    gold -= DefenseWorld.botCost;
    return true;
  }

  int botUpgradeCost(DefenseVein site) => 100 + (site.bot?.level ?? 0) * 50;
  bool upgradeDefenseBot(DefenseVein site) {
    if (paused || finished || site.bot == null || gold < botUpgradeCost(site)) {
      return false;
    }
    final cost = botUpgradeCost(site);
    if (!defense.upgradeBot(site)) return false;
    gold -= cost;
    return true;
  }

  bool recallBot(DefenseVein site) {
    if (paused || finished || site.bot == null) return false;
    site.bot = null;
    gold += 40;
    return true;
  }

  void tick(double dt) {
    if (paused || finished || dt <= 0) return;
    // Keep long background-tab gaps from advancing combat off-screen.
    dt = dt.clamp(0, .1);
    elapsed += dt;
    repairCooldown = math.max(0, repairCooldown - dt);
    repairPulse = math.max(0, repairPulse - dt);
    for (final shot in shots) {
      shot.life -= dt;
    }
    shots.removeWhere((shot) => shot.life <= 0);
    if (recruitment > 0) {
      recruitment = math.max(0, recruitment - dt);
      if (recruitment == 0) crew.add(Gunner(robot + const Offset(-48, 30)));
    }
    if (moving) {
      robot = approach(robot, destination!.dockingPoint, 105 * dt);
      robotWalkTime += dt;
      robotMineTime = 0;
    } else if (mining) {
      robotMineTime += dt;
      final amount = math.min(destination!.remaining, 5.0 * dt);
      destination!.remaining -= amount;
      gold += amount;
      extracted += amount;
    }
    if (wave < finalWave) waveIn -= dt;
    if (wave < finalWave && waveIn <= 0) {
      wave++;
      waveIn = 34;
      defense.spawnWave(wave);
    }
    final battle = defense.tick(
      dt,
      weaponLevel: weaponLevel,
      baseCrew: crew.length,
    );
    gold += battle.income;
    hull -= battle.baseDamage;
    for (var i = 0; i < crew.length; i++) {
      final unit = crew[i];
      if (unit.hp <= 0) continue;
      unit.position = approach(
        unit.position,
        robot + formation(i, crew.length),
        155 * dt,
      );
      unit.cooldown -= dt;
      Raider? target;
      var nearest = 300.0;
      for (final enemy in raiders) {
        if (enemy.hp <= 0) continue;
        final distance = (enemy.position - unit.position).distance;
        if (distance < nearest) {
          nearest = distance;
          target = enemy;
        }
      }
      if (target != null && unit.cooldown <= 0) {
        target.hp -= 15 + weaponLevel * 5;
        unit.cooldown = .8;
        shots.add(
          Shot(
            unit.position + const Offset(0, -16),
            target.position + const Offset(0, -16),
            false,
          ),
        );
      }
      // The engineer maintains the escort between encounters.
      if (raiders.isEmpty) unit.hp = math.min(100, unit.hp + dt * 3);
    }
    for (final enemy in raiders) {
      if (enemy.hp <= 0) continue;
      enemy.cooldown -= dt;
      Gunner? target;
      var distance = 120.0;
      for (final unit in crew) {
        if (unit.hp <= 0) continue;
        final d = (unit.position - enemy.position).distance;
        if (d < distance) {
          distance = d;
          target = unit;
        }
      }
      final aim = target?.position ?? robot;
      final range = target == null ? 100.0 : 64.0;
      if ((enemy.position - aim).distance > range) {
        enemy.position = approach(enemy.position, aim, enemy.speed * dt);
      } else if (enemy.cooldown <= 0) {
        if (target != null) {
          target.hp -= 9;
        } else {
          hull -= 17;
        }
        enemy.cooldown = 1.2;
        shots.add(Shot(enemy.position + const Offset(0, -15), aim, true));
      }
    }
    raiders.removeWhere((enemy) => enemy.hp <= 0);
    crew.removeWhere((unit) => unit.hp <= 0);
    if (hull <= 0) {
      hull = 0;
      lost = true;
    }
    if (!lost &&
        wave >= finalWave &&
        defense.enemies.every((e) => e.lane == null)) {
      won = true;
    }
  }

  static Offset approach(Offset from, Offset to, double distance) {
    final delta = to - from;
    return delta.distance <= distance
        ? to
        : from + delta / delta.distance * distance;
  }
}
