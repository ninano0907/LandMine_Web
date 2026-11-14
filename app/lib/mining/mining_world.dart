import 'dart:math';
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/material.dart' show Colors;
import 'simulation.dart';
import 'sound.dart';

/// Flame owns time, input, entities and animations. Flutter only draws the HUD.
class MiningWorld extends FlameGame {
  final MiningGame simulation;
  final void Function() onChanged;
  final void Function(int?) onSelected;
  final void Function()? onFactorySelected;
  late MineField field;
  Point2 probe = const Point2(.46, .14);
  Point2 target = const Point2(.46, .14);
  bool scanning = false, sound = true, layingTrack = false, panning = false;
  bool cameraGestureActive = false;
  double _baseZoom = 1;
  int? dragNode;
  Point2? trackPreview;
  int playbackSpeed = 1;
  int? selected;
  double _refresh = 0;
  final Set<int> _scoutIds = {};
  final Set<int> _storageIds = {};
  int _foundScouts = 0;
  final Set<String> _workerIds = {};
  MiningWorld({
    required this.simulation,
    required this.onChanged,
    required this.onSelected,
    this.onFactorySelected,
  });
  @override
  Color backgroundColor() => const Color(0xFF9C8B6E);
  @override
  Future<void> onLoad() async {
    camera.viewfinder.anchor = Anchor.topLeft;
    field = MineField(this)..size = Vector2(3000, 2400);
    resetCamera();
    await world.add(field);
    await field.add(ExcavationCursor(this));
    for (final merchant in simulation.trade.merchants) {
      await field.add(BrokerWagonActor(this, merchant));
    }
    await field.add(RefineryActor(this));
  }

  @override
  void update(double dt) {
    if (!isLoaded) {
      super.update(dt);
      return;
    }
    final realDt = min(dt, .1);
    if (simulation.active) {
      simulation.tick(realDt * playbackSpeed);
    }
    final found = simulation.scouts.where((s) => s.found).length;
    if (found > _foundScouts && sound) DetectorSound.beep();
    _foundScouts = found;
    for (final scout in simulation.scouts) {
      if (_scoutIds.add(scout.id)) field.add(ScoutActor(this, scout));
    }

    for (final actor in field.children.whereType<WorkerActor>().toList()) {
      if (actor.index >= actor.deposit.workers) {
        _workerIds.remove('${actor.deposit.id}:${actor.index}');
        actor.removeFromParent();
      }
    }
    for (final d in simulation.deposits) {
      if (d.discovered && _storageIds.add(d.id)) {
        field.add(MineStorageActor(this, d));
      }
      for (var i = 0; i < d.workers; i++) {
        if (_workerIds.add('${d.id}:$i')) field.add(WorkerActor(this, d, i));
      }
    }
    super.update(realDt);
    _refresh += realDt;
    if (_refresh >= .1) {
      _refresh = 0;
      onChanged();
    }
  }

  Vector2 screenPosition(Point2 point) =>
      camera.localToGlobal(field.location(point));

  Vector2 get visibleMapSize => canvasSize / camera.viewfinder.zoom;
  double get minimumZoom => max(canvasSize.x / 3000, canvasSize.y / 2400);
  void moveCamera(Vector2 delta) {
    final visible = visibleMapSize;
    final next = camera.viewfinder.position + delta;
    camera.viewfinder.position = Vector2(
      next.x.clamp(0, max(0, 3000 - visible.x)).toDouble(),
      next.y.clamp(0, max(0, 2400 - visible.y)).toDouble(),
    );
  }

  void transformCamera(Vector2 oldFocal, Vector2 newFocal, double factor) {
    final anchor = camera.globalToLocal(oldFocal);
    camera.viewfinder.zoom = (camera.viewfinder.zoom * factor)
        .clamp(minimumZoom, _baseZoom * 3)
        .toDouble();
    final shifted = camera.globalToLocal(newFocal);
    moveCamera(anchor - shifted);
    onChanged();
  }

