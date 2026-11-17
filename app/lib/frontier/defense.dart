import 'dart:math' as math;
import 'dart:ui';

enum EnemyAttack { gun, throwBomb, rollingBomb, commander }

enum HazardKind { gun, blast, rolling, drill }

enum CompanionRole { gunner, demolition, mechanic }

class PlayerHero {
  Offset position = DefenseWorld.home + const Offset(260, -40);
  Offset input = Offset.zero;
  Offset facing = const Offset(0, -1);
  Offset? goal;
  double hp = 260,
      maxHp = 260,
      shotCooldown = 0,
      rollCooldown = 0,
      rolling = 0,
      respawn = 0,
      hurt = 0;
  Offset rollDirection = const Offset(0, -1);
  bool firing = false;
  int level = 1, xp = 0;
  bool get alive => hp > 0 && respawn <= 0;
}

class DefenseVein {
  DefenseVein(this.id, this.lane, this.depth, this.position);
  final int id, lane, depth;
  final Offset position;
  double ore = 1200;
  MiningBot? bot;
  bool contains(Offset point) {
    final d = point - position;
    return d.dx * d.dx / (125 * 125) + d.dy * d.dy / (75 * 75) <= 1;
  }
}

class MiningBot {
  MiningBot(this.position);
  Offset position;
  Offset direction = const Offset(0, -1);
  double hp = 420, maxHp = 420, cooldown = 0, walkTime = 0, mineTime = 0;
  int level = 1;
}

class FieldEnemy {
  FieldEnemy({
    required this.id,
    required this.position,
    required this.attack,
    required this.maxHp,
    this.lane,
    this.campId,
    this.neutralId,
    this.speed = 72,
  }) : hp = maxHp;
  final int id;
  Offset position;
  final EnemyAttack attack;
  final double maxHp, speed;
  double hp, cooldown = 1, hurt = 0;
  final int? lane, campId, neutralId;
  int waypoint = 0, pattern = 0;
  bool get boss => attack == EnemyAttack.commander;
}

class RescueCamp {
  RescueCamp(this.id, this.candidate, this.stage, this.position, this.guardIds);
  final int id, candidate, stage;
  final Offset position;
  final List<int> guardIds;
  bool discovered = false, rescued = false;
}

class RescuedCompanion {
  RescuedCompanion(this.campId, this.role, this.name);
  final int campId;
  final CompanionRole role;
  final String name;
  int? lane;
  double cooldown = 0, transferCooldown = 0;
}

class JungleCamp {
  JungleCamp(this.id, this.position);
  final int id;
  final Offset position;
  final ids = <int>[];
  double respawn = 50;
}

class CombatTrace {
  CombatTrace(this.from, this.to, this.friendly);
  final Offset from, to;
  final bool friendly;
  double remaining = .12;
}

class Hazard {
  Hazard(
    this.kind,
    this.from,
    this.target,
    this.duration,
    this.damage, {
    this.source = -1,
    this.radius = 65,
    this.velocity = Offset.zero,
  }) : position = from,
       remaining = duration;
  final HazardKind kind;
  final Offset from, target, velocity;
  final double duration, damage, radius;
  final int source;
  Offset position;
  double remaining;
  bool impacted = false;
}

