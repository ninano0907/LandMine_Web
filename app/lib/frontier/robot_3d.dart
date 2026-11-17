import 'dart:convert';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator +(_V b) => _V(x + b.x, y + b.y, z + b.z);
  _V operator -(_V b) => _V(x - b.x, y - b.y, z - b.z);
  _V operator *(double n) => _V(x * n, y * n, z * n);
  double dot(_V b) => x * b.x + y * b.y + z * b.z;
  _V cross(_V b) => _V(y * b.z - z * b.y, z * b.x - x * b.z, x * b.y - y * b.x);
  _V get unit {
    final n = math.sqrt(dot(this));
    return n < 1e-9 ? this : this * (1 / n);
  }
}

class _Transform {
  _Transform(this.t, this.q, this.s);
  final List<double> t, q, s;
  factory _Transform.parse(Map<String, dynamic> data) => _Transform(
    _numbers(data['translation'] ?? [0, 0, 0]),
    _numbers(data['rotation'] ?? [0, 0, 0, 1]),
    _numbers(data['scale'] ?? [1, 1, 1]),
  );
  static List<double> _numbers(dynamic values) =>
      (values as List).map((x) => (x as num).toDouble()).toList();
  static _Transform mix(
    _Transform base,
    Map<String, dynamic> a,
    Map<String, dynamic> b,
    double f,
  ) {
    List<double> blend(String key, List<double> defaults) {
      final av = a[key] as List?;
      final bv = b[key] as List?;
      if (av == null) return defaults;
      var sign = 1.0;
      if (key == 'rotation' &&
          List.generate(
                4,
                (i) => (av[i] as num) * (bv![i] as num),
              ).reduce((a, b) => a + b) <
              0) {
        sign = -1;
      }
      final result = List<double>.generate(
        av.length,
        (i) =>
            (av[i] as num).toDouble() * (1 - f) +
            (bv![i] as num).toDouble() * f * sign,
      );
      if (key == 'rotation') {
        final length = math.sqrt(result.fold(0.0, (s, v) => s + v * v));
        return result.map((v) => v / length).toList();
      }
      return result;
    }

    return _Transform(
      blend('translation', base.t),
      blend('rotation', base.q),
      blend('scale', base.s),
    );
  }

  _Matrix matrix() {
    final x = q[0], y = q[1], z = q[2], w = q[3];
    return _Matrix([
      (1 - 2 * y * y - 2 * z * z) * s[0],
      (2 * x * y - 2 * z * w) * s[1],
      (2 * x * z + 2 * y * w) * s[2],
      t[0],
      (2 * x * y + 2 * z * w) * s[0],
      (1 - 2 * x * x - 2 * z * z) * s[1],
      (2 * y * z - 2 * x * w) * s[2],
      t[1],
      (2 * x * z - 2 * y * w) * s[0],
      (2 * y * z + 2 * x * w) * s[1],
      (1 - 2 * x * x - 2 * y * y) * s[2],
      t[2],
      0,
      0,
      0,
      1,
    ]);
  }
}

class _Matrix {
  _Matrix(this.m);
  final List<double> m;
  _Matrix operator *(_Matrix b) => _Matrix(
    List.generate(16, (i) {
      final r = i ~/ 4, c = i % 4;
      var v = 0.0;
      for (var k = 0; k < 4; k++) {
        v += m[r * 4 + k] * b.m[k * 4 + c];
      }
      return v;
    }),
  );
  _V point(_V v) => _V(
    m[0] * v.x + m[1] * v.y + m[2] * v.z + m[3],
    m[4] * v.x + m[5] * v.y + m[6] * v.z + m[7],
    m[8] * v.x + m[9] * v.y + m[10] * v.z + m[11],
  );
  late final List<double> _normalMatrix = () {
    final a = m[0],
        b = m[1],
        c = m[2],
        d = m[4],
        e = m[5],
        f = m[6],
        g = m[8],
        h = m[9],
        i = m[10];
    final determinant =
        a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (determinant.abs() < 1e-12) return <double>[1, 0, 0, 0, 1, 0, 0, 0, 1];
    return [
      e * i - f * h,
      f * g - d * i,
      d * h - e * g,
      c * h - b * i,
      a * i - c * g,
      b * g - a * h,
      b * f - c * e,
      c * d - a * f,
      a * e - b * d,
    ].map((v) => v / determinant).toList();
  }();
  _V normal(_V v) {
    final n = _normalMatrix;
    return _V(
      n[0] * v.x + n[1] * v.y + n[2] * v.z,
      n[3] * v.x + n[4] * v.y + n[5] * v.z,
      n[6] * v.x + n[7] * v.y + n[8] * v.z,
    ).unit;
  }
}

