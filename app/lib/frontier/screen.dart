import 'dart:async';
import 'dart:ui' as ui;
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'defense.dart';
import 'painter.dart';
import 'robot_studio.dart';
import 'simulation.dart';

class FrontierScreen extends StatefulWidget {
  const FrontierScreen({super.key, this.initialGame});
  final FrontierGame? initialGame;
  @override
  State<FrontierScreen> createState() => _FrontierScreenState();
}

class _FrontierScreenState extends State<FrontierScreen>
    with WidgetsBindingObserver {
  late FrontierGame game;
  late final Timer timer;
  final watch = Stopwatch()..start();
  final keys = <LogicalKeyboardKey>{};
  final focus = FocusNode();
  double lastTime = 0, zoom = 1;
  Offset camera = Offset.zero;
  Size viewport = Size.zero;
  String follow = 'hero';
  bool get active => !game.paused && !game.finished;
  @override
  void initState() {
    super.initState();
    game = widget.initialGame ?? FrontierGame();
    WidgetsBinding.instance.addObserver(this);
    // Load the same 8x8 walk atlas once for all temporary RTS actors.
    rootBundle.load('assets/units/1900/engineer_walk_empty.png').then((data) async {
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      try {
        final frame = await codec.getNextFrame();
        if (!mounted) {
          frame.image.dispose();
          return;
        }
        FrontierPainter.testMinerSprite = frame.image;
        setState(() {});
      } finally {
        codec.dispose();
      }
    }).catchError((Object error) {
      debugPrint('Test miner sprite load: $error');
    });
    timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = watch.elapsedMicroseconds / 1000000;
      final dt = now - lastTime;
      lastTime = now;
      if (mounted) setState(() => game.tick(dt));
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    timer.cancel();
    watch.stop();
    focus.dispose();
    super.dispose();
  }

  void clearInputs() {
    keys.clear();
    game.defense.moveHero(Offset.zero);
    game.defense.hero.firing = false;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      // A WebView swipe-to-dismiss can briefly change lifecycle state.
      // Release pressed controls, but do not pause the game.
      // Keep the preview active when an embedded WebView briefly loses focus.
      clearInputs();
    }
  }

  Offset bound(Offset at) => Offset(
    at.dx.clamp(0, math.max(0, 3600 - viewport.width)).toDouble(),
    at.dy.clamp(0, math.max(0, 2400 - viewport.height)).toDouble(),
  );
  void centerOn(Offset at) {
    camera = bound(at - Offset(viewport.width * .5, viewport.height * .53));
  }

  KeyEventResult keyEvent(FocusNode node, KeyEvent event) {
    final key = event.logicalKey;
    const handled = [
      LogicalKeyboardKey.keyW,
      LogicalKeyboardKey.keyA,
      LogicalKeyboardKey.keyS,
      LogicalKeyboardKey.keyD,
      LogicalKeyboardKey.arrowUp,
      LogicalKeyboardKey.arrowDown,
      LogicalKeyboardKey.arrowLeft,
      LogicalKeyboardKey.arrowRight,
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyJ,
      LogicalKeyboardKey.shiftLeft,
      LogicalKeyboardKey.shiftRight,
      LogicalKeyboardKey.keyK,
      LogicalKeyboardKey.keyE,
    ];
    if (!handled.contains(key)) return KeyEventResult.ignored;
    if (event is KeyUpEvent) {
      keys.remove(key);
    } else {
      keys.add(key);
    }
    if (!active) {
      clearInputs();
      return KeyEventResult.handled;
    }
    bool down(LogicalKeyboardKey a, LogicalKeyboardKey b) =>
        keys.contains(a) || keys.contains(b);
    game.defense.moveHero(
      Offset(
        (down(LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight) ? 1 : 0) -
            (down(LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft)
                    ? 1
                    : 0)
                .toDouble(),
        (down(LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown) ? 1 : 0) -
            (down(LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp) ? 1 : 0)
                .toDouble(),
      ),
    );
    game.defense.hero.firing = down(
      LogicalKeyboardKey.space,
      LogicalKeyboardKey.keyJ,
    );
    if (event is KeyDownEvent) {
      if ([
        LogicalKeyboardKey.shiftLeft,
        LogicalKeyboardKey.shiftRight,
        LogicalKeyboardKey.keyK,
      ].contains(key)) {
        game.defense.roll();
      }
      if (key == LogicalKeyboardKey.keyE) rescue();
    }
    follow = 'hero';
    return KeyEventResult.handled;
  }

  void mapTap(Offset local) {
    if (!active) return;
    focus.requestFocus();
    final world = local / zoom + camera;
    final site = game.defense.veinAt(world);
    if (site != null) {
      siteSheet(site);
      return;
    }
    setState(() {
      game.defense.walkTo(world);
      follow = 'hero';
    });
  }

  void openSheet(Widget child) {
    clearInputs();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: const Color(0xfff7e8c8),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .86,
      ),
      builder: (_) => SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
            child: child,
          ),
        ),
      ),
    );
  }

  void siteSheet(DefenseVein site) {
    final bot = site.bot;
    openSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${DefenseWorld.laneNames[site.lane]} · ${site.depth + 1}번 광맥',
            style: const TextStyle(
              fontSize: 21,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          Text(
            '잔여 금 ${site.ore.floor()} G · 고갈 후에도 봇은 방어합니다.',
            style: const TextStyle(color: ink),
          ),
          const SizedBox(height: 14),
          if (bot == null)
            FilledButton.icon(
              key: const ValueKey('deploy-bot'),
              onPressed:
                  active &&
                      game.gold >= DefenseWorld.botCost &&
                      game.defense.botCount < DefenseWorld.maxBots
                  ? () {
                      setState(() => game.deployBot(site));
                      Navigator.pop(context);
                    }
                  : null,
              icon: const Icon(Icons.precision_manufacturing),
              label: const Text('채굴 방어 봇 배치 · 140 G'),
            ),
          if (bot != null) ...[
            Text(
              'Lv.${bot.level} · 내구도 ${bot.hp.ceil()}/${bot.maxHp.floor()}',
              style: const TextStyle(color: ink),
            ),
            FilledButton.icon(
              onPressed:
                  active &&
                      bot.level < 4 &&
                      game.gold >= game.botUpgradeCost(site)
                  ? () {
                      setState(() => game.upgradeDefenseBot(site));
                      Navigator.pop(context);
                    }
                  : null,
              icon: const Icon(Icons.upgrade),
              label: Text('봇 강화 · ${game.botUpgradeCost(site)} G'),
            ),
            TextButton(
              onPressed: active
                  ? () {
                      setState(() => game.recallBot(site));
                      Navigator.pop(context);
                    }
                  : null,
              child: const Text('봇 회수 · 40 G 반환'),
            ),
          ],
        ],
      ),
    );
  }

  void showVeins() {
    openSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '광맥에 채굴 방어 봇 배치',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          Text(
            '140 G · 최대 ${DefenseWorld.maxBots}대 · 광맥을 직접 탭해도 됩니다',
            style: const TextStyle(color: ink, fontSize: 12),
          ),
          for (var lane = 0; lane < 3; lane++) ...[
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                DefenseWorld.laneNames[lane],
                style: const TextStyle(fontWeight: FontWeight.w900, color: ink),
              ),
            ),
            for (final site in game.defense.veins.where((v) => v.lane == lane))
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  site.bot == null
                      ? Icons.add_location_alt_outlined
                      : Icons.precision_manufacturing,
                  color: const Color(0xff9b753a),
                ),
                title: Text(
                  '${DefenseWorld.laneNames[lane]} ${site.depth + 1}번 광맥',
                ),
                subtitle: Text(
                  site.bot == null
                      ? '${site.ore.floor()} G · 배치 가능'
                      : 'Lv.${site.bot!.level} · ${game.defense.isDocked(site) ? '채굴 / 방어 중' : '이동 중'}',
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(context);
                  siteSheet(site);
                },
              ),
          ],
        ],
      ),
    );
  }

  void rescue() {
    if (!active) return;
    final unit = game.defense.rescue();
    if (unit != null) {
      setState(() {});
      showCompanions();
    }
  }

  void showCompanions() {
    openSheet(
      Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '구출 동료 · 라인 지휘관',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: ink,
            ),
          ),
          const Text(
            '3·6·9차 습격에 구조 캠프 등장 · 라인당 동료 1명',
            style: TextStyle(color: ink, fontSize: 12),
          ),
          if (game.defense.companions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 22),
              child: Text(
                '정글의 구조 신호를 찾아 경비대장과 졸개를 처치하세요.\n동료 가까이에서 구출 버튼을 누르면 합류합니다.',
                style: TextStyle(color: ink),
              ),
            ),
          for (final unit in game.defense.companions) ...[
            const SizedBox(height: 16),
            Text(
              unit.name,
              style: const TextStyle(color: ink, fontWeight: FontWeight.w900),
            ),
            Text(
              unit.lane == null
                  ? '배치 대기'
                  : '현재 ${DefenseWorld.laneNames[unit.lane!]}',
              style: const TextStyle(color: ink),
            ),
            Wrap(
              spacing: 8,
              children: [
                for (var lane = 0; lane < 3; lane++)
                  FilledButton.tonal(
                    onPressed:
                        active &&
                            unit.transferCooldown <= 0 &&
                            unit.lane != lane &&
                            !game.defense.companions.any(
                              (c) =>
                                  c != unit &&
                                  c.lane == lane &&
                                  c.transferCooldown > 0,
                            )
                        ? () {
                            setState(() => game.defense.assign(unit, lane));
                            Navigator.pop(context);
                          }
                        : null,
                    child: Text('${DefenseWorld.laneNames[lane]} 배치'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget action(
    String title,
    String detail,
    IconData icon,
    VoidCallback? onTap,
  ) => SizedBox(
    width: 130,
    height: 52,
    child: FilledButton.tonalIcon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 9),
        backgroundColor: const Color(0xff6b5741),
        foregroundColor: const Color(0xffffebc1),
        disabledBackgroundColor: const Color(0xffc9ba9a),
      ),
      onPressed: onTap,
      icon: Icon(icon, size: 19),
      label: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
          ),
          Text(
            detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 9),
          ),
        ],
      ),
    ),
  );
  @override
  Widget build(BuildContext context) => Focus(
    focusNode: focus,
    autofocus: true,
    onKeyEvent: keyEvent,
    onFocusChange: (value) {
      if (!value) clearInputs();
    },
    child: Scaffold(
      backgroundColor: const Color(0xfff3e2be),
      body: SafeArea(
        child: Column(
          children: [
            _topBar(),
            Expanded(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  zoom = (constraints.maxWidth / 1050).clamp(.28, 1.3);
                  viewport = Size(
                    constraints.maxWidth / zoom,
                    constraints.maxHeight / zoom,
                  );
                  if (follow == 'hero') {
                    centerOn(game.defense.hero.position);
                  } else if (follow == 'robot') {
                    centerOn(game.robot);
                  }
                  camera = bound(camera);
                  final hero = game.defense.hero;
                  final camp = game.defense.nearbyCamp;
                  return ClipRect(
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: GestureDetector(
                            key: const ValueKey('frontier-map'),
                            behavior: HitTestBehavior.opaque,
                            onTapUp: (d) => mapTap(d.localPosition),
                            onPanUpdate: (d) => setState(() {
                              follow = '';
                              camera = bound(camera - d.delta / zoom);
                            }),
                            child: CustomPaint(
                              painter: FrontierPainter(game, camera, zoom),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          left: 10,
                          child: IgnorePointer(
                            child: Container(
                              width: math.min(210, constraints.maxWidth - 135),
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: const Color(0xeef7e8c7),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    hero.alive
                                        ? '보안관 Lv.${hero.level}'
                                        : '복귀 ${hero.respawn.ceil()}초',
                                    style: const TextStyle(
                                      color: ink,
                                      fontWeight: FontWeight.w900,
                                      fontSize: 12,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  LinearProgressIndicator(
                                    value: hero.hp / hero.maxHp,
                                    minHeight: 5,
                                    color: const Color(0xffa39b61),
                                    backgroundColor: const Color(0xffd5c399),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    game.defense.noticeTime > 0
                                        ? game.defense.notice
                                        : '이동 스틱 · 공격 버튼 · 구르기',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      color: ink,
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 8,
                          right: 10,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              GestureDetector(
                                onTapDown: (d) => setState(() {
                                  follow = '';
                                  camera = bound(
                                    Offset(
                                      d.localPosition.dx / 104 * 3600 -
                                          viewport.width / 2,
                                      d.localPosition.dy / 68 * 2400 -
                                          viewport.height / 2,
                                    ),
                                  );
                                }),
                                child: Container(
                                  width: 104,
                                  height: 68,
                                  clipBehavior: Clip.antiAlias,
                                  decoration: BoxDecoration(
                                    border: Border.all(
                                      color: const Color(0xff8f744e),
                                      width: 2,
                                    ),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: CustomPaint(
                                    painter: FrontierMiniMap(
                                      game,
                                      camera,
                                      viewport,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  _cameraButton(
                                    '영웅',
                                    Icons.person,
                                    () => setState(() => follow = 'hero'),
                                  ),
                                  _cameraButton(
                                    '본부',
                                    Icons.home,
                                    () => setState(() => follow = 'robot'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Positioned(
                          left: 14,
                          bottom: 12,
                          child: _MoveStick(
                            enabled: active && hero.alive,
                            onChange: (direction) {
                              if (active) {
                                game.defense.moveHero(direction);
                                follow = 'hero';
                              }
                            },
                          ),
                        ),
                        Positioned(
                          right: 14,
                          bottom: 12,
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              _roundButton(
                                '구르기',
                                hero.rollCooldown > 0
                                    ? '${hero.rollCooldown.toStringAsFixed(1)}초'
                                    : 'Shift / K',
                                Icons.double_arrow,
                                active && hero.alive && hero.rollCooldown <= 0
                                    ? () => setState(() => game.defense.roll())
                                    : null,
                                size: 54,
                              ),
                              const SizedBox(width: 10),
                              Listener(
                                behavior: HitTestBehavior.opaque,
                                onPointerDown: (_) {
                                  if (active) {
                                    game.defense.hero.firing = true;
                                    game.defense.fire();
                                    focus.requestFocus();
                                  }
                                },
                                onPointerUp: (_) =>
                                    game.defense.hero.firing = false,
                                onPointerCancel: (_) =>
                                    game.defense.hero.firing = false,
                                child: Semantics(
                                  button: true,
                                  label: '공격 · 누르고 있으면 연속 사격',
                                  child: _roundButton(
                                    '공격',
                                    'Space / J',
                                    Icons.gps_fixed,
                                    active && hero.alive ? () {} : null,
                                    size: 70,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (camp != null && !camp.rescued)
                          Positioned(
                            bottom: 16,
                            left: constraints.maxWidth / 2 - 65,
                            child: SizedBox(
                              width: 130,
                              height: 42,
                              child: FilledButton.icon(
                                onPressed:
                                    active && game.defense.guardsLeft(camp) == 0
                                    ? rescue
                                    : null,
                                icon: const Icon(Icons.lock_open, size: 16),
                                label: Text(
                                  game.defense.guardsLeft(camp) == 0
                                      ? '동료 구출 · E'
                                      : '경비 ${game.defense.guardsLeft(camp)}명',
                                  style: const TextStyle(fontSize: 11),
                                ),
                              ),
                            ),
                          ),
                        if (game.paused && !game.finished)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0x774c3b28),
                              child: Center(
                                child: FilledButton.icon(
                                  onPressed: () =>
                                      setState(() => game.paused = false),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('계속하기'),
                                ),
                              ),
                            ),
                          ),
                        if (game.finished)
                          Positioned.fill(
                            child: ColoredBox(
                              color: const Color(0xaa443322),
                              child: Center(
                                child: Container(
                                  margin: const EdgeInsets.all(18),
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: const Color(0xfff6e6c5),
                                    borderRadius: BorderRadius.circular(18),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        game.won
                                            ? '${FrontierGame.finalWave}차 습격 방어 성공!'
                                            : '본부가 파괴됐습니다',
                                        style: const TextStyle(
                                          fontSize: 21,
                                          fontWeight: FontWeight.w900,
                                          color: ink,
                                        ),
                                      ),
                                      const SizedBox(height: 7),
                                      Text(
                                        '동료 ${game.defense.companions.length}명 구출 · 채굴 ${game.extracted.floor()} G',
                                        style: const TextStyle(
                                          color: ink,
                                          fontSize: 12,
                                        ),
                                      ),
                                      const SizedBox(height: 12),
                                      FilledButton(
                                        onPressed: () => setState(() {
                                          clearInputs();
                                          game = FrontierGame();
                                          follow = 'hero';
                                        }),
                                        child: const Text('새 원정 시작'),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            _bottomBar(),
          ],
        ),
      ),
    ),
  );
  Widget _cameraButton(String label, IconData icon, VoidCallback tap) =>
      SizedBox(
        height: 32,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 5),
            minimumSize: const Size(50, 32),
            backgroundColor: const Color(0xccf7e7bf),
            foregroundColor: ink,
          ),
          onPressed: tap,
          icon: Icon(icon, size: 13),
          label: Text(label, style: const TextStyle(fontSize: 10)),
        ),
      );
  Widget _roundButton(
    String title,
    String hint,
    IconData icon,
    VoidCallback? tap, {
    required double size,
  }) => SizedBox(
    width: size,
    height: size,
    child: FilledButton(
      style: FilledButton.styleFrom(
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
        backgroundColor: const Color(0xff83613b),
        foregroundColor: const Color(0xffffedc1),
        disabledBackgroundColor: const Color(0xaa9b8c70),
      ),
      onPressed: tap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: size * .3),
          Text(
            title,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w900),
          ),
          Text(hint, style: const TextStyle(fontSize: 7)),
        ],
      ),
    ),
  );
  Widget _topBar() => Container(
    padding: const EdgeInsets.only(left: 12, right: 4),
    height: 45,
    decoration: const BoxDecoration(
      color: Color(0xff4c4032),
      border: Border(bottom: BorderSide(color: Color(0xffd6b772), width: 2)),
    ),
    child: Row(
      children: [
        const Icon(Icons.settings, size: 22, color: Color(0xffdfbd78)),
        const SizedBox(width: 7),
        const Text(
          '황금의 철마',
          style: TextStyle(
            color: Color(0xffffebc1),
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const Spacer(),
        Flexible(
          child: Text(
            'G ${game.gold.floor()}',
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xffffd67a),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${game.wave}/${FrontierGame.finalWave}차 습격\n${game.wave >= FrontierGame.finalWave ? '최종 방어' : '${game.waveIn.ceil()}초 후'}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xfff0dfb7), fontSize: 9),
        ),
        IconButton(
          tooltip: '일시정지',
          onPressed: game.finished
              ? null
              : () => setState(() {
                  clearInputs();
                  game.paused = !game.paused;
                }),
          icon: Icon(
            game.paused ? Icons.play_arrow : Icons.pause,
            color: const Color(0xffffedc6),
          ),
        ),
      ],
    ),
  );
  Widget _bottomBar() => Container(
    padding: const EdgeInsets.fromLTRB(10, 5, 10, 7),
    decoration: const BoxDecoration(
      color: Color(0xfff3e2be),
      border: Border(top: BorderSide(color: Color(0xffc0a174), width: 2)),
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            SizedBox(
              width: 95,
              child: Text(
                '본부 ${game.hull.ceil()}\n봇 ${game.defense.botCount}/${DefenseWorld.maxBots}',
                style: const TextStyle(
                  color: ink,
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            for (var lane = 0; lane < 3; lane++)
              Expanded(
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 3),
                    minimumSize: const Size(0, 30),
                    foregroundColor: ink,
                  ),
                  onPressed: () {
                    final botSites =
                        game.defense.veins
                            .where((v) => v.lane == lane && v.bot != null)
                            .toList()
                          ..sort((a, b) => b.depth.compareTo(a.depth));
                    setState(() {
                      follow = '';
                      centerOn(
                        botSites.isEmpty
                            ? DefenseWorld.veinPositions[lane].first
                            : botSites.first.position,
                      );
                    });
                  },
                  child: Text(
                    '${DefenseWorld.laneNames[lane]} ${game.defense.veins.where((v) => v.lane == lane && v.bot != null).length}/3',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color:
                          game.defense.veins.any(
                            (v) =>
                                v.lane == lane &&
                                v.bot != null &&
                                v.bot!.hp < v.bot!.maxHp * .4,
                          )
                          ? const Color(0xffb54831)
                          : ink,
                    ),
                  ),
                ),
              ),
          ],
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              action(
                '방어 봇 배치',
                '140 G · 광맥 선택',
                Icons.precision_manufacturing,
                active ? showVeins : null,
              ),
              const SizedBox(width: 6),
              action(
                '구출 동료',
                '${game.defense.companions.length}/3명 · 라인 배치',
                Icons.groups_outlined,
                active ? showCompanions : null,
              ),
              const SizedBox(width: 6),
              action(
                '전체 화력 Lv.${game.weaponLevel}',
                game.weaponLevel >= 5 ? '최대 강화' : '${game.upgradeCost} G',
                Icons.bolt,
                active && game.gold >= game.upgradeCost && game.weaponLevel < 5
                    ? () => setState(() => game.upgrade())
                    : null,
              ),
              const SizedBox(width: 6),
              action(
                '본부 수리',
                game.repairCooldown > 0
                    ? '${game.repairCooldown.ceil()}초 후'
                    : '60 G · +300',
                Icons.handyman_outlined,
                active &&
                        game.gold >= 60 &&
                        game.repairCooldown == 0 &&
                        game.hull < 1200
                    ? () => setState(() => game.repair())
                    : null,
              ),
              const SizedBox(width: 6),
              action('로봇 동작', '대기 / 보행 / 채굴', Icons.view_in_ar, () {
                clearInputs();
                setState(() => game.paused = true);
                Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const RobotStudio()),
                );
              }),
            ],
          ),
        ),
      ],
    ),
  );
}

class _MoveStick extends StatefulWidget {
  const _MoveStick({required this.enabled, required this.onChange});
  final bool enabled;
  final ValueChanged<Offset> onChange;
  @override
  State<_MoveStick> createState() => _MoveStickState();
}

class _MoveStickState extends State<_MoveStick> {
  Offset value = Offset.zero;
  int? pointer;
  void update(Offset local) {
    final delta = local - const Offset(44, 44);
    final next = delta.distance > 31 ? delta / delta.distance * 31 : delta;
    setState(() => value = next);
    widget.onChange(next / 31);
  }

  void end() {
    pointer = null;
    setState(() => value = Offset.zero);
    widget.onChange(Offset.zero);
  }

  @override
  void didUpdateWidget(covariant _MoveStick oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) {
      pointer = null;
      value = Offset.zero;
    }
  }

  @override
  Widget build(BuildContext context) => Listener(
    key: const ValueKey('hero-stick'),
    behavior: HitTestBehavior.opaque,
    onPointerDown: (e) {
      if (widget.enabled && pointer == null) {
        pointer = e.pointer;
        update(e.localPosition);
      }
    },
    onPointerMove: (e) {
      if (widget.enabled && pointer == e.pointer) update(e.localPosition);
    },
    onPointerUp: (e) {
      if (pointer == e.pointer) end();
    },
    onPointerCancel: (e) {
      if (pointer == e.pointer) end();
    },
    child: SizedBox(
      width: 88,
      height: 88,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: const Color(0x77836b4b),
          border: Border.all(color: const Color(0x99fff0bd), width: 2),
        ),
        child: Center(
          child: Transform.translate(
            offset: value,
            child: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.enabled
                    ? const Color(0xccf5d99b)
                    : const Color(0x66b9ab8d),
                border: Border.all(color: const Color(0xffb08d55)),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x446c5134),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