/// Three-lane mining defense and skill-based hero encounters.
/// Camps are selected once from 12 candidates; discovered camps persist.
class DefenseWorld {
  DefenseWorld({int? seed, bool populateJungle = false})
    : random = math.Random(seed) {
    for (var lane = 0; lane < 3; lane++) {
      final positions = veinPositions[lane];
      for (var depth = 0; depth < positions.length; depth++) {
        veins.add(DefenseVein(veins.length, lane, depth, positions[depth]));
      }
    }
    if (populateJungle) {
      for (final point in [
        const Offset(1110, 1070),
        const Offset(1780, 1750),
        const Offset(2090, 1130),
        const Offset(2750, 900),
      ]) {
        final nest = JungleCamp(jungle.length, point);
        jungle.add(nest);
        _spawnJungle(nest);
      }
    }
  }
  static const home = Offset(560, 1900), enemyHome = Offset(3180, 360);
  static const laneNames = ['탑', '미드', '바텀'];
  // Paths run from enemy at 1 o'clock toward the player's 7 o'clock home.
  static const paths = <List<Offset>>[
    [
      enemyHome,
      Offset(1800, 340),
      Offset(700, 470),
      Offset(450, 1000),
      Offset(470, 1470),
      home,
    ],
    [enemyHome, Offset(2230, 850), Offset(1550, 1320), Offset(970, 1700), home],
    [
      enemyHome,
      Offset(3180, 1100),
      Offset(3000, 1620),
      Offset(2200, 2010),
      Offset(1350, 2000),
      home,
    ],
  ];
  static const veinPositions = <List<Offset>>[
    [Offset(470, 1470), Offset(450, 1000), Offset(700, 470)],
    [Offset(970, 1700), Offset(1550, 1320), Offset(2230, 850)],
    [Offset(1350, 2000), Offset(2200, 2010), Offset(3000, 1620)],
  ];
  static const campCandidates = <Offset>[
    Offset(950, 1420),
    Offset(1250, 1880),
    Offset(740, 1130),
    Offset(1200, 1170),
    Offset(1770, 1620),
    Offset(1890, 1020),
    Offset(1340, 700),
    Offset(2500, 1770),
    Offset(2710, 1260),
    Offset(2210, 570),
    Offset(2820, 600),
    Offset(1770, 440),
  ];
  static const campWaves = [3, 6, 9];
  static const botCost = 140, maxBots = 6;
  final math.Random random;
  final hero = PlayerHero();
  final veins = <DefenseVein>[];
  final enemies = <FieldEnemy>[];
  final camps = <RescueCamp>[];
  final jungle = <JungleCamp>[];
  final companions = <RescuedCompanion>[];
  final hazards = <Hazard>[];
  final traces = <CombatTrace>[];
  int _nextEnemy = 0;
  double elapsed = 0, baseCooldown = 0;
  String notice = '광맥을 선택해 채굴 방어 봇을 배치하세요';
  double noticeTime = 8;
  int get botCount => veins.where((v) => v.bot != null && v.bot!.hp > 0).length;
  void announce(String value) {
    notice = value;
    noticeTime = 6;
  }

  static Offset normalize(Offset value) =>
      value.distance < .001 ? Offset.zero : value / value.distance;
  static Offset move(Offset from, Offset to, double amount) {
    final d = to - from;
    return d.distance <= amount ? to : from + d / d.distance * amount;
  }

  static Offset clamp(Offset p) =>
      Offset(p.dx.clamp(55, 3545).toDouble(), p.dy.clamp(55, 2345).toDouble());
  DefenseVein? veinAt(Offset point) {
    for (final site in veins) {
      if (site.contains(point)) return site;
    }
    return null;
  }

  bool deploy(DefenseVein site) {
    if (!veins.contains(site) || site.bot != null || botCount >= maxBots) {
      return false;
    }
    site.bot = MiningBot(home + const Offset(35, -30));
    return true;
  }

  bool upgradeBot(DefenseVein site) {
    final bot = site.bot;
    if (bot == null || bot.level >= 4) return false;
    bot.level++;
    bot.maxHp += 120;
    bot.hp = math.min(bot.maxHp, bot.hp + 180);
    return true;
  }

  bool isDocked(DefenseVein site) =>
      site.bot != null && (site.bot!.position - site.position).distance < .1;

  void _spawnJungle(JungleCamp camp) {
    camp.ids.clear();
    camp.respawn = 50;
    for (var i = 0; i < 2; i++) {
      final enemy = FieldEnemy(
        id: _nextEnemy++,
        position: camp.position + Offset(i == 0 ? -45 : 45, 0),
        attack: i == 0 ? EnemyAttack.throwBomb : EnemyAttack.rollingBomb,
        maxHp: 74,
        neutralId: camp.id,
        speed: 48,
      );
      enemies.add(enemy);
      camp.ids.add(enemy.id);
    }
  }

  void spawnWave(int wave) {
    for (var lane = 0; lane < 3; lane++) {
      // A highlighted lane gets one additional enemy, not three simultaneous bosses.
      final count = 2 + wave ~/ 3 + (lane == (wave - 1) % 3 ? 1 : 0);
      for (var i = 0; i < count; i++) {
        enemies.add(
          FieldEnemy(
            id: _nextEnemy++,
            position: enemyHome + Offset(i * 18.0, lane * 22.0),
            attack: EnemyAttack.gun,
            maxHp: 48 + wave * 5.0,
            lane: lane,
            speed: 92 + wave * 2,
          ),
        );
      }
    }
    updateCampSpawns(wave);
  }

