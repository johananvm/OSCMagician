import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models.dart';

/// Renders a single control and handles play-mode gestures.
class ControlWidget extends StatefulWidget {
  const ControlWidget({
    super.key,
    required this.control,
    required this.enabled,
    required this.onChanged,
  });

  final OscControl control;

  /// False in edit mode: gestures are used for moving instead.
  final bool enabled;
  final void Function(double value) onChanged;

  @override
  State<ControlWidget> createState() => _ControlWidgetState();
}

class _ControlWidgetState extends State<ControlWidget> {
  OscControl get c => widget.control;

  void _setNormalized(double n) {
    final clamped = n.clamp(0.0, 1.0);
    widget.onChanged(c.min + (c.max - c.min) * clamped);
  }

  @override
  Widget build(BuildContext context) {
    if (c.type == ControlType.text) return _buildText();
    if (c.type == ControlType.shape) return _buildShape();

    final body = switch (c.type) {
      ControlType.hSlider => _buildHSlider(),
      ControlType.vSlider => _buildVSlider(),
      ControlType.pushButton => _buildButton(_ButtonKind.push),
      ControlType.holdButton => _buildButton(_ButtonKind.hold),
      ControlType.toggleButton => _buildButton(_ButtonKind.toggle),
      ControlType.knob => _buildKnob(),
      ControlType.hMeter => _buildMeter(horizontal: true),
      ControlType.vMeter => _buildMeter(horizontal: false),
      ControlType.text || ControlType.shape => const SizedBox(),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: c.color.withValues(alpha: 0.6)),
      ),
      padding: const EdgeInsets.all(4),
      child: LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            // Hide the label when the cell is too short to fit it.
            if (c.name.isNotEmpty && constraints.maxHeight >= 32)
              Text(
                c.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: c.color,
                  fontWeight: FontWeight.w600,
                ),
              ),
            Expanded(child: body),
          ],
        ),
      ),
    );
  }

  // ---- sliders ----

  Widget _buildHSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final w = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: widget.enabled
              ? (d) => _setNormalized(d.localPosition.dx / w)
              : null,
          onHorizontalDragUpdate: widget.enabled
              ? (d) => _setNormalized(d.localPosition.dx / w)
              : null,
          onTapDown: widget.enabled
              ? (d) => _setNormalized(d.localPosition.dx / w)
              : null,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SliderPainter(c.normalized, c.color, horizontal: true),
          ),
        );
      },
    );
  }

  Widget _buildVSlider() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final h = constraints.maxHeight;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onVerticalDragStart: widget.enabled
              ? (d) => _setNormalized(1 - d.localPosition.dy / h)
              : null,
          onVerticalDragUpdate: widget.enabled
              ? (d) => _setNormalized(1 - d.localPosition.dy / h)
              : null,
          onTapDown: widget.enabled
              ? (d) => _setNormalized(1 - d.localPosition.dy / h)
              : null,
          child: CustomPaint(
            size: Size.infinite,
            painter: _SliderPainter(c.normalized, c.color, horizontal: false),
          ),
        );
      },
    );
  }

  // ---- meter (display only, driven by incoming OSC) ----

  Widget _buildMeter({required bool horizontal}) {
    return CustomPaint(
      size: Size.infinite,
      painter: _MeterPainter(c.normalized, horizontal: horizontal),
    );
  }

  // ---- decorations ----

  Widget _buildText() {
    // Show a placeholder in edit mode so an empty label can still be found.
    final empty = c.name.isEmpty;
    if (empty && widget.enabled) return const SizedBox.expand();
    return LayoutBuilder(
      builder: (context, constraints) => Center(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            empty ? 'Label' : c.name,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: (constraints.maxHeight * 0.5).clamp(10.0, 64.0),
              color: empty ? c.color.withValues(alpha: 0.4) : c.color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildShape() {
    return Container(
      decoration: BoxDecoration(
        color: c.color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: c.color, width: 2),
      ),
      padding: const EdgeInsets.fromLTRB(8, 2, 8, 2),
      alignment: Alignment.topLeft,
      child: c.name.isEmpty
          ? null
          : Text(
              c.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                color: c.color,
                fontWeight: FontWeight.w600,
              ),
            ),
    );
  }

  // ---- buttons ----
  // Push: sends max on press and min on release (quick on/off per tap).
  // Hold: sends max while held, min on release (works for long presses).
  // Toggle: alternates between min and max per tap.

  Widget _buildButton(_ButtonKind kind) {
    final on = c.isOn;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: !widget.enabled
          ? null
          : (_) {
              switch (kind) {
                case _ButtonKind.push:
                case _ButtonKind.hold:
                  widget.onChanged(c.max);
                case _ButtonKind.toggle:
                  widget.onChanged(on ? c.min : c.max);
              }
            },
      onTapUp: !widget.enabled
          ? null
          : (_) {
              if (kind != _ButtonKind.toggle) widget.onChanged(c.min);
            },
      onTapCancel: !widget.enabled
          ? null
          : () {
              if (kind != _ButtonKind.toggle) widget.onChanged(c.min);
            },
      onLongPressEnd: !widget.enabled || kind == _ButtonKind.toggle
          ? null
          : (_) => widget.onChanged(c.min),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 80),
        decoration: BoxDecoration(
          color: on ? c.color : c.color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(6),
        ),
        alignment: Alignment.center,
        child: Icon(
          switch (kind) {
            _ButtonKind.push => Icons.radio_button_checked,
            _ButtonKind.hold => Icons.touch_app,
            _ButtonKind.toggle => Icons.power_settings_new,
          },
          color: on ? Colors.black87 : c.color,
          size: 20,
        ),
      ),
    );
  }

  // ---- knob ----

  Widget _buildKnob() {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onVerticalDragUpdate: !widget.enabled
          ? null
          : (d) => _setNormalized(c.normalized - d.delta.dy / 150),
      child: CustomPaint(
        size: Size.infinite,
        painter: _KnobPainter(
          c.normalized,
          c.color,
          label: c.value.toStringAsFixed(2),
        ),
      ),
    );
  }
}

