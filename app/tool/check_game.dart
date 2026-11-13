import 'dart:io';
import 'package:mine_path/game.dart';

void main(List<String> args) {
  final count = args.isEmpty ? 1000 : int.parse(args.first);
  for (var seed = 0; seed < count; seed++) {
    final game = MineGame(seed);
    final safe = game.deduce().$1;
    if (game.connected(game.revealed, game.player).contains(game.goal)) {
      throw StateError('Map requires no deduction: $seed');
    }
    if (safe.intersection(game.mines).isNotEmpty ||
        !game.connected(safe, game.player).contains(game.goal)) {
      throw StateError('Invalid map $seed');
    }
    var guard = 0;
    while (!game.won && guard++ < 192) {
      final next = game.findHint();
      if (next == null || !game.move(next) || game.lost) {
        throw StateError('Invalid hint $seed');
      }
    }
    if (!game.won) throw StateError('Unreachable exit $seed');
  }
  stdout.writeln(
    'PASS: $count maps have a provable route and safe hints lead to the exit.',
  );
}
