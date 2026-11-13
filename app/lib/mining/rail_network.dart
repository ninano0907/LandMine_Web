import 'geometry.dart';
import 'economy.dart';

class TrackNode {
  final int id, gateId;
  final Point2 point;
  final int? parentId;
  final TrackSegment? incoming;
  TrackNode(this.id, this.point, this.parentId, this.incoming, this.gateId);
}

class TrackSegment {
  final int id, fromId, toId;
  final Point2 start, end;
  double construction = 0;
  TrackSegment(this.id, this.fromId, this.toId, this.start, this.end);
  double get length => start.distance(end);
  bool get ready => construction >= 1;
}

class Rail {
  final int depositId, gateId;
  final List<Point2> path;
  final List<TrackSegment> segments;
  Rail(this.depositId, this.path, this.segments, this.gateId);
  Point2 get start => path.first;
  Point2 get end => path.last;
  double get length => segments.fold(0, (sum, s) => sum + s.length);
  double get construction => length == 0
      ? 0
      : segments.fold(0.0, (sum, s) => sum + s.length * s.construction) /
            length;
  bool get ready => segments.every((s) => s.ready);
  Point2 pointAt(double t) {
    var distance = t.clamp(0, 1) * length;
    for (var i = 0; i < segments.length; i++) {
      final s = segments[i];
      if (distance <= s.length || i == segments.length - 1) {
        return s.start.towards(
          s.end,
          s.length == 0 ? 0 : (distance / s.length).clamp(0, 1).toDouble(),
        );
      }
      distance -= s.length;
    }
    return end;
  }
}

class RailNetwork {
  final List<TrackNode> nodes = [];
  final List<TrackSegment> segments = [];
  final List<Rail> routes = [];
  RailNetwork(List<FactoryGate> gates) {
    for (final g in gates) {
      nodes.add(TrackNode(g.id, g.point, null, null, g.id));
    }
  }
  Rail? routeFor(int id) {
    for (final r in routes) {
      if (r.depositId == id) return r;
    }
    return null;
  }

  bool crosses(int from, Point2 end) =>
      crossesFactory(nodes[from].point, end) ||
      segments.any(
        (s) => segmentsConflict(nodes[from].point, end, s.start, s.end),
      );
  TrackNode extend(int from, Point2 end) {
    final parent = nodes[from];
    final segment = TrackSegment(
      segments.length,
      from,
      nodes.length,
      parent.point,
      end,
    );
    segments.add(segment);
    final node = TrackNode(nodes.length, end, from, segment, parent.gateId);
    nodes.add(node);
    return node;
  }

  Rail attachMine(int mineId, TrackNode leaf) {
    final points = <Point2>[], path = <TrackSegment>[];
    var node = leaf;
    while (true) {
      points.add(node.point);
      if (node.incoming != null) path.add(node.incoming!);
      if (node.parentId == null) break;
      node = nodes[node.parentId!];
    }
    final route = Rail(
      mineId,
      points.reversed.toList(),
      path.reversed.toList(),
      leaf.gateId,
    );
    routes.add(route);
    return route;
  }

  void update(double dt) {
    for (final s in segments) {
      if (s.ready) continue;
      final parent = nodes[s.fromId].incoming;
      if (parent != null && !parent.ready) continue;
      s.construction = (s.construction + dt / (1 + s.length * 8))
          .clamp(0, 1)
          .toDouble();
    }
  }
}