  void zoomBy(double factor) =>
      transformCamera(canvasSize / 2, canvasSize / 2, factor);
  void resetCamera() {
    _baseZoom = max(canvasSize.x / 1500, minimumZoom);
    camera.viewfinder.zoom = _baseZoom;
    camera.viewfinder.position = Vector2(1500, 1200) - visibleMapSize / 2;
    moveCamera(Vector2.zero());
  }

  @override
  void onGameResize(Vector2 size) {
    final previousCenter = isLoaded
        ? camera.viewfinder.position + visibleMapSize / 2
        : null;
    final ratio = isLoaded ? camera.viewfinder.zoom / _baseZoom : 1.0;
    super.onGameResize(size);
    if (previousCenter != null) {
      _baseZoom = max(size.x / 1500, minimumZoom);
      camera.viewfinder.zoom = max(minimumZoom, _baseZoom * ratio);
      camera.viewfinder.position = previousCenter - visibleMapSize / 2;
      moveCamera(Vector2.zero());
    }
  }

  void lookAt(Point2 point) {
    camera.viewfinder.position =
        Vector2(point.x * 3000, point.y * 2400) - visibleMapSize / 2;
    moveCamera(Vector2.zero());
  }

  bool excavate() {
    final success = simulation.scan(probe);
    if (success && isLoaded) field.add(DigDust(this, probe));
    return success;
  }

  void selectAt(Point2 point) {
    if (!simulation.active) return;
    if (point.distance(MiningGame.entrance) < .12) {
      onFactorySelected?.call();
      return;
    }
    // Only the excavated portion of a vein is selectable.
    for (final d in simulation.deposits.reversed) {
      if (d.discovered && simulation.visible(point) && d.contains(point)) {
        selected = d.id;
        scanning = false;
        onSelected(d.id);
        return;
      }
    }
    scanning = true;
    selected = null;
    final markers = simulation.scouts.where(
      (s) => s.found && s.point.distance(point) < .06,
    );
    probe = markers.isEmpty ? point : markers.first.point;
    target = probe;
    onSelected(null);
  }
}