enum _ButtonKind { push, hold, toggle }

class _SliderPainter extends CustomPainter {
  _SliderPainter(this.normalized, this.color, {required this.horizontal});

  final double normalized;
  final Color color;
  final bool horizontal;

  @override
  void paint(Canvas canvas, Size size) {
    final track = Paint()..color = color.withValues(alpha: 0.15);
    final fill = Paint()..color = color;
    final r = RRect.fromRectAndRadius(
      Offset.zero & size,
      const Radius.circular(4),
    );
    canvas.clipRRect(r);
    canvas.drawRect(Offset.zero & size, track);
    if (horizontal) {
      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width * normalized, size.height),
        fill,
      );
    } else {
      final h = size.height * normalized;
      canvas.drawRect(Rect.fromLTWH(0, size.height - h, size.width, h), fill);
    }
  }

  @override
  bool shouldRepaint(_SliderPainter old) =>
      old.normalized != normalized || old.color != color;
}

class _MeterPainter extends CustomPainter {
  _MeterPainter(this.normalized, {required this.horizontal});

  final double normalized;
  final bool horizontal;

  // Green for most of the range, then yellow, then red at the top.
  static const _colors = [
    Colors.green,
    Colors.green,
    Colors.yellow,
    Colors.red,
  ];
  static const _stops = [0.0, 0.6, 0.85, 1.0];

  @override
  void paint(Canvas canvas, Size size) {
    final full = Offset.zero & size;
    canvas.clipRRect(RRect.fromRectAndRadius(full, const Radius.circular(4)));
    canvas.drawRect(full, Paint()..color = Colors.white10);

    final gradient = LinearGradient(
      begin: horizontal ? Alignment.centerLeft : Alignment.bottomCenter,
      end: horizontal ? Alignment.centerRight : Alignment.topCenter,
      colors: _colors,
      stops: _stops,
    );
    final level = horizontal
        ? Rect.fromLTWH(0, 0, size.width * normalized, size.height)
        : Rect.fromLTWH(
            0,
            size.height * (1 - normalized),
            size.width,
            size.height * normalized,
          );
    // The shader spans the whole meter so colors stay fixed by position.
    canvas.drawRect(level, Paint()..shader = gradient.createShader(full));
  }

  @override
  bool shouldRepaint(_MeterPainter old) =>
      old.normalized != normalized || old.horizontal != horizontal;
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.normalized, this.color, {required this.label});

  final double normalized;
  final Color color;
  final String label;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 6;
    if (radius <= 0) return;

    const startAngle = 3 * math.pi / 4; // 135°
    const sweepTotal = 3 * math.pi / 2; // 270°

    final trackPaint = Paint()
      ..color = color.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;
    final valuePaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepTotal, false, trackPaint);
    canvas.drawArc(
      rect,
      startAngle,
      sweepTotal * normalized,
      false,
      valuePaint,
    );

    // Pointer line
    final angle = startAngle + sweepTotal * normalized;
    final pointer = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      center,
      center + Offset(math.cos(angle), math.sin(angle)) * (radius - 8),
      pointer,
    );

    final tp = TextPainter(
      text: TextSpan(
        text: label,
        style: TextStyle(color: color, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, center + Offset(-tp.width / 2, radius - tp.height + 4));
  }

  @override
  bool shouldRepaint(_KnobPainter old) =>
      old.normalized != normalized || old.color != color || old.label != label;
}
