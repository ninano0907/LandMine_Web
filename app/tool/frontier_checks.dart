import 'dart:ui';
import 'package:mine_path/frontier/defense.dart';
import 'package:mine_path/frontier/simulation.dart';

void verify(bool value, String message) {
  if (!value) throw StateError(message);
}

void advance(FrontierGame game, double seconds) {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    game.tick(.05);
  }
}

void advanceBattle(DefenseWorld world, double seconds) {
  for (var i = 0; i < (seconds * 20).round(); i++) {
    world.tick(.05);
  }
}

final frontierChecks = <String, void Function()>{
  '7 oclock home, 1 oclock enemy and three connected lanes': () {
    verify(
      DefenseWorld.home.dx < 1800 && DefenseWorld.home.dy > 1200,
      'Home must be southwest',
    );
    verify(
      DefenseWorld.enemyHome.dx > 1800 && DefenseWorld.enemyHome.dy < 1200,
      'Enemy must be northeast',
    );
    final world = DefenseWorld(seed: 1);
    verify(world.veins.length == 9, 'Three veins in each of three lanes');
    for (final path in DefenseWorld.paths) {
      verify(
        path.first == DefenseWorld.enemyHome && path.last == DefenseWorld.home,
        'Lane endpoints',
      );
    }
  },
  '12 candidates, scheduled persistent camps and progressive guards': () {
    final world = DefenseWorld(seed: 7);
    verify(
      DefenseWorld.campCandidates.toSet().length == 12,
      '12 unique positions',
    );
    world.updateCampSpawns(2);
    verify(world.camps.isEmpty, 'No early spawn');
    world.updateCampSpawns(3);
    verify(world.camps.length == 1, 'Wave 3 spawn');
    final first = world.camps.first;
    final position = first.position;
    verify(
      first.candidate < 4 && world.guardsLeft(first) == 4,
      'Near camp: boss and three minions',
    );
    world.updateCampSpawns(6);
    verify(world.camps.length == 2, 'Wave 6 spawn');
    verify(
      world.camps.first.position == position && !first.rescued,
      'Old camp must persist',
    );
    world.updateCampSpawns(9);
    world.updateCampSpawns(9);
    verify(
      world.camps.length == 3 &&
          world.camps.map((c) => c.candidate).toSet().length == 3,
      'No duplicate spawn',
    );
    verify(
      world.guardsLeft(world.camps[1]) == 5 &&
          world.guardsLeft(world.camps[2]) == 5,
      'Later camps have four minions',
    );
    final bosses = world.enemies.where((e) => e.boss).toList();
    verify(
      bosses[0].hp < bosses[1].hp && bosses[1].hp < bosses[2].hp,
      'Boss strength increases',
    );
    final variants = {
      for (var seed = 0; seed < 20; seed++)
        (DefenseWorld(seed: seed)..updateCampSpawns(3)).camps.first.candidate,
    };
    verify(variants.length > 1, 'Different seeds change location');
  },
  'manual fire, no automatic hero fire and roll movement/cooldown': () {
    final world = DefenseWorld(seed: 1);
    world.hero.position = const Offset(1600, 1200);
    final enemy = FieldEnemy(
      id: 800,
      position: const Offset(1800, 1200),
      attack: EnemyAttack.gun,
      maxHp: 100,
      lane: 1,
    )..cooldown = 100;
    world.enemies.add(enemy);
    advanceBattle(world, .4);
    verify(enemy.hp == 100, 'Hero must not shoot without input');
    verify(world.fire() && enemy.hp == 76, 'Attack button deals damage');
    verify(!world.fire(), 'Attack cooldown');
    world.hero.input = const Offset(1, 0);
    final from = world.hero.position;
    verify(world.roll() && !world.roll(), 'Roll has cooldown');
    advanceBattle(world, .25);
    verify(
      (world.hero.position - from).distance > 150,
      'Roll provides fast movement',
    );
  },
  'bomb landing point stays fixed and walking out prevents damage': () {
    final world = DefenseWorld(seed: 1);
    world.hero.position = const Offset(1600, 1200);
    world.enemies.add(
      FieldEnemy(
        id: 500,
        position: const Offset(1800, 1200),
        attack: EnemyAttack.throwBomb,
        maxHp: 100,
        lane: 1,
      )..cooldown = 0,
    );
    world.tick(.05);
    final hazard = world.hazards.single;
    final landing = hazard.target;
    verify(hazard.kind == HazardKind.blast, 'Thrower uses marked blast');
    world.moveHero(const Offset(0, 1));
    advanceBattle(world, 1.3);
    verify(hazard.target == landing, 'Landing marker must not follow hero');
    verify(
      world.hero.hp == world.hero.maxHp,
      'Escaping the marker prevents damage',
    );
  },
  'rolling bombs can be sidestepped and instantaneous guns respect roll': () {
    final world = DefenseWorld(seed: 1);
    world.hero.position = const Offset(1600, 1200);
    world.hazards.add(
      Hazard(
        HazardKind.rolling,
        const Offset(1450, 1200),
        world.hero.position,
        3.4,
        30,
        velocity: const Offset(135, 0),
      ),
    );
    world.moveHero(const Offset(0, 1));
    advanceBattle(world, 1.5);
    verify(world.hero.hp == world.hero.maxHp, 'Sidestep slow bomb');
    world.hero.input = Offset.zero;
    final enemy = FieldEnemy(
      id: 77,
      position: world.hero.position + const Offset(200, 0),
      attack: EnemyAttack.gun,
      maxHp: 100,
      lane: 1,
    )..cooldown = 10;
    world.enemies.add(enemy);
    world.hazards.add(
      Hazard(
        HazardKind.gun,
        enemy.position,
        world.hero.position,
        .1,
        7,
        source: 77,
      ),
    );
    world.hero.facing = const Offset(0, -1);
    verify(world.roll(), 'Roll available');
    advanceBattle(world, .15);
    verify(
      world.hero.hp == world.hero.maxHp,
      'Correctly timed roll avoids instant shot',
    );
    advanceBattle(world, .3);
    world.hazards.add(
      Hazard(
        HazardKind.gun,
        enemy.position,
        world.hero.position,
        .05,
        7,
        source: 77,
      ),
    );
    advanceBattle(world, .05);
    verify(
      world.hero.hp < world.hero.maxHp,
      'Gun hits in-range hero after roll ends',
    );
  },
  'rescue requires cleared guards and allows exactly one commander per lane':
      () {
        final world = DefenseWorld(seed: 2)..updateCampSpawns(9);
        for (var i = 0; i < 3; i++) {
          final camp = world.camps[i];
          world.hero.position = camp.position;
          camp.discovered = true;
          verify(world.rescue() == null, 'Cannot rescue through living guards');
          for (final e in world.enemies.where((e) => e.campId == camp.id)) {
            e.hp = 0;
          }
          world.tick(.05);
          final unit = world.rescue();
          verify(unit != null && camp.rescued, 'Cleared camp grants companion');
          verify(world.rescue() == null, 'No duplicate companion');
          verify(world.assign(unit!, i), 'Assign to chosen lane');
          if (i > 0) {
            unit.transferCooldown = 0;
            for (final other in world.companions) {
              other.transferCooldown = 0;
            }
            verify(world.assign(unit, 0), 'Can swap occupied lines');
            verify(
              world.companions.where((c) => c.lane == 0).length == 1,
              'Swapping never stacks commanders',
            );
          }
        }
        verify(world.companions.length == 3, 'All three companions retained');
      },
  'bot travels before mining; exhausted veins retain defense': () {
    final game = FrontierGame(seed: 3);
    game.waveIn = 10000;
    final site = game.defense.veins[3];
    final gold = game.gold;
    verify(
      game.deployBot(site) && game.gold == gold - 140,
      'Deployment charges once',
    );
    verify(!game.deployBot(site), 'Cannot double deploy');
    final remaining = site.ore;
    advance(game, .5);
    verify(site.ore == remaining, 'No mining in transit');
    advance(game, 5);
    verify(
      game.defense.isDocked(site) && site.ore < remaining,
      'Mines after docking',
    );
    site.ore = 0;
    final unit = FieldEnemy(
      id: 700,
      position: site.position + const Offset(100, 0),
      attack: EnemyAttack.gun,
      maxHp: 20,
      lane: site.lane,
    )..cooldown = 100;
    game.defense.enemies.add(unit);
    advance(game, 1);
    verify(site.bot != null && unit.hp <= 0, 'Depleted mine still defends');
    site.bot!.hp = 0;
    advance(game, .05);
    verify(site.bot == null, 'Destroyed bot clears slot');
    game.gold = 500;
    verify(game.deployBot(site), 'Can replace destroyed defense');
  },
  'pause, hero respawn and terminal state stop invalid actions': () {
    final game = FrontierGame(seed: 4)..paused = true;
    advance(game, 2);
    verify(game.elapsed == 0, 'Pause freezes game');
    verify(
      !game.deployBot(game.defense.veins.first),
      'Cannot build while paused',
    );
    game.paused = false;
    game.defense.hero.hp = 0;
    game.defense.hero.respawn = .1;
    advance(game, .2);
    verify(game.defense.hero.alive, 'Hero respawns');
    game.wave = FrontierGame.finalWave;
    game.defense.enemies.clear();
    advance(game, .05);
    verify(game.won, 'Final wave clearance wins');
    final gold = game.gold;
    advance(game, 2);
    verify(game.gold == gold && !game.hire(), 'Terminal state freezes economy');
    final loss = FrontierGame(seed: 4)..hull = 0;
    advance(loss, .05);
    verify(loss.lost, 'Home destruction loses');
  },
  'full defense is winnable without mandatory companion RNG': () {
    final game = FrontierGame(seed: 9);
    for (final index in [0, 3, 6]) {
      verify(
        game.deployBot(game.defense.veins[index]),
        'Start with three chosen defenses',
      );
    }
    for (var i = 0; i < 14000 && !game.finished; i++) {
      for (final index in [0, 3, 6]) {
        final site = game.defense.veins[index];
        if (site.bot == null) {
          game.deployBot(site);
        } else if (site.bot!.level < 4 &&
            game.gold > game.botUpgradeCost(site) + 60) {
          game.upgradeDefenseBot(site);
        }
      }
      if (game.hull < 850) game.repair();
      if (game.gold > game.upgradeCost + 100) game.upgrade();
      game.tick(.05);
    }
    verify(
      game.won,
      'Defense should be viable with sensible investment (${game.wave} waves, hull ${game.hull}, enemies ${game.defense.enemies.length})',
    );
    verify(
      game.defense.camps.length == 3,
      'All three scheduled camps exist by victory',
    );
  },
};