class MineField extends PositionComponent with TapCallbacks, DragCallbacks {
  final MiningWorld scene;
  MineField(this.scene);
  Point2 normalized(Vector2 p) => Point2(
    (p.x / size.x).clamp(0, 1).toDouble(),
    (p.y / size.y).clamp(.02, .97).toDouble(),
  );
  Vector2 location(Point2 p) => Vector2(p.x * size.x, p.y * size.y);
  double get unit => size.y / MiningGame.mapScale;
  @override
  void onTapUp(TapUpEvent event) {
    if (scene.panning || scene.cameraGestureActive || scene.layingTrack) return;
    final point = normalized(event.localPosition);
    if (scene.scanning) {
      scene.probe = point;
      scene.target = point;
      scene.excavate();
      scene.onChanged();
    } else {
      scene.selectAt(point);
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);
    if (scene.panning ||
        scene.cameraGestureActive ||
        !scene.simulation.active) {
      return;
    }
    final point = normalized(event.localPosition);
    if (scene.layingTrack) {
      final nearby =
          scene.simulation.trackNodes
              .where((n) => n.point.distance(point) < .07)
              .toList()
            ..sort(
              (a, b) =>
                  a.point.distance(point).compareTo(b.point.distance(point)),
            );
      if (nearby.isNotEmpty) {
        scene.dragNode = nearby.first.id;
        scene.trackPreview = point;
      } else {
        scene.simulation.message = '채굴 공장이나 기존 레일의 파란 연결점에서 드래그하세요.';
      }
    } else if (scene.scanning) {
      scene.probe = point;
      scene.target = point;
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    if (scene.cameraGestureActive) return;
    if (scene.panning &&
        event.localDelta.x.isFinite &&
        event.localDelta.y.isFinite) {
      scene.moveCamera(-event.localDelta);
      scene.onChanged();
      return;
    }
    if (!scene.simulation.active ||
        !event.localStartPosition.x.isFinite ||
        !event.localStartPosition.y.isFinite) {
      return;
    }
    final point = normalized(event.localStartPosition);
    if (scene.layingTrack && scene.dragNode != null) {
      scene.trackPreview = point;
    } else if (scene.scanning) {
      scene.probe = point;
      scene.target = point;
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);
    if (!scene.cameraGestureActive &&
        scene.dragNode != null &&
        scene.trackPreview != null) {
      scene.simulation.buildTrack(scene.dragNode!, scene.trackPreview!);
    }
    scene.dragNode = null;
    scene.trackPreview = null;
    scene.onChanged();
  }

  @override
  void onDragCancel(DragCancelEvent event) {
    scene.dragNode = null;
    scene.trackPreview = null;
    super.onDragCancel(event);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    final game = scene.simulation;
    final rect = Rect.fromLTWH(0, 0, size.x, size.y);
    canvas.drawRect(rect, Paint()..color = const Color(0xFFAEAC86));
    final random = Random(game.stage.seed);
    for (var i = 0; i < 260; i++) {
      final p = Offset(
        random.nextDouble() * size.x,
        random.nextDouble() * size.y,
      );
      canvas.drawCircle(
        p,
        1 + random.nextDouble() * 2,
        Paint()..color = const Color(0xFF7C865B).withValues(alpha: .3),
      );
    }
    // Geology is painted first, then strictly masked by excavated areas.
    // Discovery never reveals an entire vein or its unexcavated boundary.
    for (final d in game.deposits) {
      final center = location(d.point).toOffset();
      final bounds = Rect.fromCenter(
        center: center,
        width: d.radius * unit * 2,
        height: d.radius * unit * 2,
      );
      canvas.drawOval(
        bounds,
        Paint()
          ..color = Color(
            d.mineral.color,
          ).withValues(alpha: d.remaining > .001 ? 1 : .25),
      );
      canvas.save();
      canvas.clipPath(Path()..addOval(bounds));
      for (var i = 0; i < 11; i++) {
        final p =
            center +
            Offset(
              sin(i * 2.4 + d.id) * bounds.width * .43,
              cos(i * 1.8) * bounds.height * .43,
            );
        canvas.drawCircle(
          p,
          3 + (i % 3).toDouble(),
          Paint()..color = Colors.white.withValues(alpha: .25),
        );
      }
      canvas.restore();
      if (scene.selected == d.id) {
        canvas.drawOval(
          bounds.deflate(2),
          Paint()
            ..color = const Color(0xFFFDF6DC)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 3,
        );
      }
    }
    canvas.saveLayer(rect, Paint());
    canvas.drawRect(rect, Paint()..color = const Color(0xFF9C8B6E));
    for (var i = 0; i < 80; i++) {
      final p = Offset(
        random.nextDouble() * size.x,
        random.nextDouble() * size.y,
      );
      canvas.drawCircle(
        p,
        10 + random.nextDouble() * 30,
        Paint()..color = Colors.white.withValues(alpha: .025),
      );
    }
    for (final dig in game.surveys) {
      canvas.drawOval(
        Rect.fromCenter(
          center: location(dig.point).toOffset(),
          width: dig.radius * unit * 2,
          height: dig.radius * unit * 2,
        ),
        Paint()..blendMode = BlendMode.clear,
      );
    }
    canvas.drawCircle(
      location(MiningGame.entrance).toOffset(),
      100,
      Paint()..blendMode = BlendMode.clear,
    );
    canvas.restore();
    // Simple overhead terrain: render above the underground geology mask.
    final terrain = game.terrain;
    final river = Path();
    final riverBank = Path();
    for (var i = 0; i <= 90; i++) {
      final x = i / 90.0;
      final y = terrain.riverCenterY(x);
      final left = Offset(x * size.x, (y - .026) * size.y);
      final bank = Offset(x * size.x, (y - .032) * size.y);
      if (i == 0) {
        river.moveTo(left.dx, left.dy);
        riverBank.moveTo(bank.dx, bank.dy);
      } else {
        river.lineTo(left.dx, left.dy);
        riverBank.lineTo(bank.dx, bank.dy);
      }
    }
    for (var i = 90; i >= 0; i--) {
      final x = i / 90.0;
      final y = terrain.riverCenterY(x);
      river.lineTo(x * size.x, (y + .026) * size.y);
      riverBank.lineTo(x * size.x, (y + .032) * size.y);
    }
    river.close();
    riverBank.close();
    canvas.drawPath(riverBank, Paint()..color = const Color(0xFF6A806D));
    canvas.drawPath(river, Paint()..color = const Color(0xFF4A8CA7));
    for (final mountain in terrain.mountains) {
      final c = location(mountain.center).toOffset();
      final radius = mountain.radius * unit;
      final area = Rect.fromCenter(
        center: c, width: radius * 2.8, height: radius * 2);
      canvas.drawOval(area.shift(const Offset(6, 8)),
          Paint()..color = const Color(0xFF58624A));
      canvas.drawOval(area,
          Paint()..color = const Color(0xFF849071));
      canvas.drawOval(area.deflate(radius * .36),
          Paint()..color = const Color(0xFFB3B49B));
    }
    // A small spoil rim marks each actual shovel excavation.
    for (final dig in game.surveys) {
      canvas.drawOval(
        Rect.fromCenter(
          center: location(dig.point).toOffset(),
          width: dig.radius * unit * 2,
          height: dig.radius * unit * 2,
        ),
        Paint()
          ..color = const Color(0xFF6C5E46).withValues(alpha: .30)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    for (final rail in game.trackSegments) {
      final a = location(rail.start).toOffset();
      final b = Offset.lerp(
        a,
        location(rail.end).toOffset(),
        rail.construction,
      )!;
      final delta = b - a;
      final perp = Offset(-delta.dy, delta.dx) / max(1, delta.distance) * 4;
      // Continuous belt body, rather than railway sleepers or carts.
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFF433C34)
          ..strokeWidth = 13
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = const Color(0xFF8B7961)
          ..strokeWidth = 9
          ..strokeCap = StrokeCap.round,
      );
      // Animated diagonal cleats show the belt moving toward the factory.
      if (rail.ready && game.active && delta.distance > 0) {
        final spacing = 14.0;
        final offset = (game.elapsed * game.speed * 18) % spacing;
        for (var distance = offset; distance < delta.distance; distance += spacing) {
          final p = a + delta * (distance / delta.distance);
          canvas.drawLine(
            p - perp * .7 - delta / delta.distance * 2,
            p + perp * .7 + delta / delta.distance * 2,
            Paint()
              ..color = const Color(0xFFD0B992)
              ..strokeWidth = 2,
          );
        }
      }
      // Only the actual river or mountain span is highlighted, not the
      // entire conveyor. This keeps long routes visually uncluttered.
      final coloredSteps = max(12, (delta.distance / 8).ceil());
      for (var i = 0; i < coloredSteps; i++) {
        final t0 = rail.construction * i / coloredSteps;
        final t1 = rail.construction * (i + 1) / coloredSteps;
        final mid = rail.start.towards(rail.end, (t0 + t1) / 2);
        final color = game.terrain.isRiver(mid)
            ? const Color(0xFFE3BF7E)
            : game.terrain.isMountain(mid)
                ? const Color(0xFF3F4342)
                : const Color(0xFFD7D8CD);
        final start = Offset.lerp(a, b, i / coloredSteps)!;
        final end = Offset.lerp(a, b, (i + 1) / coloredSteps)!;
        for (final side in [-1, 1]) {
          canvas.drawLine(
            start + perp * side.toDouble(),
            end + perp * side.toDouble(),
            Paint()
              ..color = color
              ..strokeWidth = color == const Color(0xFFD7D8CD) ? 2 : 3,
          );
        }
      }
    }
    // Moving raw ore chips make active conveyor sections readable from above.
    if (game.active) {
      for (final route in game.rails.where((r) => r.ready)) {
        final mine = game.deposit(route.depositId);
        if (mine.stock <= 0) continue;
        for (var i = 0; i < 4; i++) {
          final t = ((game.elapsed * game.speed * .15 + i / 4) % 1.0);
          final p = location(route.pointAt(1 - t)).toOffset();
          canvas.drawCircle(p, 4, Paint()..color = const Color(0xFF9C876A));
          canvas.drawCircle(p + const Offset(-1, -1), 1.4, Paint()..color = const Color(0xFFD9BA72));
        }
      }
    }
    for (final node in game.trackNodes) {
      final p = location(node.point).toOffset();
      canvas.drawCircle(
        p,
        node.parentId == null ? 14 : 7,
        Paint()..color = const Color(0xFF426E8D),
      );
      canvas.drawCircle(
        p,
        node.parentId == null ? 14 : 7,
        Paint()
          ..color = const Color(0xFFF1E8CC)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    // Every discovered mine has a visible loading port, even before rails exist.
    for (final d in game.deposits.where((d) => d.discovered)) {
      final entrance = location(d.exposedPoint!).toOffset();
      final port = location(d.railPort).toOffset();
      canvas.drawLine(
        entrance + const Offset(0, 15),
        port,
        Paint()
          ..color = const Color(0xFF63543D)
          ..strokeWidth = 4,
      );
      canvas.drawCircle(entrance, 17, Paint()..color = const Color(0xFF745B39));
      canvas.drawCircle(entrance, 11, Paint()..color = const Color(0xFF282B27));
      canvas.drawLine(
        entrance + const Offset(-16, -13),
        entrance + const Offset(16, -13),
        Paint()
          ..color = const Color(0xFFD3B582)
          ..strokeWidth = 5,
      );
      canvas.drawCircle(port, 14, Paint()..color = const Color(0xFF426E8D));
      canvas.drawCircle(
        port,
        14,
        Paint()
          ..color = const Color(0xFFFFEFC9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    if (scene.dragNode != null && scene.trackPreview != null) {
      final a = location(game.trackNodes[scene.dragNode!].point).toOffset();
      final b = location(game.snapTrackEnd(scene.trackPreview!)).toOffset();
      final blocked = game.trackWouldCross(
        scene.dragNode!,
        scene.trackPreview!,
      );
      canvas.drawLine(
        a,
        b,
        Paint()
          ..color = blocked ? const Color(0xFFD2553B) : const Color(0xFFFFE99C)
          ..strokeWidth = 3,
      );
      final midpoint = (a + b) / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(midpoint.dx - 5, midpoint.dy - 3, 120, 39),
          const Radius.circular(4),
        ),
        Paint()..color = const Color(0xFFF3E6C6),
      );
      label(
        canvas,
        blocked
            ? '교차 불가'
            : '\$${game.trackPrice(scene.dragNode!, scene.trackPreview!).round()}',
        midpoint,
        const Color(0xFF493D2B),
        28,
      );
    }
    // Top-down factory floor plan; no facades or perspective.
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: location(MiningGame.entrance).toOffset(),
          width: 110,
          height: 70,
        ),
        const Radius.circular(8),
      ),
      Paint()..color = const Color(0xFF5E6F50),
    );

    for (final gate in game.factory.gates) {
      final p = location(gate.point).toOffset();
      canvas.drawCircle(p, 14, Paint()..color = const Color(0xFF426E8D));
      canvas.drawCircle(
        p,
        14,
        Paint()
          ..color = const Color(0xFFFFEFC9)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3,
      );
    }
    for (final merchant in game.trade.merchants) {
      final p = location(merchant.shop).toOffset();
      canvas.drawRect(
        Rect.fromCenter(center: p, width: 82, height: 64),
        Paint()..color = const Color(0xFF765C3F),
      );
    }
  }
}

abstract class MineActor extends PositionComponent {
  final MiningWorld scene;
  MineActor(this.scene) : super(priority: 20, scale: Vector2.all(1.8));
  @override
  bool containsLocalPoint(Vector2 point) => false;
}

class ExcavationCursor extends MineActor {
  ExcavationCursor(super.scene) {
    scale.setValues(1, 1);
  }
  @override
  void update(double dt) {
    super.update(dt);
    position = scene.field.location(scene.probe);
  }

