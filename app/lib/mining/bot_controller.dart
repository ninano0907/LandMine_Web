import 'simulation.dart';

/// Simple deterministic autonomous opponent for isolated simulations.
/// Uses the same public actions and costs as the human player.
class MiningBotController {
  final MiningGame game;
  final double decisionInterval;
  double _nextDecision = 0;

  MiningBotController(this.game, {this.decisionInterval = 2})
      : assert(decisionInterval > 0);

  /// Advance one bot's game clock and periodically make economic decisions.
  void tick(double seconds) {
    if (!seconds.isFinite || seconds <= 0 || game.finished) return;
    var remaining = seconds;
    while (remaining > 1e-7 && !game.finished) {
      if (game.elapsed + 1e-7 >= _nextDecision) {
        decide();
        _nextDecision = game.elapsed + decisionInterval;
      }
      final dt = (remaining < _nextDecision - game.elapsed)
          ? remaining
          : _nextDecision - game.elapsed;
      if (dt <= 1e-7) {
        _nextDecision = game.elapsed + decisionInterval;
        continue;
      }
      game.tick(dt);
      remaining -= dt;
    }
  }

  /// No hidden free resources: scouting, workers, rails and upgrades are paid.
  void decide() {
    if (!game.canCommand) return;

    // First connect discovered shafts. If terrain research is unavailable,
    // keep exploring rather than repeatedly spending on blocked routes.
    for (final mine in game.deposits) {
      if (!mine.discovered || mine.remaining <= 0) continue;
      if (game.railFor(mine.id) == null && game.cash >= game.railPrice(mine.id)) {
        game.connect(mine.id);
      }
      if (game.railFor(mine.id) != null &&
          mine.workers < 2 &&
          game.availableWorkers == 0 &&
          game.cash >= MiningGame.workerCost) {
        game.buyWorker();
      }
      if (game.railFor(mine.id) != null && game.availableWorkers > 0) {
        game.assignWorker(mine.id);
      }
    }

    if (game.searchingScouts < 1 &&
        game.cash >= MiningGame.scoutCost) {
      game.hireScout();
    }

    // Sell refined gold through the same broker as the player.
    if (game.trade.available > 0) game.sellAll();

    // Upgrade only after basic infrastructure is running.
    if (game.rails.isNotEmpty &&
        game.cash > game.upgradePrice(Upgrade.processing) + 200) {
      game.upgrade(Upgrade.processing);
    }
  }
}