  void updateCampSpawns(int wave) {
    for (var stage = 0; stage < campWaves.length; stage++) {
      if (wave < campWaves[stage] || camps.any((c) => c.stage == stage)) {
        continue;
      }
      final candidate = stage * 4 + random.nextInt(4);
      final point = campCandidates[candidate];
      final ids = <int>[];
      final camp = RescueCamp(camps.length, candidate, stage, point, ids);
      camps.add(camp);
      final boss = FieldEnemy(
        id: _nextEnemy++,
        position: point + const Offset(0, -100),
        attack: EnemyAttack.commander,
        maxHp: 320 + stage * 110.0,
        campId: camp.id,
        speed: 46,
      );
      enemies.add(boss);
      ids.add(boss.id);
      for (var i = 0; i < (stage == 0 ? 3 : 4); i++) {
        final angle = i * math.pi * 2 / (stage == 0 ? 3 : 4);
        final attack = i == 0
            ? EnemyAttack.gun
            : i == 1
            ? EnemyAttack.throwBomb
            : EnemyAttack.rollingBomb;
        final unit = FieldEnemy(
          id: _nextEnemy++,
          position: point + Offset(math.cos(angle) * 95, math.sin(angle) * 70),
          attack: attack,
          maxHp: 48 + stage * 14.0,
          campId: camp.id,
          speed: 52,
        );
        enemies.add(unit);
        ids.add(unit.id);
      }
      announce('${campWaves[stage]}차 습격 · 정글에서 구조 신호가 들립니다');
    }
  }

  int guardsLeft(RescueCamp camp) =>
      enemies.where((e) => e.campId == camp.id && e.hp > 0).length;
  RescueCamp? get nearbyCamp {
    for (final camp in camps) {
      if (!camp.rescued &&
          camp.discovered &&
          (camp.position - hero.position).distance < 115) {
        return camp;
      }
    }
    return null;
  }

  RescuedCompanion? rescue() {
    final camp = nearbyCamp;
    if (!hero.alive || camp == null || guardsLeft(camp) > 0) return null;
    camp.rescued = true;
    const names = ['기관총 사수 로즈', '폭파 전문가 잭', '정비사 루'];
    final companion = RescuedCompanion(
      camp.id,
      CompanionRole.values[camp.stage],
      names[camp.stage],
    );
    companions.add(companion);
    announce('${companion.name} 구출! 배치할 라인을 선택하세요');
    return companion;
  }

  bool assign(RescuedCompanion unit, int lane) {
    if (!companions.contains(unit) ||
        lane < 0 ||
        lane > 2 ||
        unit.transferCooldown > 0) {
      return false;
    }
    final occupied = companions.where((c) => c.lane == lane && c != unit);
    if (occupied.isNotEmpty) {
      final other = occupied.first;
      if (other.transferCooldown > 0) return false;
      other.lane = unit.lane;
      other.transferCooldown = 3;
    }
    unit.lane = lane;
    unit.transferCooldown = 3;
    announce('${unit.name} → ${laneNames[lane]} 배치');
    return true;
  }

  Offset companionPosition(RescuedCompanion unit) {
    final lane = unit.lane;
    if (lane == null) return home;
    final occupied =
        veins
            .where((v) => v.lane == lane && v.bot != null && isDocked(v))
            .toList()
          ..sort((a, b) => b.depth.compareTo(a.depth));
    return (occupied.isEmpty
            ? veinPositions[lane].first
            : occupied.first.position) +
        const Offset(-48, 42);
  }

  FieldEnemy? closestEnemy(Offset from, double range, {int? lane}) {
    FieldEnemy? target;
    var nearest = range;
    for (final e in enemies) {
      if (e.hp <= 0 || (lane != null && e.lane != lane)) continue;
      final distance = (e.position - from).distance;
      if (distance < nearest) {
        nearest = distance;
        target = e;
      }
    }
    return target;
  }

  bool fire() {
    if (!hero.alive || hero.shotCooldown > 0) return false;
    final enemy = closestEnemy(hero.position, 365);
    hero.shotCooldown = .32;
    if (enemy != null) {
      hero.facing = normalize(enemy.position - hero.position);
      enemy.hp -= 24 + (hero.level - 1) * 4;
      enemy.hurt = .15;
      traces.add(CombatTrace(hero.position, enemy.position, true));
    } else {
      traces.add(
        CombatTrace(hero.position, hero.position + hero.facing * 300, true),
      );
    }
    return true;
  }

