import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models/energia.dart';

class EnergyLineChart extends StatelessWidget {
  final List<EnergyHistoryPoint> points;
  final Color accentColor;
  final String title;
  final String subtitle;

  const EnergyLineChart({
    super.key,
    required this.points,
    required this.accentColor,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return _ChartShell(
        title: title,
        subtitle: subtitle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Brak danych historycznych.'),
        ),
      );
    }

    final values = points.map((p) => p.powerKw).toList();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final avgValue = values.reduce((a, b) => a + b) / values.length;
    final first = points.first.recordedAt;
    final last = points.last.recordedAt;

    return _ChartShell(
      title: title,
      subtitle: subtitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _Meta(label: 'Śr.', value: '${avgValue.toStringAsFixed(1)} kW'),
              _Meta(label: 'Min', value: '${minValue.toStringAsFixed(1)} kW'),
              _Meta(label: 'Max', value: '${maxValue.toStringAsFixed(1)} kW'),
              _Meta(label: 'Zakres', value: '${DateFormat('HH:mm').format(first)} – ${DateFormat('HH:mm').format(last)}'),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 220,
            child: CustomPaint(
              painter: _EnergyChartPainter(points: points, accentColor: accentColor),
              child: const SizedBox.expand(),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChartShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _ChartShell({required this.title, required this.subtitle, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  final String label;
  final String value;

  const _Meta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text('$label: $value', style: const TextStyle(fontSize: 12, color: Colors.black54));
  }
}

class _EnergyChartPainter extends CustomPainter {
  final List<EnergyHistoryPoint> points;
  final Color accentColor;

  _EnergyChartPainter({required this.points, required this.accentColor});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 52.0;
    const right = 12.0;
    const top = 18.0;
    const bottom = 42.0;
    final drawWidth = math.max(1.0, size.width - left - right);
    final drawHeight = math.max(1.0, size.height - top - bottom);
    final values = points.map((p) => p.powerKw).toList();
    final maxValue = values.reduce(math.max);
    final minValue = values.reduce(math.min);
    final range = math.max(0.1, maxValue - minValue);
    final stepX = points.length == 1 ? 0.0 : drawWidth / (points.length - 1);
    final labelStyle = TextStyle(
      color: Colors.black.withOpacity(.58),
      fontSize: 11,
      fontWeight: FontWeight.w500,
    );
    final axisStyle = TextStyle(
      color: Colors.black.withOpacity(.72),
      fontSize: 11,
      fontWeight: FontWeight.w600,
    );

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(.06)
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = top + (drawHeight * i / 2);
      canvas.drawLine(Offset(left, y), Offset(size.width - right, y), gridPaint);

      final value = maxValue - ((maxValue - minValue) * i / 2);
      _paintText(
        canvas,
        text: '${value.toStringAsFixed(1)} kW',
        offset: Offset(4, y - 8),
        style: labelStyle,
      );
    }

    _paintText(
      canvas,
      text: 'Pobór [kW]',
      offset: const Offset(6, 8),
      style: axisStyle,
    );

    final linePaint = Paint()
      ..color = accentColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [accentColor.withOpacity(.24), accentColor.withOpacity(.02)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, top, size.width, drawHeight));

    final path = Path();
    final area = Path();
    final dotPaint = Paint()..color = accentColor;
    Offset? previous;

    for (var i = 0; i < points.length; i++) {
      final value = points[i].powerKw;
      final normalized = (maxValue - minValue).abs() < 0.0001 ? 0.5 : (value - minValue) / range;
      final x = left + stepX * i;
      final y = top + drawHeight - (normalized * drawHeight);
      final current = Offset(x, y);

      if (i == 0) {
        path.moveTo(current.dx, current.dy);
        area.moveTo(current.dx, top + drawHeight);
        area.lineTo(current.dx, current.dy);
      } else {
        final prev = previous!;
        final c1 = Offset((prev.dx + current.dx) / 2, prev.dy);
        final c2 = Offset((prev.dx + current.dx) / 2, current.dy);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
        area.lineTo(current.dx, current.dy);
      }

      previous = current;
    }

    area.lineTo(previous!.dx, top + drawHeight);
    area.close();
    canvas.drawPath(area, fillPaint);
    canvas.drawPath(path, linePaint);

    for (var i = 0; i < points.length; i++) {
      final value = points[i].powerKw;
      final normalized = (maxValue - minValue).abs() < 0.0001 ? 0.5 : (value - minValue) / range;
      final x = left + stepX * i;
      final y = top + drawHeight - (normalized * drawHeight);
      canvas.drawCircle(Offset(x, y), 4.0, dotPaint);
      canvas.drawCircle(Offset(x, y), 1.8, Paint()..color = Colors.white);
    }

    final tickIndices = <int>{
      0,
      if (points.length > 2) (points.length / 3).floor(),
      if (points.length > 3) ((points.length * 2) / 3).floor(),
      points.length - 1,
    }.toList()
      ..sort();

    for (final index in tickIndices) {
      final x = left + stepX * index;
      canvas.drawLine(
        Offset(x, top + drawHeight),
        Offset(x, top + drawHeight + 4),
        gridPaint,
      );
      _paintText(
        canvas,
        text: DateFormat('HH:mm').format(points[index].recordedAt),
        offset: Offset(x - 16, top + drawHeight + 8),
        style: labelStyle,
      );
    }

    _paintText(
      canvas,
      text: 'Czas',
      offset: Offset((left + drawWidth / 2) - 14, size.height - 16),
      style: axisStyle,
    );
  }

  void _paintText(
    Canvas canvas, {
    required String text,
    required Offset offset,
    required TextStyle style,
  }) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(covariant _EnergyChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accentColor != accentColor;
  }
}


