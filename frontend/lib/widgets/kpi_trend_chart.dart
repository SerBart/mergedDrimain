import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../core/models/dashboard_kpi.dart';

class KpiTrendChart extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<DashboardTrendPoint> points;
  final Color accentColor;

  const KpiTrendChart({
    super.key,
    required this.title,
    required this.subtitle,
    required this.points,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (points.isEmpty) {
      return _TrendPanelShell(
        title: title,
        subtitle: subtitle,
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 24),
          child: Text('Brak danych trendu.'),
        ),
      );
    }

    final maxValue = math.max(1, points.map((p) => p.count).fold<int>(0, math.max));
    final first = points.first;
    final last = points.last;
    final delta = last.count - first.count;

    return _TrendPanelShell(
      title: title,
      subtitle: subtitle,
      trailing: Text(
        delta == 0
            ? 'stabilnie'
            : delta > 0
                ? '+$delta'
                : '$delta',
        style: TextStyle(
          color: delta > 0 ? Colors.orange.shade700 : delta < 0 ? Colors.green.shade700 : theme.colorScheme.onSurfaceVariant,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 170,
            child: CustomPaint(
              painter: _TrendChartPainter(
                points: points,
                accentColor: accentColor,
                maxValue: maxValue,
              ),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _TrendLegendDot(color: accentColor, label: 'seria'),
              _TrendMeta(label: 'pierwszy', value: '${first.count} • ${DateFormat('dd.MM').format(first.date)}'),
              _TrendMeta(label: 'ostatni', value: '${last.count} • ${DateFormat('dd.MM').format(last.date)}'),
            ],
          ),
        ],
      ),
    );
  }
}

class _TrendPanelShell extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;
  final Widget? trailing;

  const _TrendPanelShell({
    required this.title,
    required this.subtitle,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor.withOpacity(.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.black54)),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _TrendLegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _TrendLegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      ],
    );
  }
}

class _TrendMeta extends StatelessWidget {
  final String label;
  final String value;

  const _TrendMeta({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Text(
      '$label: $value',
      style: const TextStyle(fontSize: 12, color: Colors.black54),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<DashboardTrendPoint> points;
  final Color accentColor;
  final int maxValue;

  _TrendChartPainter({
    required this.points,
    required this.accentColor,
    required this.maxValue,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;

    const left = 14.0;
    const top = 18.0;
    const bottom = 24.0;
    final drawWidth = math.max(1.0, size.width - left * 2);
    final drawHeight = math.max(1.0, size.height - top - bottom);
    final stepX = points.length == 1 ? 0.0 : drawWidth / (points.length - 1);

    final gridPaint = Paint()
      ..color = Colors.black.withOpacity(.06)
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = top + (drawHeight * i / 2);
      canvas.drawLine(Offset(left, y), Offset(size.width - left, y), gridPaint);
    }

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

    Offset? firstPoint;
    Offset? previousPoint;

    for (var i = 0; i < points.length; i++) {
      final value = points[i].count.toDouble();
      final normalized = maxValue == 0 ? 0.0 : value / maxValue;
      final x = left + stepX * i;
      final y = top + drawHeight - (normalized * drawHeight);
      final current = Offset(x, y);

      if (i == 0) {
        path.moveTo(current.dx, current.dy);
        area.moveTo(current.dx, top + drawHeight);
        area.lineTo(current.dx, current.dy);
        firstPoint = current;
      } else {
        final prev = previousPoint!;
        final c1 = Offset((prev.dx + current.dx) / 2, prev.dy);
        final c2 = Offset((prev.dx + current.dx) / 2, current.dy);
        path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, current.dx, current.dy);
        area.lineTo(current.dx, current.dy);
      }

      previousPoint = current;
    }

    if (firstPoint != null) {
      area.lineTo(previousPoint!.dx, top + drawHeight);
      area.close();
      canvas.drawPath(area, fillPaint);
      canvas.drawPath(path, linePaint);
    }

    for (var i = 0; i < points.length; i++) {
      final value = points[i].count.toDouble();
      final normalized = maxValue == 0 ? 0.0 : value / maxValue;
      final x = left + stepX * i;
      final y = top + drawHeight - (normalized * drawHeight);
      canvas.drawCircle(Offset(x, y), 4.2, dotPaint);
      canvas.drawCircle(Offset(x, y), 2.0, Paint()..color = Colors.white);
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.accentColor != accentColor || oldDelegate.maxValue != maxValue;
  }
}