  bool roll() {
    if (!hero.alive || hero.rollCooldown > 0) return false;
    hero.rollDirection = hero.input.distance > .1
        ? normalize(hero.input)
        : hero.facing;
    hero.rolling = .28;
    hero.rollCooldown = 3.5;
    hero.goal = null;
    return true;
  }

  void moveHero(Offset direction) {
    hero.input = normalize(direction);
    hero.goal = null;
  }

  void walkTo(Offset point) {
    hero.goal = clamp(point);
    hero.input = Offset.zero;
  }

  void _hurtHero(double damage) {
    if (!hero.alive || hero.rolling > 0) return;
    hero.hp = math.max(0, hero.hp - damage);
    hero.hurt = .2;
    if (hero.hp == 0) {
      hero.respawn = 7;
      hero.firing = false;
      hero.input = Offset.zero;
      hero.goal = null;
      announce('영웅이 쓰러졌습니다 · 7초 후 본부에서 복귀');
    }
  }

  void _attackHero(FieldEnemy enemy) {
    final target = hero.position;
    final stage = enemy.campId == null
        ? 0
        : camps.firstWhere((c) => c.id == enemy.campId).stage;
    final patterns = stage == 0
        ? [HazardKind.blast]
        : stage == 1
        ? [HazardKind.blast, HazardKind.drill]
        : [HazardKind.blast, HazardKind.drill, HazardKind.rolling];
    final kind = enemy.attack == EnemyAttack.gun
        ? HazardKind.gun
        : enemy.attack == EnemyAttack.throwBomb
        ? HazardKind.blast
        : enemy.attack == EnemyAttack.rollingBomb
        ? HazardKind.rolling
        : patterns[enemy.pattern++ % patterns.length];
    enemy.cooldown = enemy.boss
        ? 2.2
        : enemy.attack == EnemyAttack.gun
        ? 1.65
        : 3.0;
    switch (kind) {
      case HazardKind.gun:
        hazards.add(
          Hazard(kind, enemy.position, target, .5, 7, source: enemy.id),
        );
      case HazardKind.blast:
        hazards.add(
          Hazard(
            kind,
            enemy.position,
            target,
            1.15,
            enemy.boss ? 42 : 24,
            radius: enemy.boss ? 88 : 65,
            source: enemy.id,
          ),
        );
      case HazardKind.rolling:
        hazards.add(
          Hazard(
            kind,
            enemy.position,
            target,
            3.4,
            enemy.boss ? 35 : 22,
            velocity: normalize(target - enemy.position) * 135,
            radius: 55,
            source: enemy.id,
          ),
        );
      case HazardKind.drill:
        hazards.add(
          Hazard(
            kind,
            enemy.position,
            enemy.position + normalize(target - enemy.position) * 420,
            .95,
            44,
            radius: 22,
            source: enemy.id,
          ),
        );
    }
  }

  static double segmentDistance(Offset p, Offset a, Offset b) {
    final delta = b - a;
    final d = delta.distanceSquared;
    if (d < .001) return (p - a).distance;
    final u = (((p - a).dx * delta.dx + (p - a).dy * delta.dy) / d).clamp(
      0.0,
      1.0,
    );
    return (p - (a + delta * u)).distance;
  }

