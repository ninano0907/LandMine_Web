import 'dart:math';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'content.dart';
import 'simulation.dart';
import 'mining_world.dart';
import 'hud_widgets.dart';

String money(num value) =>
    '${value < 0 ? '-' : ''}\$${value.abs().toStringAsFixed(0)}';

class MiningScreen extends StatefulWidget {
  const MiningScreen({super.key});
  @override
  State<MiningScreen> createState() => _MiningScreenState();
}

class _MiningScreenState extends State<MiningScreen>
    with WidgetsBindingObserver {
  late MiningGame game;
  late MiningWorld scene;
  int stageIndex = 0, unlocked = 0, speed = 1;
  int? selected;
  String tool = 'inspect', mineralId = 'gold', townSection = 'workshop';
  Upgrade? openUpgrade;
  bool townOpen = false,
      townPreviousPause = false,
      resultShown = false,
      sound = true;
  final Map<int, Offset> _touches = {};
  Offset? _lastFocal;
  double _lastSpan = 0;
  void _rememberPinch() {
    final points = _touches.values.take(2).toList();
    _lastFocal = (points[0] + points[1]) / 2;
    _lastSpan = (points[0] - points[1]).distance;
  }

  void _pointerDown(PointerDownEvent event) {
    if (event.kind == PointerDeviceKind.mouse &&
        (event.buttons == kSecondaryMouseButton ||
            event.buttons == kMiddleMouseButton ||
            HardwareKeyboard.instance.logicalKeysPressed.contains(
              LogicalKeyboardKey.space,
            ))) {
      scene.cameraGestureActive = true;
      scene.dragNode = null;
      scene.trackPreview = null;
    }
    _touches[event.pointer] = event.localPosition;
    if (_touches.length >= 2) {
      scene.cameraGestureActive = true;
      scene.dragNode = null;
      scene.trackPreview = null;
      _rememberPinch();
    }
  }

  void _pointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    final previous = _lastFocal, span = _lastSpan;
    _touches[event.pointer] = event.localPosition;
    if (_touches.length < 2) {
      if (event.kind == PointerDeviceKind.mouse && scene.cameraGestureActive) {
        scene.moveCamera(
          Vector2(-event.delta.dx, -event.delta.dy) /
              scene.camera.viewfinder.zoom,
        );
        setState(() {});
      }
      return;
    }
    _rememberPinch();
    if (previous != null && span > 1) {
      scene.transformCamera(
        Vector2(previous.dx, previous.dy),
        Vector2(_lastFocal!.dx, _lastFocal!.dy),
        _lastSpan / span,
      );
    }
  }

  void _pointerUp(PointerEvent event) {
    _touches.remove(event.pointer);
    if (_touches.length >= 2) {
      _rememberPinch();
      return;
    }
    _lastFocal = null;
    _lastSpan = 0;
    if (_touches.isEmpty) {
      final oldScene = scene;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && identical(scene, oldScene) && _touches.isEmpty) {
          scene.cameraGestureActive = false;
        }
      });
    }
  }

  bool _changeWorkers(Deposit d, bool increase) {
    var changed = false;
    setState(
      () => changed = increase
          ? game.assignWorker(d.id)
          : game.removeWorker(d.id),
    );
    return changed;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    startStage(0, rebuild: false);
  }

  void startStage(int index, {bool rebuild = true}) {
    void reset() {
      _touches.clear();
      _lastFocal = null;
      _lastSpan = 0;
      stageIndex = index;
      selected = null;
      openUpgrade = null;
      resultShown = false;
      townOpen = false;
      tool = 'inspect';
      speed = 1;
      game = MiningGame(stage: stages[index]);
      mineralId = game.episode.minerals.first.id;
      scene = MiningWorld(
        simulation: game,
        onFactorySelected: showFactory,
        onChanged: () {
          if (!mounted) return;
          setState(() {});
          if (game.finished && !resultShown) showResult();
        },
        onSelected: (id) {
          if (mounted) setState(() => selected = id);
        },
      );
    }

    if (rebuild) {
      setState(reset);
    } else {
      reset();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (mounted && state != AppLifecycleState.resumed && !game.finished) {
      setState(() => game.paused = true);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void setTool(String value) => setState(() {
    tool = value;
    openUpgrade = null;
    scene.dragNode = null;
    scene.trackPreview = null;
    game.message = value == 'rail'
        ? '채굴 공장이나 파란 연결점에서 드래그해 레일을 이어주세요.'
        : value == 'dig'
        ? '지도를 누른 자리만 작게 팝니다. 한 번에 \$12가 들어요.'
        : value == 'pan'
        ? '지도를 드래그해서 이동하세요. + / −로 확대·축소할 수 있어요.'
        : '갱도를 눌러 광부를 배치하거나 회수하세요.';
  });
  void purchase(VoidCallback action) => setState(action);
  void toggleTown([String section = 'workshop']) => setState(() {
    if (!townOpen) {
      townPreviousPause = game.paused;
      game.paused = true;
      townOpen = true;
      townSection = section;
    } else {
      townOpen = false;
      game.paused = townPreviousPause;
    }
    openUpgrade = null;
  });
  void improve(Upgrade kind, {bool inTown = false}) => setState(() {
    final pause = game.paused;
    if (inTown) game.paused = false;
    game.upgrade(kind);
    game.paused = pause;
  });
  Future<T?> panel<T>(Widget Function(BuildContext) builder) async {
    final wasPaused = game.paused;
    setState(() {
      game.paused = true;
      openUpgrade = null;
    });
    final answer = await showDialog<T>(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 40, vertical: 18),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 640,
            maxHeight: MediaQuery.sizeOf(context).height - 50,
          ),
          child: PaperPanel(
            child: SingleChildScrollView(child: builder(context)),
          ),
        ),
      ),
    );
    if (mounted) setState(() => game.paused = wasPaused);
    return answer;
  }

  Future<void> showMenu() async {
    final answer = await panel<String>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '광산 관리',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: hudInk,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FrontierButton(
                '광산 마을',
                onPressed: () => Navigator.pop(context, 'town'),
              ),
              FrontierButton(
                '창고',
                onPressed: () => Navigator.pop(context, 'warehouse'),
              ),

              FrontierButton(
                '소리 ${sound ? '끄기' : '켜기'}',
                onPressed: () => Navigator.pop(context, 'sound'),
              ),
              FrontierButton(
                '작업 종료',
                onPressed: () => Navigator.pop(context, 'finish'),
              ),
              FrontierButton('계속하기', onPressed: () => Navigator.pop(context)),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (answer) {
      case 'town':
        toggleTown();
      case 'warehouse':
        showWarehouse();
      case 'sound':
        setState(() => sound = !sound);
      case 'finish':
        finish();
    }
  }

  Future<void> finish() async {
    final yes = await panel<bool>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '올해 작업을 마칠까요?',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '현재 순이익 ${money(game.profit)}\n미판매 금과 중개인 마차의 운반 중인 금은 수익에 포함되지 않습니다.',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              FrontierButton(
                '계속 작업',
                onPressed: () => Navigator.pop(context, false),
              ),
              const SizedBox(width: 12),
              FrontierButton(
                '마감하기',
                onPressed: () => Navigator.pop(context, true),
              ),
            ],
          ),
        ],
      ),
    );
    if (mounted && yes == true) {
      setState(() {
        game.paused = false;
        game.finishEarly();
      });
      showResult();
    }
  }

  Future<void> showResult() async {
    if (resultShown) return;
    resultShown = true;
    if (game.cleared) {
      unlocked = max(unlocked, min(stages.length - 1, stageIndex + 1));
    }
    final next = await panel<bool>(
      (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            game.cleared ? '목표 달성!' : '올해 작업 마감',
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              fontFamily: 'serif',
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '판매 수입  ${money(game.revenue)}\n투자 비용  ${money(game.spending)}',
            textAlign: TextAlign.center,
            style: const TextStyle(height: 1.7),
          ),
          const Divider(),
          Text(
            '순이익 ${money(game.profit)}',
            style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
          ),
          Text('목표 ${money(game.stage.targetProfit)}'),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FrontierButton(
                '다시 도전',
                onPressed: () => Navigator.pop(context, false),
              ),
              if (game.cleared && stageIndex < stages.length - 1) ...[
                const SizedBox(width: 12),
                FrontierButton(
                  '다음 광구',
                  onPressed: () => Navigator.pop(context, true),
                ),
              ],
            ],
          ),
        ],
      ),
    );
    if (mounted) startStage(next == true ? stageIndex + 1 : stageIndex);
  }

  MineralSpec get tradingMineral =>
      game.episode.minerals.firstWhere((m) => m.id == mineralId);
  void showWarehouse() => showFactory();
  void showFactory() => panel<void>(
    (context) => StatefulBuilder(
      builder: (context, refresh) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            '중앙 가공 공장',
            style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Text(
            '원석 ${game.rawStored.toStringAsFixed(1)} / ${game.factory.rawOre.capacity.round()}',
          ),
          Text(
            '완제품 금 ${game.stored.toStringAsFixed(1)} / ${game.storageCapacity.round()}',
          ),
          Text(
            '판매 예약 ${game.trade.reserved.toStringAsFixed(1)} · 판매 가능 ${game.trade.available.toStringAsFixed(1)}',
          ),
          const Divider(),
          Text(
            '원석 2 → 금 1 · 초당 원석 ${game.factory.refinery.rate.toStringAsFixed(1)} 가공',
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          FrontierButton(
            '가공 속도 강화 ${money(game.upgradePrice(Upgrade.processing))}',
            onPressed:
                game.levels[Upgrade.processing]! >=
                        game.maxUpgradeLevel(Upgrade.processing) ||
                    game.cash < game.upgradePrice(Upgrade.processing)
                ? null
                : () {
                    game.upgrade(Upgrade.processing);
                    refresh(() {});
                    setState(() {});
                  },
          ),
          const SizedBox(height: 8),
          FrontierButton(
            '공장 창고 증설 ${money(game.upgradePrice(Upgrade.storage))}',
            onPressed:
                game.levels[Upgrade.storage]! >= 4 ||
                    game.cash < game.upgradePrice(Upgrade.storage)
                ? null
                : () {
                    game.upgrade(Upgrade.storage);
                    refresh(() {});
                    setState(() {});
                  },
          ),
          const SizedBox(height: 12),
          FrontierButton(
            '금 판매 수량 배분',
            onPressed: () {
              Navigator.pop(context);
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) showTrade(0);
              });
            },
          ),
          const SizedBox(height: 8),
          FrontierButton('닫기', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
  void showMineStorage(int id) => panel<void>(
    (context) => StatefulBuilder(
      builder: (context, refresh) {
        final mine = game.deposit(id), storage = mine.storage;
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '갱도 ${id + 1} 원석 저장소 · Lv.${storage.level}',
              style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Text(
              '저장 원석 ${mine.stock.toStringAsFixed(1)} / ${storage.capacity.round()}',
            ),

            const SizedBox(height: 14),
            FrontierButton(
              storage.canUpgrade
                  ? '용량 ${((storage.level + 1) * 100)}으로 강화 ${money(storage.upgradeCost)}'
                  : '최대 단계',
              onPressed: !storage.canUpgrade || game.cash < storage.upgradeCost
                  ? null
                  : () {
                      game.upgradeMineStorage(id);
                      refresh(() {});
                      setState(() {});
                    },
            ),
            const SizedBox(height: 10),
            FrontierButton('닫기', onPressed: () => Navigator.pop(context)),
          ],
        );
      },
    ),
  );
  void showCarts() => panel<void>(
    (context) => StatefulBuilder(
      builder: (context, refresh) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('컨베이어 운송', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text('벨트 단계: ${game.levels[Upgrade.speed]! + 1} / 3'),
          const Text('연결된 모든 갱도가 공용 컨베이어 용량을 나눠 사용합니다.'),
          FrontierButton(
            game.levels[Upgrade.speed]! >= 2 ? '최대 단계' : '벨트 강화 ${money(game.upgradePrice(Upgrade.speed))}',
            onPressed: game.levels[Upgrade.speed]! >= 2 || game.cash < game.upgradePrice(Upgrade.speed)
                ? null
                : () { game.upgrade(Upgrade.speed); refresh(() {}); setState(() {}); },
          ),
          FrontierButton('닫기', onPressed: () => Navigator.pop(context)),
        ],
      ),
    ),
  );
  void showTrade(int merchantId) {
    var first = merchantId == 0 ? game.trade.available.floorToDouble() : 0.0;
    var second = merchantId == 1 ? game.trade.available.floorToDouble() : 0.0;
    panel<void>(
      (context) => StatefulBuilder(
        builder: (context, refresh) {
          final available = game.trade.available.floorToDouble();
          final total = first + second;
          Widget quantity(int id, double amount) => Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '${id + 1}번 중개인 · ${merchantPrice(game.trade.price(id, game.elapsed))}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  IconButton(
                    onPressed: amount < 1
                        ? null
                        : () => refresh(() {
                            if (id == 0) {
                              first--;
                            } else {
                              second--;
                            }
                          }),
                    icon: const Icon(Icons.remove, size: 18),
                  ),
                  Text(
                    '${amount.round()}개',
                    key: ValueKey('trade-quantity-$id'),
                  ),
                  IconButton(
                    onPressed: total >= available
                        ? null
                        : () => refresh(() {
                            if (id == 0) {
                              first++;
                            } else {
                              second++;
                            }
                          }),
                    icon: const Icon(Icons.add, size: 18),
                  ),
                ],
              ),
              Slider(
                value: amount.clamp(0, max(1, available)).toDouble(),
                min: 0,
                max: max(1, available),
                divisions: max(1, min(500, available.toInt())),
                onChanged: available < 1
                    ? null
                    : (value) => refresh(() {
                        if (id == 0) {
                          first = value.roundToDouble();
                          second = min(second, available - first);
                        } else {
                          second = value.roundToDouble();
                          first = min(first, available - second);
                        }
                      }),
              ),
            ],
          );
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '금 판매 수량 배분',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              Text(
                '공장 금 ${game.stored.toStringAsFixed(1)} · 미예약 ${available.round()} · 예약 ${game.trade.reserved.toStringAsFixed(1)}',
                style: const TextStyle(fontSize: 12),
              ),
              quantity(0, first),
              quantity(1, second),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  FrontierButton(
                    '1번에 전부',
                    key: const ValueKey('sell-all-0'),
                    onPressed: available < 1
                        ? null
                        : () => refresh(() {
                            first = available;
                            second = 0;
                          }),
                  ),
                  FrontierButton(
                    '반반',
                    key: const ValueKey('sell-half'),
                    onPressed: available < 1
                        ? null
                        : () => refresh(() {
                            first = (available / 2).floorToDouble();
                            second = available - first;
                          }),
                  ),
                  FrontierButton(
                    '2번에 전부',
                    key: const ValueKey('sell-all-1'),
                    onPressed: available < 1
                        ? null
                        : () => refresh(() {
                            first = 0;
                            second = available;
                          }),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              if (game.trade.reserved > 0)
                TextButton(
                  onPressed: () => refresh(() {
                    game.cancelSale(0);
                    game.cancelSale(1);
                    first = 0;
                    second = 0;
                    setState(() {});
                  }),
                  child: const Text('주문 취소'),
                ),
              const SizedBox(height: 10),
              FrontierButton(
                '${total.round()}개 판매 주문',
                key: const ValueKey('confirm-sale'),
                onPressed: total < 1
                    ? null
                    : () {
                        if (game.splitSale(first, second)) {
                          setState(() {});
                          Navigator.pop(context);
                        }
                      },
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('닫기'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    scene.scanning = tool == 'dig';
    scene.layingTrack = tool == 'rail';
    scene.panning = tool == 'pan';
    scene.selected = selected;
    scene.playbackSpeed = speed;
    scene.sound = sound;
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, box) => Stack(
            children: [
              Column(
                children: [
                  _topBar(box.maxWidth),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, mapBox) => Stack(
                        children: [
                          Positioned.fill(
                            child: Listener(
                              onPointerSignal: (event) {
                                if (event is PointerScrollEvent) {
                                  GestureBinding.instance.pointerSignalResolver
                                      .register(event, (_) {
                                        final p = Vector2(
                                          event.localPosition.dx,
                                          event.localPosition.dy,
                                        );
                                        scene.transformCamera(
                                          p,
                                          p,
                                          exp(-event.scrollDelta.dy * .0015),
                                        );
                                      });
                                }
                              },
                              onPointerDown: _pointerDown,
                              onPointerMove: _pointerMove,
                              onPointerUp: _pointerUp,
                              onPointerCancel: _pointerUp,
                              child: ClipRect(
                                child: GameWidget<MiningWorld>(
                                  key: ObjectKey(scene),
                                  game: scene,
                                ),
                              ),
                            ),
                          ),
                          Positioned(left: 10, top: 10, child: _trader(0)),
                          Positioned(right: 10, top: 10, child: _trader(1)),
                          if (scene.isLoaded)
                            ..._entrances(mapBox.maxWidth, mapBox.maxHeight),
                          if (scene.isLoaded)
                            ..._mineStorageButtons(
                              mapBox.maxWidth,
                              mapBox.maxHeight,
                            ),
                          if (scene.isLoaded)
                            Positioned(right: 10, bottom: 7, child: _minimap()),
                          if (game.paused && !townOpen)
                            Positioned.fill(
                              child: Center(
                                child: FrontierButton(
                                  '시작하기',
                                  key: const ValueKey('start-game'),
                                  onPressed: () =>
                                      setState(() => game.paused = false),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (openUpgrade != null)
                Positioned(
                  top: 68,
                  left: _upgradeLeft(box.maxWidth),
                  width: min(270, box.maxWidth - 24),
                  child: _upgradeCard(openUpgrade!),
                ),
              if (townOpen) Positioned.fill(child: _town()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _topBar(double width) {
    final d = selected == null ? null : game.deposit(selected!);
    final slotWidth = ((width - 230) / 6).clamp(44, 68).toDouble();
    final progressDay = min(
      364,
      (game.elapsed / game.stage.seconds * 365).floor(),
    );
    final date = DateTime(1900, 1, 1).add(Duration(days: progressDay));
    const months = [
      'JAN',
      'FEB',
      'MAR',
      'APR',
      'MAY',
      'JUN',
      'JUL',
      'AUG',
      'SEP',
      'OCT',
      'NOV',
      'DEC',
    ];
    return Container(
      height: 74,
      decoration: const BoxDecoration(
        color: Color(0xFFF2E8D3),
        border: Border(bottom: BorderSide(color: Color(0xFFBEA783), width: 2)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        children: [
          SizedBox(
            width: 103,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: showMenu,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.settings, size: 17, color: hudInk),
                        const SizedBox(width: 5),
                        Text(
                          '1편 · ${game.stage.number}광구',
                          style: const TextStyle(fontSize: 10, color: hudInk),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    money(game.cash),
                    style: const TextStyle(
                      fontSize: 27,
                      color: hudInk,
                      fontFamily: 'serif',
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    '순익 ${money(game.profit)}',
                    style: const TextStyle(
                      fontSize: 10,
                      color: Color(0xFF7B694F),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('scout'),
                    icon: Icons.hiking,
                    label: '탐사인 ${game.searchingScouts}',
                    price: '\$100',
                    tooltip: '',
                    onTap:
                        game.active &&
                            game.cash >= MiningGame.scoutCost &&
                            game.searchingScouts < 3
                        ? () => purchase(() {
                            game.hireScout();
                          })
                        : null,
                    onUpgrade: () => setState(
                      () => openUpgrade = openUpgrade == Upgrade.scanner
                          ? null
                          : Upgrade.scanner,
                    ),
                  ),
                ),
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('dig'),
                    icon: Icons.construction,
                    label: '땅 파기',
                    price: '\$12',
                    tooltip: '',
                    selected: tool == 'dig',
                    onTap: game.active && game.cash >= MiningGame.scanCost
                        ? () => setTool(tool == 'dig' ? 'inspect' : 'dig')
                        : null,
                  ),
                ),
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('rail'),
                    icon: Icons.route,
                    label: '레일',
                    price: '드래그',
                    tooltip: '',
                    selected: tool == 'rail',
                    onTap: game.active
                        ? () => setTool(tool == 'rail' ? 'inspect' : 'rail')
                        : null,
                  ),
                ),
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('hire'),
                    icon: Icons.person,
                    label: '대기 ${game.availableWorkers}',
                    price: '\$75',
                    tooltip: '',
                    onTap: game.active && game.cash >= MiningGame.workerCost
                        ? () => purchase(() {
                            game.buyWorker();
                          })
                        : null,
                    onUpgrade: () => setState(
                      () => openUpgrade = openUpgrade == Upgrade.workers
                          ? null
                          : Upgrade.workers,
                    ),
                  ),
                ),
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('conveyor'),
                    icon: Icons.route,
                    label: '벨트 ${game.levels[Upgrade.speed]! + 1}단계',
                    price: game.levels[Upgrade.speed]! >= 2 ? '최대' : money(game.upgradePrice(Upgrade.speed)),
                    tooltip: '',
                    onTap: game.active && game.levels[Upgrade.speed]! < 2 && game.cash >= game.upgradePrice(Upgrade.speed)
                        ? () => improve(Upgrade.speed)
                        : null,
                    onUpgrade: showCarts,
                  ),
                ),
                SizedBox(
                  width: slotWidth,
                  child: PurchaseTool(
                    key: const ValueKey('storage'),
                    icon: Icons.warehouse,
                    label: '금 ${game.stored.toStringAsFixed(0)}',
                    price: money(game.upgradePrice(Upgrade.storage)),
                    tooltip: '',
                    onTap:
                        game.active &&
                            game.levels[Upgrade.storage]! < 4 &&
                            game.cash >= game.upgradePrice(Upgrade.storage)
                        ? () => improve(Upgrade.storage)
                        : null,
                    onUpgrade: () => setState(
                      () => openUpgrade = openUpgrade == Upgrade.storage
                          ? null
                          : Upgrade.storage,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 74,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 5,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD9C59D),
                    border: Border.all(color: const Color(0xFF99794C)),
                  ),
                  child: Column(
                    children: [
                      Text(
                        months[date.month - 1],
                        style: const TextStyle(
                          fontSize: 11,
                          color: hudInk,
                          letterSpacing: 2,
                        ),
                      ),
                      Text(
                        '${date.day}',
                        style: const TextStyle(
                          fontSize: 24,
                          color: hudInk,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  '${(game.timeLeft / 60).floor()}:${(game.timeLeft % 60).floor().toString().padLeft(2, '0')}',
                  style: const TextStyle(fontSize: 10, color: hudInk),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 36,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                InkWell(
                  key: const ValueKey('pause'),
                  onTap: () => setState(() => game.paused = !game.paused),
                  child: SizedBox(
                    height: 32,
                    width: 34,
                    child: Icon(
                      game.paused ? Icons.play_arrow : Icons.pause,
                      color: hudInk,
                      size: 23,
                    ),
                  ),
                ),
                InkWell(
                  onTap: () => setState(() => speed = speed == 1 ? 2 : 1),
                  child: SizedBox(
                    height: 30,
                    width: 34,
                    child: Center(
                      child: Text(
                        '×$speed',
                        style: const TextStyle(
                          color: hudInk,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _trader(int side) {
    final merchant = game.trade.merchants[side],
        price = game.trade.price(side, game.elapsed);
    return SizedBox(
      width: 108,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaperPanel(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 6),
            child: Column(
              children: [
                Text(
                  '${side + 1}번 중개인',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: hudInk,
                  ),
                ),
                Text(
                  merchantPrice(price),
                  style: const TextStyle(
                    fontSize: 22,
                    fontFamily: 'serif',
                    fontWeight: FontWeight.w900,
                    color: hudInk,
                  ),
                ),
                Text(
                  '예약 ${game.trade.pendingFor(side).toStringAsFixed(0)} · 운반 ${merchant.cargo.amount.toStringAsFixed(0)}',
                  style: const TextStyle(fontSize: 9, color: hudInk),
                ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          FrontierButton(
            '판매 수량',
            key: ValueKey('broker-$side'),
            onPressed: game.finished ? null : () => showTrade(side),
          ),
        ],
      ),
    );
  }

  List<Widget> _entrances(double width, double height) => game.deposits
      .where((d) {
        if (!d.discovered) return false;
        final p = scene.screenPosition(d.exposedPoint!);
        return p.x >= 0 && p.x <= width && p.y >= 0 && p.y <= height;
      })
      .map((d) {
        final p = scene.screenPosition(d.exposedPoint!),
            expanded = selected == d.id;
        final w = expanded ? 30.0 : 24.0, h = expanded ? 48.0 : 20.0;
        return Positioned(
          left: (p.x + 12).clamp(4, max(4, width - w - 4)).toDouble(),
          top: (p.y - (expanded ? 24 : 10))
              .clamp(3, max(3, height - h - 3))
              .toDouble(),
          width: w,
          height: h,
          child: Material(
            color: expanded ? const Color(0xFFF8E2AE) : const Color(0xFFEFE2C2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
              side: BorderSide(
                color: expanded ? hudInk : const Color(0xFF9F895F),
              ),
            ),
            child: InkWell(
              key: ValueKey('entrance-${d.id}'),
              onTap: () => setState(() {
                selected = d.id;
                tool = 'inspect';
              }),
              child: expanded
                  ? WorkforceControl(
                      key: ValueKey('workforce-${d.id}'),
                      mineId: d.id,
                      workers: d.workers,
                      canIncrease:
                          game.active &&
                          game.availableWorkers > 0 &&
                          d.workers < 8 &&
                          d.remaining > .001,
                      canDecrease: game.active && d.workers > 0,
                      increase: () => _changeWorkers(d, true),
                      decrease: () => _changeWorkers(d, false),
                    )
                  : Center(
                      child: Text(
                        '${d.workers}',
                        key: ValueKey('workers-${d.id}'),
                        style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: hudInk,
                        ),
                      ),
                    ),
            ),
          ),
        );
      })
      .toList();
  List<Widget> _mineStorageButtons(double width, double height) =>
      game.deposits.where((mine) => mine.discovered).expand((mine) {
        final p = scene.screenPosition(mine.storagePoint);
        if (p.x < 20 || p.x > width - 20 || p.y < 26 || p.y > height) {
          return <Widget>[];
        }
        return [
          Positioned(
            left: p.x - 18,
            top: p.y - 25,
            width: 36,
            height: 16,
            child: Material(
              color: hudPaper,
              borderRadius: BorderRadius.circular(3),
              child: InkWell(
                key: ValueKey('mine-storage-${mine.id}'),
                onTap: () => showMineStorage(mine.id),
                child: Center(
                  child: Text(
                    'L${mine.storage.level} ↑',
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                      color: hudInk,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ];
      }).toList();
  double _upgradeLeft(double width) {
    final index = switch (openUpgrade) {
      Upgrade.scanner => 0,
      Upgrade.workers => 3,
      Upgrade.speed => 4,
      Upgrade.storage || Upgrade.processing => 5,
      _ => 0,
    };
    return (110 + (width - 230) / 6 * index)
        .clamp(12, max(12, width - 282))
        .toDouble();
  }

  (String, String) upgradeInfo(Upgrade u) => switch (u) {
    Upgrade.processing => ('가공 속도', '공장에서 초당 처리하는 원석량을 늘립니다.'),
    Upgrade.scanner => ('탐사 속도', '탐사인이 더 빨리 광맥을 찾습니다.'),
    Upgrade.workers => ('곡괭이', '광부의 채굴 속도가 35% 증가합니다.'),
    Upgrade.speed => ('수레 바퀴', '수레의 이동 속도가 30% 증가합니다.'),
    Upgrade.storage => ('공장 창고', '원석과 완제품 금의 보관 용량을 늘립니다.'),
  };
  Widget _upgradeCard(Upgrade u) {
    final info = upgradeInfo(u),
        maxed = game.levels[u]! >= game.maxUpgradeLevel(u);
    return PaperPanel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${info.$1} ${game.levels[u]! + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: hudInk,
                  ),
                ),
              ),
              InkWell(
                onTap: () => setState(() => openUpgrade = null),
                child: const Icon(Icons.close, size: 18, color: hudInk),
              ),
            ],
          ),
          const SizedBox(height: 8),

          const SizedBox(height: 10),
          FrontierButton(
            maxed ? '최대 강화' : '구매 ${money(game.upgradePrice(u))}',
            onPressed: !game.active || maxed || game.cash < game.upgradePrice(u)
                ? null
                : () => improve(u),
          ),
        ],
      ),
    );
  }

  Widget _minimap() {
    final position = scene.camera.viewfinder.position,
        view = scene.visibleMapSize;
    return GestureDetector(
      key: const ValueKey('minimap'),
      onTapDown: (details) => setState(
        () => scene.lookAt(
          Point2(details.localPosition.dx / 96, details.localPosition.dy / 42),
        ),
      ),
      child: Container(
        width: 98,
        height: 44,
        decoration: BoxDecoration(border: Border.all(color: hudPaper)),
        child: CustomPaint(
          painter: MineMinimap(
            viewport: Rect.fromLTWH(
              position.x / 3000,
              position.y / 1200,
              view.x / 3000,
              view.y / 1200,
            ),
            mines: game.deposits
                .where((d) => d.discovered)
                .map((d) => Offset(d.railPort.x, d.railPort.y))
                .toList(),
            tracks: game.trackSegments
                .map(
                  (s) => [
                    Offset(s.start.x, s.start.y),
                    Offset(s.end.x, s.end.y),
                  ],
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Widget _town() {
    final options = townSection == 'stable'
        ? [Upgrade.speed]
        : townSection == 'storage'
        ? [Upgrade.storage, Upgrade.processing]
        : [Upgrade.scanner, Upgrade.workers];
    return Container(
      color: const Color(0xFFF0E5CB),
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              const Text(
                '광산 마을',
                style: TextStyle(
                  fontFamily: 'serif',
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: hudInk,
                ),
              ),
              const Spacer(),
              Text(
                money(game.cash),
                style: const TextStyle(
                  fontFamily: 'serif',
                  fontSize: 28,
                  color: hudInk,
                ),
              ),
              const SizedBox(width: 16),
              IconButton(
                onPressed: () => toggleTown(),
                icon: const Icon(Icons.close, color: hudInk),
              ),
            ],
          ),
          Expanded(
            child: townSection == 'stages'
                ? SingleChildScrollView(
                    child: Column(
                      children: stages
                          .asMap()
                          .entries
                          .map(
                            (entry) => ListTile(
                              leading: Icon(
                                entry.key <= unlocked
                                    ? Icons.landscape
                                    : Icons.lock,
                                color: hudInk,
                              ),
                              title: Text(
                                '${entry.value.number}. ${entry.value.title}',
                              ),
                              subtitle: Text(
                                '목표 순이익 ${money(entry.value.targetProfit)}',
                              ),
                              enabled: entry.key <= unlocked,
                              onTap: entry.key <= unlocked
                                  ? () => startStage(entry.key)
                                  : null,
                            ),
                          )
                          .toList(),
                    ),
                  )
                : Row(
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              townSection == 'stable'
                                  ? Icons.shopping_cart
                                  : townSection == 'storage'
                                  ? Icons.warehouse
                                  : Icons.engineering,
                              color: const Color(0xFF816B48),
                              size: 70,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              townSection == 'stable'
                                  ? '수레 공방'
                                  : townSection == 'storage'
                                  ? '창고 관리인'
                                  : '작업장 주인',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: hudInk,
                              ),
                            ),
                            const SizedBox(height: 10),
                          ],
                        ),
                      ),
                      Expanded(
                        flex: 6,
                        child: SingleChildScrollView(
                          child: Column(
                            children: options.map((u) {
                              final info = upgradeInfo(u);
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                ),
                                child: PaperPanel(
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              '${info.$1} ${game.levels[u]! + 1}',
                                              style: const TextStyle(
                                                fontSize: 17,
                                                fontWeight: FontWeight.bold,
                                                color: hudInk,
                                              ),
                                            ),
                                            const SizedBox(height: 5),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      FrontierButton(
                                        game.levels[u]! >=
                                                game.maxUpgradeLevel(u)
                                            ? '최대'
                                            : money(game.upgradePrice(u)),
                                        onPressed:
                                            game.levels[u]! >=
                                                    game.maxUpgradeLevel(u) ||
                                                game.cash < game.upgradePrice(u)
                                            ? null
                                            : () => improve(u, inTown: true),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ...[
                ('workshop', '작업장'),
                ('stable', '수레 공방'),
                ('storage', '창고'),
                ('stages', '광구'),
              ].map(
                (section) => Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: FrontierButton(
                    section.$2,
                    active: townSection == section.$1,
                    onPressed: () => setState(() => townSection = section.$1),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FrontierButton(
                '채굴 시작 ▶',
                active: true,
                onPressed: () => toggleTown(),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hide fractional dollars in the HUD; trading retains the exact price.
String merchantPrice(double price) => '\$${max(1, price.floor())}';