  @override
  void render(Canvas canvas) {
    if (!scene.scanning) return;
    final radius = scene.simulation.surveyRadius * scene.field.unit;
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..color = const Color(0xFFFFE7A0)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(-5, 0),
      const Offset(5, 0),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(0, -5),
      const Offset(0, 5),
      Paint()
        ..color = Colors.white
        ..strokeWidth = 2,
    );
  }
}

class ScoutActor extends MineActor {
  final Scout scout;
  double time = 0;
  ScoutActor(super.scene, this.scout);
  @override
  void update(double dt) {
    super.update(dt);
    if (scene.simulation.active) time += dt;
    position = scene.field.location(scout.point);
  }

  @override
  void render(Canvas canvas) {
    if (scout.found) return;
    final step = sin(time * 15) * 2;
    canvas.drawCircle(
      Offset(-4, 4 + step),
      3,
      Paint()..color = const Color(0xFF453D33),
    );
    canvas.drawCircle(
      Offset(4, 4 - step),
      3,
      Paint()..color = const Color(0xFF453D33),
    );
    canvas.drawCircle(Offset.zero, 8, Paint()..color = const Color(0xFF58764E));
    canvas.drawCircle(Offset.zero, 5, Paint()..color = const Color(0xFFC8AD7C));
    canvas.drawLine(
      const Offset(7, 0),
      const Offset(18, 6),
      Paint()
        ..color = const Color(0xFFE5D0A4)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(18, 6),
      const Offset(22, 1),
      Paint()
        ..color = const Color(0xFFE5D0A4)
        ..strokeWidth = 2,
    );
  }
}

