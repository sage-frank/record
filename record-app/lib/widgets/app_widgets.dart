import 'dart:ui';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

// ─── Card ──────────────────────────────────────────────────

class AppCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final EdgeInsets? margin;
  final Color? color;
  final double radius;
  final VoidCallback? onTap;
  final bool flat;

  const AppCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.color,
    this.radius = 16,
    this.onTap,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: margin ?? EdgeInsets.zero,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: flat ? null : [
          BoxShadow(
            color: C.ink.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}

// ─── GlassCard (毛玻璃) ────────────────────────────────────

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets? padding;
  final double radius;
  final double blur;
  final double opacity;

  const GlassCard({
    super.key,
    required this.child,
    this.padding,
    this.radius = 16,
    this.blur = 12,
    this.opacity = 0.15,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── StatTile ──────────────────────────────────────────────

class StatTile extends StatelessWidget {
  final String label;
  final String value;
  final String? unit;
  final IconData icon;
  final Color accent;

  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.unit,
    required this.icon,
    this.accent = C.slate,
  });

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: accent),
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(value, style: T.numMd),
              if (unit != null) ...[
                const SizedBox(width: 3),
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Text(unit!, style: T.caption),
                ),
              ],
            ],
          ),
          const SizedBox(height: 2),
          Text(label, style: T.bodyS),
        ],
      ),
    );
  }
}

// ─── ProgressRing ──────────────────────────────────────────

class ProgressRing extends StatelessWidget {
  final double progress; // 0.0–1.0
  final double size;
  final double strokeWidth;
  final Color color;
  final Widget? center;

  const ProgressRing({
    super.key,
    required this.progress,
    this.size = 100,
    this.strokeWidth = 8,
    this.color = C.limeDim,
    this.center,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              strokeWidth: strokeWidth,
              backgroundColor: color.withOpacity(0.12),
              valueColor: AlwaysStoppedAnimation(color),
              strokeCap: StrokeCap.round,
            ),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

// ─── SectionHeader ─────────────────────────────────────────

class SectionHeader extends StatelessWidget {
  final String title;
  final String? action;
  final VoidCallback? onAction;

  const SectionHeader({
    super.key,
    required this.title,
    this.action,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 10),
      child: Row(
        children: [
          Text(title, style: T.h4),
          const Spacer(),
          if (action != null)
            GestureDetector(
              onTap: onAction,
              child: Text(action!, style: T.bodyS.copyWith(color: C.steel)),
            ),
        ],
      ),
    );
  }
}

// ─── Chip ──────────────────────────────────────────────────

class TagChip extends StatelessWidget {
  final String text;
  final IconData? icon;
  final Color? color;

  const TagChip(this.text, {super.key, this.icon, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? C.slate;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: c),
            const SizedBox(width: 4),
          ],
          Text(text, style: T.bodyS.copyWith(color: c, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ─── EmptyState ────────────────────────────────────────────

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.hint,
    this.actionLabel,
    this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: C.slate.withOpacity(0.4)),
            const SizedBox(height: 16),
            Text(title, style: T.h4.copyWith(color: C.slate)),
            if (hint != null) ...[
              const SizedBox(height: 6),
              Text(hint!, style: T.bodyS, textAlign: TextAlign.center),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: onAction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: C.ink,
                  foregroundColor: C.lime,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── WeightChart (CustomPaint, zero dependency) ────────────

class WeightChart extends StatelessWidget {
  final List<double> weights;
  final Color color;
  final double height;

  const WeightChart({
    super.key,
    required this.weights,
    this.color = C.limeDim,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    if (weights.length < 2) return const SizedBox.shrink();
    return SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _WeightPainter(weights: weights, color: color),
      ),
    );
  }
}

class _WeightPainter extends CustomPainter {
  final List<double> weights;
  final Color color;

  _WeightPainter({required this.weights, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (weights.length < 2) return;

    final minW = weights.reduce((a, b) => a < b ? a : b) - 0.5;
    final maxW = weights.reduce((a, b) => a > b ? a : b) + 0.5;
    final range = maxW - minW;
    if (range <= 0) return;

    final w = size.width;
    final h = size.height;
    final step = w / (weights.length - 1);

    // Fill area
    final fillPath = Path();
    final linePath = Path();

    for (int i = 0; i < weights.length; i++) {
      final x = step * i;
      final y = h - ((weights[i] - minW) / range) * h;
      if (i == 0) {
        linePath.moveTo(x, y);
        fillPath.moveTo(x, h);
        fillPath.lineTo(x, y);
      } else {
        // Smooth curve
        final prevX = step * (i - 1);
        final prevY = h - ((weights[i - 1] - minW) / range) * h;
        final midX = (prevX + x) / 2;
        linePath.cubicTo(midX, prevY, midX, y, x, y);
        fillPath.cubicTo(midX, prevY, midX, y, x, y);
      }
    }
    fillPath.lineTo(w, h);
    fillPath.close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [color.withOpacity(0.25), color.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.drawPath(fillPath, fillPaint);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(linePath, linePaint);

    // End dot
    final lastX = step * (weights.length - 1);
    final lastY = h - ((weights.last - minW) / range) * h;
    canvas.drawCircle(Offset(lastX, lastY), 5, Paint()..color = color);
    canvas.drawCircle(Offset(lastX, lastY), 3, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => old.weights != weights;
}

// ─── AnimatedNumber ────────────────────────────────────────

class AnimatedNumber extends StatefulWidget {
  final num value;
  final TextStyle? style;
  final int decimals;
  final Duration duration;

  const AnimatedNumber({
    super.key,
    required this.value,
    this.style,
    this.decimals = 0,
    this.duration = const Duration(milliseconds: 800),
  });

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;
  num _oldValue = 0;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(duration: widget.duration, vsync: this);
    _anim = Tween<double>(begin: 0, end: widget.value.toDouble())
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(AnimatedNumber oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _oldValue = oldWidget.value;
      _anim = Tween<double>(
        begin: _oldValue.toDouble(),
        end: widget.value.toDouble(),
      ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        final s = widget.decimals == 0
            ? v.round().toString()
            : v.toStringAsFixed(widget.decimals);
        return Text(s, style: widget.style);
      },
    );
  }
}
