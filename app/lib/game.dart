import 'dart:math';

class MineGame {
  static const rows = 16, cols = 12, size = rows * cols;
  final int seed;
  late final Set<int> mines;
  final Set<int> revealed = {}, flags = {}, trail = {};
  int player = 185, moves = 0;
  final int goal = 6;
  bool lost = false, won = false;
  int? hint;
  MineGame(this.seed) {
    final random = Random(seed);
    // A winding corridor guarantees a physical route.
    final route = <int>[player];
    var x = player % cols;
    for (var y = rows - 1; y >= 0; y--) {
      final target = y == 0
          ? goal
          : y % 3 == 0
          ? (x + random.nextInt(5) - 2).clamp(1, cols - 2)
          : x;
      while (x != target) {
        x += target > x ? 1 : -1;
        route.add(y * cols + x);
      }
      if (y > 0) route.add((y - 1) * cols + x);
    }
    final protected = route.toSet();
    mines = {
      for (var i = 0; i < size; i++)
        if (!protected.contains(i) && random.nextDouble() < .32) i,
    };
    for (var i = 0; i < size; i++) {
      if (!mines.contains(i) && random.nextDouble() < .30) revealed.add(i);
    }
    revealed.addAll([player, goal]);
    trail.add(player);
    // Add honest clues until the visible numbers prove a connected safe route.
    for (var attempt = 0; attempt < size; attempt++) {
      final safe = deduce().$1;
      final reachable = connected(safe, player);
      if (reachable.contains(goal)) break;
      final frontier =
          reachable
              .expand(orthogonal)
              .where((i) => !mines.contains(i) && !safe.contains(i))
              .toSet()
              .toList()
            ..shuffle(random);
      if (frontier.isEmpty) break;
      final next = frontier.first;
      final clues =
          around(next)
              .where(
                (i) =>
                    !mines.contains(i) &&
                    !revealed.contains(i) &&
                    !protected.contains(i),
              )
              .toList()
            ..shuffle(random);
      if (clues.isNotEmpty) {
        revealed.add(clues.first);
      } else {
        revealed.add(next);
      }
    }
    // Strip redundant information, especially zero islands. A route must remain
    // provable, but the player should have to infer covered cells to follow it.
    final candidates = revealed.where((i) => i != player && i != goal).toList()
      ..shuffle(random);
    candidates.sort(
      (a, b) => (number(a) == 0 ? 0 : 1).compareTo(number(b) == 0 ? 0 : 1),
    );
    for (final clue in candidates) {
      revealed.remove(clue);
      if (!connected(deduce().$1, player).contains(goal)) {
        revealed.add(clue);
      }
    }
  }
  Iterable<int> around(int i) sync* {
    for (var dy = -1; dy <= 1; dy++) {
      for (var dx = -1; dx <= 1; dx++) {
        final y = i ~/ cols + dy, x = i % cols + dx;
        if ((dx != 0 || dy != 0) && y >= 0 && y < rows && x >= 0 && x < cols) {
          yield y * cols + x;
        }
      }
    }
  }

  Iterable<int> orthogonal(int i) => around(i).where(
    (j) => (j ~/ cols - i ~/ cols).abs() + (j % cols - i % cols).abs() == 1,
  );
  int number(int i) => around(i).where(mines.contains).length;
  Set<int> connected(Set<int> safe, int start) {
    final found = <int>{start}, queue = [start];
    for (var n = 0; n < queue.length; n++) {
      for (final i in orthogonal(queue[n])) {
        if (safe.contains(i) && found.add(i)) queue.add(i);
      }
    }
    return found;
  }

  (Set<int>, Set<int>) deduce() {
    final safe = {...revealed}, bombs = <int>{};
    var changed = true;
    while (changed) {
      changed = false;
      final constraints = <(Set<int>, int)>[];
      void apply(Set<int> cells, int remaining) {
        if (cells.isEmpty) return;
        if (remaining == 0) {
          final before = safe.length;
          safe.addAll(cells);
          changed |= before != safe.length;
        } else if (remaining == cells.length) {
          final before = bombs.length;
          bombs.addAll(cells);
          changed |= before != bombs.length;
        }
      }

      for (final i in revealed) {
        final adjacent = around(i).toSet();
        final unknown = adjacent.difference(safe).difference(bombs);
        final remaining = number(i) - adjacent.intersection(bombs).length;
        if (unknown.isEmpty) continue;
        constraints.add((unknown, remaining));
        apply(unknown, remaining);
      }
      if (changed) continue;
      // If A is contained in B, subtract their mine counts. This is the
      // reasoning behind patterns such as 1–2–1, beyond single-number rules.
      for (final a in constraints) {
        for (final b in constraints) {
          if (a.$1.length >= b.$1.length || !b.$1.containsAll(a.$1)) continue;
          apply(b.$1.difference(a.$1), b.$2 - a.$2);
        }
      }
    }
    return (safe, bombs);
  }

  bool move(int i) {
    if (lost || won || flags.contains(i) || !orthogonal(player).contains(i)) {
      return false;
    }
    hint = null;
    player = i;
    moves++;
    if (mines.contains(i)) {
      lost = true;
      return true;
    }
    revealed.add(i);
    trail.add(i);
    won = i == goal;
    return true;
  }

  void flag(int i) {
    if (lost || won || revealed.contains(i) || i == player) return;
    if (!flags.remove(i)) flags.add(i);
  }

  int? findHint() {
    final safe = deduce().$1;
    final queue = [player];
    final previous = <int, int>{player: -1};
    for (var n = 0; n < queue.length; n++) {
      final current = queue[n];
      if (current == goal) {
        var next = current;
        while (previous[next] != player && previous[next] != -1) {
          next = previous[next]!;
        }
        return hint = next;
      }
      for (final next in orthogonal(current)) {
        if (safe.contains(next) && !previous.containsKey(next)) {
          previous[next] = current;
          queue.add(next);
        }
      }
    }
    return null;
  }
}
