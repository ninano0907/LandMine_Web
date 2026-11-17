import 'dart:async';
import 'package:flutter/material.dart';
import 'robot_3d.dart';

class RobotStudio extends StatefulWidget {
  const RobotStudio({super.key});
  @override
  State<RobotStudio> createState() => _RobotStudioState();
}

class _RobotStudioState extends State<RobotStudio> {
  late final Timer timer;
  final clock = Stopwatch()..start();
  String clip = 'Mine';
  double yaw = 0;
  bool playing = true;
  double time = 0, last = 0;
  @override
  void initState() {
    super.initState();
    RobotModel.load().then((_) {
      if (mounted) setState(() {});
    });
    timer = Timer.periodic(const Duration(milliseconds: 33), (_) {
      final now = clock.elapsedMicroseconds / 1e6;
      if (mounted) {
        setState(() {
          if (playing) time += now - last;
          last = now;
        });
      }
    });
  }

  @override
  void dispose() {
    timer.cancel();
    clock.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: const Color(0xffe7d4ae),
    appBar: AppBar(
      title: const Text('철마 · 3D 동작'),
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
              onPanUpdate: (d) => setState(() => yaw += d.delta.dx * .012),
              child: CustomPaint(
                size: Size.infinite,
                painter: _RobotStudioPainter(clip, time, yaw),
              ),
            ),
          ),
          const Text(
            '좌우로 드래그하면 모델을 돌려 볼 수 있습니다',
            style: TextStyle(fontSize: 11, color: Color(0xff705a3d)),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 10,
              children: [
                for (final mode in [
                  ('Idle', '대기'),
                  ('Walk', '거미 보행'),
                  ('Mine', '드릴 · 굴착'),
                ])
                  FilledButton.tonal(
                    onPressed: () => setState(() {
                      clip = mode.$1;
                      time = 0;
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
  _RobotStudioPainter(this.clip, this.time, this.yaw);
  final String clip;
  final double time, yaw;
  @override
  void paint(Canvas c, Size size) {
    final model = RobotModel.cached;
    if (model == null) return;
    final scale = (size.width / 360).clamp(.5, 2.3);
    final at = Offset(size.width * .5, size.height * .65);
    final p = Paint()
      ..color = const Color(0x4453442b)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
    c.drawOval(
      Rect.fromCenter(center: at, width: 250 * scale, height: 95 * scale),
      p,
    );
    model.paint(c, at, clip: clip, poseTime: time, yaw: yaw, modelScale: scale);
  }

  @override
  bool shouldRepaint(covariant _RobotStudioPainter oldDelegate) => true;
}