class _Mesh {
  _Mesh(Map<String, dynamic> data)
    : vertices = _vectors(data['positions']),
      normals = _vectors(data['normals']),
      indices = (data['indices'] as List).cast<int>(),
      color = Color(
        int.parse((data['color'] as String).replaceFirst('#', 'ff'), radix: 16),
      );
  final List<_V> vertices, normals;
  final List<int> indices;
  final Color color;
  static List<_V> _vectors(dynamic values) {
    final v = values as List;
    return [
      for (var i = 0; i < v.length; i += 3)
        _V(
          (v[i] as num).toDouble(),
          (v[i + 1] as num).toDouble(),
          (v[i + 2] as num).toDouble(),
        ),
    ];
  }
}

class _Node {
  _Node(Map<String, dynamic> data)
    : name = data['name'] as String,
      base = _Transform.parse(data),
      mesh = data['mesh'] as int?,
      children = (data['children'] as List).cast<int>();
  final String name;
  final _Transform base;
  final int? mesh;
  final List<int> children;
}

class _Triangle {
  _Triangle(this.depth, this.points, this.colors);
  final double depth;
  final List<Offset> points;
  final List<Color> colors;
}

/// True 3D triangle geometry with rigid-node animation, projected into the
/// existing Flutter battlefield. No WebView, network dependency or 2D sprite rig.
class RobotModel {
  RobotModel.fromJson(Map<String, dynamic> data)
    : _meshes = (data['meshes'] as List)
          .map((m) => _Mesh(m as Map<String, dynamic>))
          .toList(),
      _nodes = (data['nodes'] as List)
          .map((n) => _Node(n as Map<String, dynamic>))
          .toList(),
      clips = data['clips'] as Map<String, dynamic>,
      root = data['root'] as int;
  final List<_Mesh> _meshes;
  final List<_Node> _nodes;
  final Map<String, dynamic> clips;
  final int root;
  static RobotModel? cached;
  static Future<RobotModel>? _loading;
  static Future<RobotModel> load() {
    if (cached != null) return Future.value(cached);
    return _loading ??= rootBundle
        .loadString('assets/models/frontier_robot.scene.json')
        .then((source) {
          return cached = RobotModel.fromJson(
            jsonDecode(source) as Map<String, dynamic>,
          );
        })
        .catchError((Object error) {
          _loading = null;
          throw error;
        });
  }

  static const _view = _V(.48, .64, .6);
  static final _light = const _V(-.45, .86, .5).unit;
  static final _half = (_light + _view).unit;
  static const units = 27.0;
  static Offset project(double x, double y, double z) => Offset(
    (x * .8 - z * .6) * units,
    (x * .384 - y * .768 + z * .512) * units,
  );

  static double headingFor(Offset direction) => math.atan2(
    .512 * direction.dx + .6 * direction.dy,
    -.384 * direction.dx + .8 * direction.dy,
  );
  static double walkSeconds(double distance, double yaw, double scale) {
    final step =
        project(math.sin(yaw), 0, math.cos(yaw)).distance * scale * (2.5 / .68);
    return distance / math.max(.001, step);
  }

  Color _shade(Color base, _V n) {
    final brightness = .48 + .52 * math.max(0.0, n.dot(_light));
    final spec = math.pow(math.max(0.0, n.dot(_half)), 22) * .18;
    return Color.fromARGB(
      255,
      ((base.r * brightness + spec) * 255).round().clamp(0, 255),
      ((base.g * brightness + spec * .88) * 255).round().clamp(0, 255),
      ((base.b * brightness + spec * .67) * 255).round().clamp(0, 255),
    );
  }