class WorkerActor extends MineActor {
  final Deposit deposit;
  final int index;
  double time = 0;
  WorkerActor(super.scene, this.deposit, this.index);
  @override
  void update(double dt) {
    super.update(dt);
    if (scene.simulation.active) time += dt * scene.playbackSpeed;
    final end = deposit.exposedPoint ?? deposit.point;
    final start = scene.simulation.factory.nearestGate(end).point;
    if (index >= deposit.workforce.length) {
      removeFromParent();
      return;
    }
    final travel = start.distance(end) / .10;
    final progress =
        (1 -
                (deposit.workforce[index].arrivesAt -
                        scene.simulation.elapsed) /
                    max(.01, travel))
            .clamp(0, 1)
            .toDouble();
    position = scene.field.location(start.towards(end, progress));
    if (progress >= 1) {
      position += Vector2(cos(index * 2.4) * 15, sin(index * 2.4) * 12);
    }
  }

  @override
  void render(Canvas canvas) {
    if (index >= deposit.workforce.length) return;
    final arrived =
        scene.simulation.elapsed >= deposit.workforce[index].arrivesAt;
    final working =
        arrived && deposit.remaining > .001 && deposit.storage.ore.free > .001;
    canvas.drawCircle(Offset.zero, 7, Paint()..color = Colors.black12);
    canvas.drawCircle(
      Offset(0, arrived ? 0 : sin(time * 18) * 1.5),
      5,
      Paint()..color = const Color(0xFF4B6682),
    );
    canvas.drawCircle(Offset.zero, 4, Paint()..color = const Color(0xFFEAC464));
    canvas.save();
    canvas.translate(5, 0);
    canvas.rotate(working ? sin(time * 9 + index) * .7 : -.5);
    canvas.drawLine(
      Offset.zero,
      const Offset(10, 0),
      Paint()
        ..color = const Color(0xFFC8AB82)
        ..strokeWidth = 2,
    );
    canvas.drawLine(
      const Offset(10, -4),
      const Offset(10, 4),
      Paint()
        ..color = const Color(0xFFCCD0CB)
        ..strokeWidth = 2,
    );
    canvas.restore();
  }
}

