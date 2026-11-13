/// Episode-specific names, appearances and balancing live here.
/// Future episodes reuse the simulation; different mechanics may need new rules.
class MineralSpec {
  final String id, name, symbol;
  final int color;
  final double price, hardness;
  const MineralSpec(
    this.id,
    this.name,
    this.symbol,
    this.color,
    this.price,
    this.hardness,
  );
}

class EpisodeSpec {
  final int number;
  final String title, worker, cart, scanner;
  final List<MineralSpec> minerals;
  final double workerRate, cartCapacity, cartSpeed, scanRadius;
  const EpisodeSpec({
    required this.number,
    required this.title,
    required this.worker,
    required this.cart,
    required this.scanner,
    required this.minerals,
    this.workerRate = 1.5,
    this.cartCapacity = 50,
    this.cartSpeed = .075,
    this.scanRadius = .045,
  });
}

const handEra = EpisodeSpec(
  number: 1,
  title: '사람과 수레의 시대',
  worker: '⛏️',
  cart: '🛒',
  scanner: '🔎',
  minerals: [MineralSpec('gold', '금', 'Au', 0xFFF2CF61, 25, 2)],
);
const episodeTitles = ['사람과 수레의 시대', '증기의 시대', '현대의 광산', '미래의 광산'];

class StageSpec {
  final int number, seed, deposits;
  final String title;
  final double seconds, startingCash, targetProfit, railCost;
  const StageSpec(
    this.number,
    this.title, {
    required this.seed,
    required this.deposits,
    required this.seconds,
    required this.startingCash,
    required this.targetProfit,
    this.railCost = 260,
  });
}

const stages = [
  StageSpec(
    1,
    '첫 번째 광산',
    seed: 101,
    deposits: 7,
    seconds: 240,
    startingCash: 1000,
    targetProfit: 1500,
  ),
  StageSpec(
    2,
    '황금빛 언덕',
    seed: 202,
    deposits: 9,
    seconds: 600,
    startingCash: 1100,
    targetProfit: 5000,
  ),
  StageSpec(
    3,
    '깊은 곳의 금',
    seed: 303,
    deposits: 11,
    seconds: 600,
    startingCash: 1200,
    targetProfit: 8000,
  ),
  StageSpec(
    4,
    '수레가 모자라',
    seed: 404,
    deposits: 13,
    seconds: 600,
    startingCash: 1300,
    targetProfit: 11000,
  ),
  StageSpec(
    5,
    '광산주 시험',
    seed: 505,
    deposits: 15,
    seconds: 600,
    startingCash: 1400,
    targetProfit: 14000,
  ),
];

/// First-play balance knobs; all quantities are abstract game units.
class GameBalance {
  static const mineStorageCapacities = [100.0, 200.0, 300.0];
  static const mineStorageUpgradeCosts = [150.0, 300.0];
  static const cartCapacities = [50.0, 100.0, 200.0];
  static const cartUpgradeCosts = [250.0, 500.0];
  static const orePerGold = 2.0;
  static const refineryOrePerSecond = 3.0;
  static const cartLoadPerSecond = 20.0, cartUnloadPerSecond = 25.0;
  static const partialLoadWait = 8.0;
  static const brokerCapacity = 40.0,
      brokerSpeed = .11,
      brokerLoadPerSecond = 10.0;
}
