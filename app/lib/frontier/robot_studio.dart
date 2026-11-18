import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'dart:math' as math;
import 'robot_3d.dart';

class RobotStudio extends StatefulWidget {
  const RobotStudio({super.key});
  @override
  State<RobotStudio> createState() => _RobotStudioState();
}

class _RobotStudioState extends State<RobotStudio>
    with SingleTickerProviderStateMixin {
  late final Ticker ticker;
  final frames = ValueNotifier<double>(0);
  String clip = 'Mine';
  double zoom = 1, gestureZoom = 1;
  bool playing = true;
  double time = 0;
  Duration last = Duration.zero;
  @override
  void initState() {
    super.initState();
    RobotModel.load()
        .then((_) {
          if (mounted) setState(() {});
        })
        .catchError((Object error) {
          debugPrint('Robot model: $error');
        });
    ticker = createTicker((elapsed) {
      final dt = (elapsed - last).inMicroseconds / 1e6;
      last = elapsed;
      if (playing) {
        time += dt.clamp(0, .1);
        frames.value = time;
      }
    })..start();
  }

  @override
  void dispose() {
    ticker.dispose();
    frames.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe7d4ae),
    appBar: AppBar(
      title: const Text('거미 기지 · 채굴 동작'),
      backgroundColor: const Color(0xffe7d4ae),
      actions: [
        IconButton(
          tooltip: '재생 / 멈춤',
          onPressed: () => setState(() => playing = !playing),
          icon: Icon(playing ? Icons.pause : Icons.play_arrow),
        ),
      ],
    ),
    body: SafeArea(
      child: Column(
        children: [
          Expanded(
            child: GestureDetector(
              onScaleStart: (_) => gestureZoom = zoom,
              onScaleUpdate: (d) => setState(
                () => zoom = (gestureZoom * d.scale).clamp(.65, 2.5),
              ),
              child: RepaintBoundary(
                child: CustomPaint(
                  size: Size.infinite,
                  painter: _RobotStudioPainter(clip, () => time, zoom, frames),
                ),
              ),
            ),
          ),
          const Text(
            '두 손가락으로 확대해서 기계의 디테일과 채굴 동작을 살펴보세요',
            style: TextStyle(fontSize: 11, color: Color(0xff705a3d)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              children: [
                for (final mode in [
                  ('Idle', '대기'),
                  ('Mine', '드릴 · 굴삭기 · 컨베이어'),
                ])
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      clip = mode.$1;
                      time = 0;
                      frames.value = 0;
                    }),
                    child: Text(mode.$2),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _RobotStudioPainter extends CustomPainter {
  _RobotStudioPainter(
    this.clip,
    this.timeProvider,
    this.zoom,
    Listenable repaint,
  ) : super(repaint: repaint);
  final String clip;
  final double Function() timeProvider;
  final double zoom;
  double get time => timeProvider();
  @override
  void paint(Canvas c, Size size) {
    final model = RobotModel.cached;
    if (model == null) return;
    final scale = math.min(size.width / 360, size.height / 300) * zoom;
    final at = Offset(size.width * .5, size.height * .65);
    c.save();
    c.clipRect(Offset.zero & size);
    model.paint(c, at, clip: clip, poseTime: time, modelScale: scale);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant _RobotStudioPainter oldDelegate) => true;
}
