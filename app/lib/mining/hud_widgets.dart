import 'package:flutter/material.dart';

const hudInk = Color(0xFF493D2B);
const hudPaper = Color(0xFFF3E6C6);
const hudWood = Color(0xFF9C784C);

class PaperPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  const PaperPanel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
  });
  @override
  Widget build(BuildContext context) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: hudPaper,
      border: Border.all(color: const Color(0xFFAF9468), width: 1.5),
      borderRadius: BorderRadius.circular(3),
      boxShadow: const [
        BoxShadow(color: Colors.black26, offset: Offset(0, 3), blurRadius: 2),
      ],
    ),
    child: child,
  );
}

class PurchaseTool extends StatelessWidget {
  final IconData icon;
  final String label, price, tooltip;
  final VoidCallback? onTap, onUpgrade;
  final bool selected;
  const PurchaseTool({
    super.key,
    required this.icon,
    required this.label,
    required this.price,
    required this.tooltip,
    this.onTap,
    this.onUpgrade,
    this.selected = false,
  });
  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: SizedBox(
      width: 62,
      height: 82,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Opacity(
                  opacity: 1,
                  child: Column(
                    children: [
                      const SizedBox(height: 5),
                      Container(
                        width: 41,
                        height: 36,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: selected
                              ? const Color(0xFFD9C48F)
                              : const Color(0xFFF4E8CE),
                          border: Border.all(
                            color: selected ? hudInk : const Color(0xFFD3C3A3),
                          ),
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Icon(icon, color: hudInk, size: 28),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        price,
                        style: const TextStyle(
                          color: hudInk,
                          fontSize: 14,
                          height: 1.1,
                          fontFamily: 'serif',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        label,
                        maxLines: 1,
                        style: const TextStyle(
                          color: Color(0xFF776344),
                          fontSize: 10,
                          height: 1.1,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          if (onUpgrade != null)
            Positioned(
              right: -2,
              top: 0,
              child: Tooltip(
                message: '$label 업그레이드',
                child: Material(
                  color: const Color(0xFF8E6A3B),
                  shape: const CircleBorder(),
                  child: InkWell(
                    onTap: onUpgrade,
                    customBorder: const CircleBorder(),
                    child: const SizedBox(
                      width: 22,
                      height: 22,
                      child: Icon(
                        Icons.keyboard_double_arrow_up,
                        size: 15,
                        color: Color(0xFFFFF4D8),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class FrontierButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool active;
  const FrontierButton(
    this.text, {
    super.key,
    this.onPressed,
    this.active = false,
  });
  @override
  Widget build(BuildContext context) => Material(
    color: onPressed == null
        ? const Color(0xFFDDD1B7)
        : active
        ? const Color(0xFF71583A)
        : const Color(0xFFB89968),
    borderRadius: BorderRadius.circular(3),
    child: InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(3),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: const Color(0xFF82633D)),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: onPressed == null
                ? const Color(0xFF9C907A)
                : active
                ? const Color(0xFFFFF3D6)
                : hudInk,
          ),
        ),
      ),
    ),
  );
}

class MineMinimap extends CustomPainter {
  final Rect viewport;
  final List<Offset> mines;
  final List<List<Offset>> tracks;
  const MineMinimap({
    required this.viewport,
    required this.mines,
    required this.tracks,
  });
  @override
  void paint(Canvas canvas, Size size) {
    Offset point(Offset p) => Offset(p.dx * size.width, p.dy * size.height);
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF9C8B6E),
    );
    for (final line in tracks) {
      canvas.drawLine(
        point(line[0]),
        point(line[1]),
        Paint()
          ..color = const Color(0xFFF4E7C7)
          ..strokeWidth = 1,
      );
    }
    for (final p in mines) {
      canvas.drawCircle(point(p), 2, Paint()..color = const Color(0xFFF4CB71));
    }
    canvas.drawRect(
      Rect.fromLTWH(
        viewport.left * size.width,
        viewport.top * size.height,
        viewport.width * size.width,
        viewport.height * size.height,
      ),
      Paint()
        ..color = const Color(0xFFFDF5DE)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(covariant MineMinimap oldDelegate) => true;
}

class WorkforceControl extends StatefulWidget {
  final int mineId, workers;
  final bool canIncrease, canDecrease;
  final bool Function() increase, decrease;
  const WorkforceControl({
    super.key,
    required this.mineId,
    required this.workers,
    required this.canIncrease,
    required this.canDecrease,
    required this.increase,
    required this.decrease,
  });
  @override
  State<WorkforceControl> createState() => _WorkforceControlState();
}

class _WorkforceControlState extends State<WorkforceControl> {
  double remainder = 0;
  void drag(double delta) {
    remainder -= delta;
    while (remainder >= 14) {
      if (!widget.increase()) {
        remainder = 0;
        break;
      }
      remainder -= 14;
    }
    while (remainder <= -14) {
      if (!widget.decrease()) {
        remainder = 0;
        break;
      }
      remainder += 14;
    }
  }

  @override
  Widget build(BuildContext context) => GestureDetector(
    behavior: HitTestBehavior.opaque,
    onVerticalDragStart: (_) => remainder = 0,
    onVerticalDragUpdate: (event) => drag(event.delta.dy),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          key: ValueKey('assign-${widget.mineId}'),
          onTap: widget.canIncrease ? () => widget.increase() : null,
          child: SizedBox(
            width: 28,
            height: 14,
            child: Icon(
              Icons.arrow_drop_up,
              size: 17,
              color: widget.canIncrease ? hudInk : const Color(0xFFC4B99F),
            ),
          ),
        ),
        SizedBox(
          height: 16,
          child: Center(
            child: Text(
              '${widget.workers}',
              key: ValueKey('workers-${widget.mineId}'),
              style: const TextStyle(
                fontSize: 12,
                height: 1,
                fontWeight: FontWeight.bold,
                color: hudInk,
              ),
            ),
          ),
        ),
        InkWell(
          key: ValueKey('remove-${widget.mineId}'),
          onTap: widget.canDecrease ? () => widget.decrease() : null,
          child: SizedBox(
            width: 28,
            height: 14,
            child: Icon(
              Icons.arrow_drop_down,
              size: 17,
              color: widget.canDecrease ? hudInk : const Color(0xFFC4B99F),
            ),
          ),
        ),
      ],
    ),
  );
}