  /// poseTime is local to each state. Idle, Walk and Mine have distinct clips.
  Rect paint(
    Canvas canvas,
    Offset contact, {
    required String clip,
    required double poseTime,
    double yaw = 0,
    double modelScale = 1,
    double? gunYaw,
  }) {
    final animation = clips[clip] as Map<String, dynamic>;
    final times = animation['times'] as List;
    final duration = (animation['duration'] as num).toDouble();
    final frame = (poseTime % duration) / duration * (times.length - 1);
    final left = frame.floor(),
        right = math.min(left + 1, times.length - 1),
        fraction = frame - left;
    final poses = animation['poses'] as List;
    final a = poses[left] as Map<String, dynamic>,
        b = poses[right] as Map<String, dynamic>;
    final yawMatrix = _Transform(
      [0, 0, 0],
      [0, math.sin(yaw / 2), 0, math.cos(yaw / 2)],
      [1, 1, 1],
    ).matrix();
    // The scene's bit tip remains at the actual game's drilling contact point.
    final tip = yawMatrix.point(const _V(0, .16, 1.35));
    final origin = contact - project(tip.x, tip.y, tip.z) * modelScale;
    final triangles = <_Triangle>[];
    var bounds = Rect.fromLTWH(contact.dx, contact.dy, 0, 0);
    void visit(int id, _Matrix parent) {
      final node = _nodes[id];
      final key = id.toString();
      final local = a.containsKey(key)
          ? _Transform.mix(
              node.base,
              a[key] as Map<String, dynamic>,
              b[key] as Map<String, dynamic>,
              fraction,
            )
          : node.base;
      final aimed = node.name == 'Turret pivot' && gunYaw != null
          ? _Transform(local.t, [
              0,
              math.sin((gunYaw - yaw) / 2),
              0,
              math.cos((gunYaw - yaw) / 2),
            ], local.s)
          : local;
      final matrix = parent * aimed.matrix();
      if (node.mesh != null) {
        final mesh = _meshes[node.mesh!];
        final positions = mesh.vertices.map(matrix.point).toList();
        final screen = positions
            .map((v) => origin + project(v.x, v.y, v.z) * modelScale)
            .toList();
        final colors = mesh.normals
            .map((n) => _shade(mesh.color, matrix.normal(n)))
            .toList();
        for (var i = 0; i < mesh.indices.length; i += 3) {
          final ia = mesh.indices[i],
              ib = mesh.indices[i + 1],
              ic = mesh.indices[i + 2];
          final va = positions[ia], vb = positions[ib], vc = positions[ic];
          final normal = (vb - va).cross(vc - va);
          if (normal.dot(_view) <= 1e-8) continue;
          final points = [screen[ia], screen[ib], screen[ic]];
          for (final point in points) {
            bounds = bounds.expandToInclude(
              Rect.fromLTWH(point.dx, point.dy, .01, .01),
            );
          }
          triangles.add(
            _Triangle((va + vb + vc).dot(_view), points, [
              colors[ia],
              colors[ib],
              colors[ic],
            ]),
          );
        }
      }
      for (final child in node.children) {
        visit(child, matrix);
      }
    }

    visit(root, yawMatrix);
    triangles.sort((a, b) => a.depth.compareTo(b.depth));
    final points = <Offset>[], colors = <Color>[];
    for (final t in triangles) {
      points.addAll(t.points);
      colors.addAll(t.colors);
    }
    if (points.isNotEmpty) {
      final vertices = ui.Vertices(
        ui.VertexMode.triangles,
        points,
        colors: colors,
      );
      canvas.drawVertices(
        vertices,
        BlendMode.modulate,
        Paint()
          ..color = Colors.white
          ..isAntiAlias = true,
      );
      vertices.dispose();
    }
    return bounds;
  }
}