class DigDust extends MineActor {
  final Point2 point;
  double age = 0;
  DigDust(super.scene, this.point) : super();
  @override
  void update(double dt) {
    super.update(dt);
    age += dt;
    position = scene.field.location(point);
    if (age > .6) removeFromParent();
  }

  @override
  void render(Canvas canvas) {
    for (var i = 0; i < 12; i++) {
      final a = i * pi / 6;
      canvas.drawCircle(
        Offset(cos(a) * age * 40, sin(a) * age * 25),
        max(0, 3 - age * 5),
        Paint()
          ..color = const Color(
            0xFFE4D6AD,
          ).withValues(alpha: max(0, 1 - age / .6)),
      );
    }
  }
}

void label(
  Canvas canvas,
  String text,
  Offset position,
  Color color,
  double size,
) {
  final painter = TextPainter(
    text: TextSpan(
      text: text,
      style: TextStyle(
        color: color,
        fontSize: size,
        fontWeight: FontWeight.w600,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  painter.paint(canvas, position);
}

class MineStorageActor extends MineActor {
  final MineShaft mine;
  MineStorageActor(super.scene, this.mine);
  @override
  void update(double dt) {
    super.update(dt);
    position = scene.field.location(mine.storagePoint);
  }

  @override
  void render(Canvas canvas) {
    canvas.drawRect(
      const Rect.fromLTWH(-10, -7, 20, 14),
      Paint()..color = const Color(0xFF614F38),
    );
    final fill = mine.stock / mine.storage.capacity;
    canvas.drawRect(
      Rect.fromLTWH(-8, 5 - fill * 10, 16, fill * 10),
      Paint()..color = const Color(0xFFBBA07A),
    );
    for (var i = 1; i < mine.storage.level; i++) {
      canvas.drawLine(
        Offset(-9 + i * 6, -7),
        Offset(-9 + i * 6, 7),
        Paint()
          ..color = const Color(0xFFD7BE88)
          ..strokeWidth = 1,
      );
    }
  }
}

class BrokerWagonActor extends MineActor {
  final Merchant merchant;
  double time = 0;
  BrokerWagonActor(super.scene, this.merchant);
  @override
  void update(double dt) {
    super.update(dt);
    if (scene.simulation.active) time += dt;
    position = scene.field.location(merchant.point);
    final a = scene.field.location(merchant.shop),
        b = scene.field.location(merchant.dock);
    angle =
        atan2(b.y - a.y, b.x - a.x) +
        (merchant.state == MerchantState.toShop ? pi : 0);
  }

  @override
  void render(Canvas canvas) {
    // Brokers travel on foot; mined ore moves through the conveyor network.
    final coat = Paint()
      ..color = merchant.id == 0
          ? const Color(0xFF486F82)
          : const Color(0xFF8B5B4E);
    canvas.drawCircle(const Offset(0, -7), 5, Paint()..color = const Color(0xFFE4B98B));
    canvas.drawRRect(
      RRect.fromRectAndRadius(const Rect.fromLTWH(-5, -2, 10, 13), const Radius.circular(3)),
      coat,
    );
    canvas.drawLine(const Offset(-3, 10), const Offset(-4, 16),
        Paint()..color = const Color(0xFF303030)..strokeWidth = 3);
    canvas.drawLine(const Offset(3, 10), const Offset(4, 16),
        Paint()..color = const Color(0xFF303030)..strokeWidth = 3);
    if (merchant.cargo.amount > 0) {
      canvas.drawCircle(const Offset(9, 5), 5, Paint()..color = const Color(0xFFF3CA5E));
    }
  }
}

class RefineryActor extends MineActor {
  double time = 0;
  RefineryActor(super.scene) {
    scale.setValues(1, 1);
    priority = 15;
  }
  @override
  void update(double dt) {
    super.update(dt);
    position = scene.field.location(MiningGame.entrance) + Vector2(0, -22);
    if (scene.simulation.active &&
        scene.simulation.rawStored > 0 &&
        scene.simulation.factory.gold.free > 0) {
      time += dt;
    }
  }

  @override
  void render(Canvas canvas) {
    canvas.save();
    canvas.rotate(time * 2);
    for (var i = 0; i < 8; i++) {
      canvas.rotate(pi / 4);
      canvas.drawRect(
        const Rect.fromLTWH(9, -3, 7, 6),
        Paint()..color = const Color(0xFFD6C18E),
      );
    }
    canvas.drawCircle(
      Offset.zero,
      10,
      Paint()..color = const Color(0xFFD6C18E),
    );
    canvas.drawCircle(Offset.zero, 4, Paint()..color = const Color(0xFF5E6F50));
    canvas.restore();
  }
}