  /// Returns gold earned and damage dealt to the home base in this step.
  ({double income, double baseDamage}) tick(
    double dt, {
    int weaponLevel = 1,
    int baseCrew = 4,
  }) {
    var income = 0.0, baseDamage = 0.0;
    elapsed += dt;
    noticeTime = math.max(0, noticeTime - dt);
    hero.shotCooldown = math.max(0, hero.shotCooldown - dt);
    hero.rollCooldown = math.max(0, hero.rollCooldown - dt);
    hero.hurt = math.max(0, hero.hurt - dt);
    if (hero.respawn > 0) {
      hero.respawn = math.max(0, hero.respawn - dt);
      if (hero.respawn == 0) {
        hero.position = home + const Offset(240, -30);
        hero.hp = hero.maxHp;
      }
    } else if (hero.alive) {
      if (hero.rolling > 0) {
        hero.position = clamp(hero.position + hero.rollDirection * 700 * dt);
        hero.rolling = math.max(0, hero.rolling - dt);
      } else {
        var input = hero.input;
        if (input.distance < .01 && hero.goal != null) {
          if ((hero.goal! - hero.position).distance < 6) {
            hero.goal = null;
          } else {
            input = normalize(hero.goal! - hero.position);
          }
        }
        if (input.distance > .01) {
          hero.facing = normalize(input);
          hero.position = clamp(hero.position + input * 195 * dt);
        }
      }
      if (hero.firing) fire();
      if ((hero.position - home).distance < 200) {
        hero.hp = math.min(hero.maxHp, hero.hp + 18 * dt);
      }
    }
    for (final camp in camps) {
      if ((camp.position - hero.position).distance < 440) {
        camp.discovered = true;
      }
    }
    for (final t in traces) {
      t.remaining -= dt;
    }
    traces.removeWhere((t) => t.remaining <= 0);
    for (final site in veins) {
      final bot = site.bot;
      if (bot == null) continue;
      if (bot.hp <= 0) {
        site.bot = null;
        announce('${laneNames[site.lane]} 채굴 봇 파괴 · 광맥에 재배치할 수 있습니다');
        continue;
      }
      if (!isDocked(site)) {
        final next = move(bot.position, site.position, 125 * dt);
        bot.direction = normalize(next - bot.position);
        bot.walkTime += (next - bot.position).distance;
        bot.position = next;
        continue;
      }
      bot.mineTime += dt;
      if (site.ore > 0) {
        final amount = math.min(site.ore, 2.5 * dt);
        site.ore -= amount;
        income += amount;
      }
      bot.cooldown -= dt;
      final enemy = closestEnemy(bot.position, 335);
      if (enemy != null && bot.cooldown <= 0) {
        enemy.hp -= 20 + bot.level * 6 + weaponLevel * 3;
        enemy.hurt = .12;
        bot.cooldown = .75;
        traces.add(CombatTrace(bot.position, enemy.position, true));
      }
    }
    for (final unit in companions) {
      unit.cooldown -= dt;
      unit.transferCooldown = math.max(0, unit.transferCooldown - dt);
      if (unit.lane == null) continue;
      final position = companionPosition(unit);
      if (unit.role == CompanionRole.mechanic) {
        for (final site in veins.where(
          (v) => v.lane == unit.lane && v.bot != null,
        )) {
          site.bot!.hp = math.min(site.bot!.maxHp, site.bot!.hp + 5 * dt);
        }
      }
      final target = closestEnemy(position, 370);
      if (target != null && unit.cooldown <= 0) {
        final damage = unit.role == CompanionRole.demolition
            ? 60.0
            : unit.role == CompanionRole.gunner
            ? 42.0
            : 30.0;
        target.hp -= damage;
        target.hurt = .15;
        unit.cooldown = unit.role == CompanionRole.demolition ? 1.3 : .65;
        if (unit.role == CompanionRole.demolition) {
          for (final other in enemies) {
            if (other != target &&
                (other.position - target.position).distance < 80) {
              other.hp -= damage * .5;
            }
          }
        }
        traces.add(CombatTrace(position, target.position, true));
      }
    }
    baseCooldown -= dt;
    final baseTarget = closestEnemy(home, 350);
    if (baseTarget != null && baseCooldown <= 0) {
      baseTarget.hp -= 20 + baseCrew * 3 + weaponLevel * 4;
      baseTarget.hurt = .15;
      baseCooldown = .6;
      traces.add(CombatTrace(home, baseTarget.position, true));
    }
    for (final enemy in enemies) {
      if (enemy.hp <= 0) continue;
      enemy.cooldown -= dt;
      enemy.hurt = math.max(0, enemy.hurt - dt);
      final heroDistance = (enemy.position - hero.position).distance;
      if (enemy.neutralId != null) {
        final nest = jungle.firstWhere((c) => c.id == enemy.neutralId);
        if (hero.alive &&
            heroDistance < 430 &&
            (hero.position - nest.position).distance < 560) {
          if (heroDistance > 320) {
            enemy.position = move(
              enemy.position,
              hero.position,
              enemy.speed * dt,
            );
          } else if (enemy.cooldown <= 0) {
            _attackHero(enemy);
          }
        } else {
          enemy.position = move(
            enemy.position,
            nest.position,
            enemy.speed * dt,
          );
        }
        continue;
      }
      if (enemy.campId != null) {
        final camp = camps.firstWhere((c) => c.id == enemy.campId);
        if (!camp.discovered) continue;
        if (hero.alive &&
            heroDistance < 500 &&
            (hero.position - camp.position).distance < 650) {
          final range = enemy.attack == EnemyAttack.gun ? 270.0 : 360.0;
          if (heroDistance > range) {
            enemy.position = move(
              enemy.position,
              hero.position,
              enemy.speed * dt,
            );
          } else if (enemy.cooldown <= 0) {
            _attackHero(enemy);
          }
        } else {
          enemy.position = move(
            enemy.position,
            camp.position,
            enemy.speed * dt,
          );
        }
        continue;
      }
      if (hero.alive && heroDistance < 250) {
        if (enemy.cooldown <= 0) _attackHero(enemy);
        continue;
      }
      DefenseVein? target;
      var nearest = 440.0;
      for (final site in veins.where(
        (v) => v.lane == enemy.lane && v.bot != null && isDocked(v),
      )) {
        final d = (site.position - enemy.position).distance;
        if (d < nearest) {
          nearest = d;
          target = site;
        }
      }
      if (target != null) {
        if (nearest > 230) {
          enemy.position = move(
            enemy.position,
            target.position,
            enemy.speed * dt,
          );
        } else if (enemy.cooldown <= 0) {
          target.bot!.hp -= 8;
          enemy.cooldown = 1.1;
          traces.add(CombatTrace(enemy.position, target.position, false));
        }
      } else if ((enemy.position - home).distance < 155) {
        if (enemy.cooldown <= 0) {
          baseDamage += 10;
          enemy.cooldown = 1.2;
          traces.add(CombatTrace(enemy.position, home, false));
        }
      } else {
        final route = paths[enemy.lane!];
        while (enemy.waypoint < route.length - 1 &&
            (enemy.position - route[enemy.waypoint]).distance < 12) {
          enemy.waypoint++;
        }
        enemy.position = move(
          enemy.position,
          route[enemy.waypoint],
          enemy.speed * dt,
        );
      }
    }
    for (final hazard in hazards) {
      hazard.remaining -= dt;
      if (hazard.impacted) continue;
      if (hazard.kind == HazardKind.rolling) {
        hazard.position += hazard.velocity * dt;
        if ((hazard.position - hero.position).distance < 28 ||
            hazard.remaining <= 0) {
          if ((hazard.position - hero.position).distance < hazard.radius) {
            _hurtHero(hazard.damage);
          }
          hazard.impacted = true;
          hazard.remaining = .25;
        }
      } else if (hazard.remaining <= 0) {
        if (hazard.kind == HazardKind.gun) {
          final source = enemies.where(
            (e) => e.id == hazard.source && e.hp > 0,
          );
          if (source.isNotEmpty &&
              (source.first.position - hero.position).distance <= 300) {
            _hurtHero(hazard.damage);
            traces.add(
              CombatTrace(source.first.position, hero.position, false),
            );
          }
        } else if (hazard.kind == HazardKind.blast) {
          if ((hero.position - hazard.target).distance < hazard.radius) {
            _hurtHero(hazard.damage);
          }
        } else if (segmentDistance(hero.position, hazard.from, hazard.target) <
            hazard.radius) {
          _hurtHero(hazard.damage);
        }
        hazard.impacted = true;
        hazard.remaining = .28;
      }
    }
    hazards.removeWhere((h) => h.remaining <= 0);
    final defeated = enemies.where((e) => e.hp <= 0).toList();
    for (final enemy in defeated) {
      income += enemy.boss
          ? 90
          : enemy.campId != null || enemy.neutralId != null
          ? 16
          : 8;
      if ((enemy.position - hero.position).distance < 500) {
        hero.xp += enemy.boss ? 60 : 12;
      }
    }
    enemies.removeWhere((e) => e.hp <= 0);
    for (final nest in jungle) {
      if (nest.ids.every((id) => !enemies.any((e) => e.id == id))) {
        nest.respawn -= dt;
        if (nest.respawn <= 0) _spawnJungle(nest);
      }
    }
    while (hero.xp >= hero.level * 70) {
      hero.xp -= hero.level * 70;
      hero.level++;
      hero.maxHp += 18;
      hero.hp = math.min(hero.maxHp, hero.hp + 45);
    }
    return (income: income, baseDamage: baseDamage);
  }
}
