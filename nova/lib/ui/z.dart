import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/localization/app_text.dart';
import '../design/theme.dart';

/// Легкий haptic на дотик (на мобільному — вібрація, на вебі — no-op).
void zTap() => HapticFeedback.selectionClick();

/// Набір компонентів Запис+ v3. Єдина дизайн-система: усі екрани збираються з
/// цих цеглин, щоб пиксель-в-пиксель збігатися з макетами (глибина, скло,
/// градієнти, свічення, плавність). Kavio* назви лишаються внутрішніми.

// ─────────────────────────────────────────── Текст-хелпери

/// UPPERCASE-мітка (.lbl у макеті): 11px, 700, tracking, ink3.
class ZLabel extends StatelessWidget {
  const ZLabel(this.text, {super.key, this.color});
  final String text;
  final Color? color;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Text(
      text.toUpperCase(),
      style: AppTypography.caption(color ?? k.ink3).copyWith(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1),
    );
  }
}

// ─────────────────────────────────────────── Поверхні

class ZCard extends StatelessWidget {
  const ZCard(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.radius = 22});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FX.card(context.kavio, radius: radius),
      padding: padding,
      child: child,
    );
  }
}

class ZHero extends StatelessWidget {
  const ZHero(
      {super.key,
      required this.child,
      this.padding = const EdgeInsets.all(16),
      this.radius = 24,
      this.orb = true});
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool orb;
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: FX.hero(radius: radius),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          if (orb)
            const Positioned(top: -30, right: -18, child: GlowOrb(size: 150)),
          Padding(padding: padding, child: child),
        ],
      ),
    );
  }
}

/// Скляна поверхня (нав-бар, пошук, тости): blur + напівпрозорість.
class ZGlass extends StatelessWidget {
  const ZGlass({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.radius = 16,
    this.blur = 22,
    this.fill = FX.glassFill,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final double blur;
  final Color fill;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: k.line, width: 1),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── Кнопки (з press-фізикою)

class ZButton extends StatefulWidget {
  const ZButton(
      {super.key,
      required this.label,
      this.onTap,
      this.icon,
      this.padding = const EdgeInsets.all(15),
      this.expand = true});
  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final EdgeInsetsGeometry padding;
  final bool expand;
  @override
  State<ZButton> createState() => _ZButtonState();
}

class _ZButtonState extends State<ZButton> {
  bool _down = false;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    // Кнопка без дії не має світитися як головна: гасне градієнт, зникає
    // свічення, текст іде в ink3. Підпис при цьому лишається підказкою.
    final enabled = widget.onTap != null;
    final fg = enabled ? Colors.white : k.ink3;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      curve: Motion.enter,
      width: widget.expand ? double.infinity : null,
      padding: widget.padding,
      decoration: enabled ? FX.button() : FX.buttonSecondary(k, radius: 17),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (widget.icon != null) ...[
            Icon(widget.icon, size: 18, color: fg),
            const SizedBox(width: 8)
          ],
          Text(widget.label,
              style: AppTypography.title3(fg)
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w700)),
        ],
      ),
    );
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.96 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: child,
      ),
    );
  }
}

class ZButtonSecondary extends StatelessWidget {
  const ZButtonSecondary(
      {super.key,
      required this.label,
      this.onTap,
      this.padding = const EdgeInsets.all(13),
      this.expand = false});
  final String label;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool expand;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: expand ? double.infinity : null,
        padding: padding,
        alignment: Alignment.center,
        decoration: FX.buttonSecondary(k),
        child: Text(label,
            style: AppTypography.title3(k.ink)
                .copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
      ),
    );
  }
}

// ─────────────────────────────────────────── Дрібні елементи

class ZPill extends StatelessWidget {
  const ZPill(this.text, {super.key, required this.color, required this.bg});
  final String text;
  final Color color;
  final Color bg;
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration:
          BoxDecoration(color: bg, borderRadius: BorderRadius.circular(999)),
      child: Text(text,
          style: AppTypography.caption(color).copyWith(
              fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0)),
    );
  }
}

class ZAvatar extends StatelessWidget {
  const ZAvatar(
      {super.key,
      required this.initials,
      this.size = 44,
      this.ring = false,
      this.color,
      this.bg});
  final String initials;
  final double size;
  final bool ring;
  final Color? color;
  final Color? bg;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg ?? k.accentTint,
        shape: BoxShape.circle,
        boxShadow: ring
            ? [
                BoxShadow(color: k.canvas, blurRadius: 0, spreadRadius: 3),
                const BoxShadow(
                    color: Color(0x2E8B8BF0), blurRadius: 0, spreadRadius: 4),
                const BoxShadow(
                    color: Color(0x998B8BF0),
                    blurRadius: 24,
                    spreadRadius: -8,
                    offset: Offset(0, 10)),
              ]
            : null,
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTypography.title3(color ?? k.accent)
            .copyWith(fontSize: size * 0.36, fontWeight: FontWeight.w700),
      ),
    );
  }
}

/// Статистична плитка (Записів / Виручка / Вільно).
class ZStatCard extends StatelessWidget {
  const ZStatCard(
      {super.key,
      required this.label,
      required this.value,
      this.sub,
      this.subColor});
  final String label;
  final String value;
  final String? sub;
  final Color? subColor;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZLabel(label),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value,
                maxLines: 1,
                softWrap: false,
                style: AppTypography.tabular(AppTypography.title1(k.ink))
                    .copyWith(fontSize: 24)),
          ),
          if (sub != null) ...[
            const SizedBox(height: 2),
            Text(sub!,
                style: AppTypography.label(subColor ?? k.ink3)
                    .copyWith(fontSize: 11)),
          ],
        ],
      ),
    );
  }
}

/// Сегмент-контрол (День/Тиждень/Місяць, періоди).
class ZSegmented extends StatelessWidget {
  const ZSegmented(
      {super.key,
      required this.items,
      required this.index,
      required this.onChanged});
  final List<String> items;
  final int index;
  final ValueChanged<int> onChanged;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
          color: k.surface2, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: GestureDetector(
                onTap: () {
                  zTap();
                  onChanged(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeOut,
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == index ? k.surface3 : Colors.transparent,
                    borderRadius: BorderRadius.circular(11),
                    boxShadow: i == index
                        ? const [
                            BoxShadow(
                                color: Color(0x66000000),
                                blurRadius: 8,
                                offset: Offset(0, 2))
                          ]
                        : null,
                  ),
                  child: Text(
                    items[i],
                    style: AppTypography.label(i == index ? k.ink : k.ink2)
                        .copyWith(fontSize: 13.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Вільне вікно: пунктирна рамка iris + м'яка заливка + CTA «Заповнити».
class ZFreeSlot extends StatelessWidget {
  const ZFreeSlot({super.key, required this.duration, this.onTap, this.cta});
  final String duration;
  final VoidCallback? onTap;
  final String? cta;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return GestureDetector(
      onTap: onTap == null
          ? null
          : () {
              HapticFeedback.lightImpact();
              onTap!();
            },
      child: CustomPaint(
        painter: _DashedRRectPainter(
            color: FX.freeSlotBorder, radius: 16, dash: 6, gap: 5, stroke: 1.5),
        child: Container(
          decoration: FX.freeSlot(),
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
          child: Row(
            children: [
              Container(
                width: 26,
                height: 26,
                decoration: BoxDecoration(
                    color: k.accentTint,
                    borderRadius: BorderRadius.circular(8)),
                alignment: Alignment.center,
                child: Icon(Icons.add, size: 16, color: k.accent),
              ),
              const SizedBox(width: 9),
              Expanded(
                  child: Text('${t('Вільно')} · $duration',
                      style: AppTypography.label(k.ink2)
                          .copyWith(fontSize: 12.5))),
              Text(cta ?? t('Заповнити'),
                  style: AppTypography.label(k.accent)
                      .copyWith(fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter(
      {required this.color,
      required this.radius,
      required this.dash,
      required this.gap,
      required this.stroke});
  final Color color;
  final double radius, dash, gap, stroke;
  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    for (final metric in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < metric.length) {
        final len = math.min(dash, metric.length - dist);
        canvas.drawPath(metric.extractPath(dist, dist + len), paint);
        dist += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedRRectPainter old) => old.color != color;
}

/// Кільце-прогрес (лічильник «до наступного», завантаження).
class ZRing extends StatelessWidget {
  const ZRing(
      {super.key,
      required this.progress,
      this.size = 52,
      this.stroke = 4,
      this.color,
      this.center,
      this.glow = true});
  final double progress;
  final double size, stroke;
  final Color? color;
  final Widget? center;
  final bool glow;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CustomPaint(
            size: Size(size, size),
            painter: _RingPainter(
                progress: progress,
                stroke: stroke,
                track: k.surface3,
                color: color ?? k.accent,
                glow: glow),
          ),
          if (center != null) center!,
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(
      {required this.progress,
      required this.stroke,
      required this.track,
      required this.color,
      required this.glow});
  final double progress, stroke;
  final Color track, color;
  final bool glow;
  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    final trackPaint = Paint()
      ..color = track
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke;
    canvas.drawCircle(c, r, trackPaint);
    final arc = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;
    if (glow) {
      arc.maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    }
    final rect = Rect.fromCircle(center: c, radius: r);
    canvas.drawArc(
        rect, -math.pi / 2, 2 * math.pi * progress.clamp(0, 1), false, arc);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}

/// «Живе» кільце: прокреслюється з пружиною при появі, потім тихо «дихає» —
/// біжуча цятка-голова обертається, свічення пульсує. Для «Наступний клієнт».
class ZLiveRing extends StatefulWidget {
  const ZLiveRing({
    super.key,
    required this.progress,
    this.size = 52,
    this.stroke = 4,
    this.color,
    this.center,
  });
  final double progress;
  final double size, stroke;
  final Color? color;
  final Widget? center;
  @override
  State<ZLiveRing> createState() => _ZLiveRingState();
}

class _ZLiveRingState extends State<ZLiveRing> with TickerProviderStateMixin {
  late final AnimationController _draw = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1100));
  late final Animation<double> _drawT =
      CurvedAnimation(parent: _draw, curve: const Cubic(0.16, 0.9, 0.3, 1));
  late final AnimationController _spin =
      AnimationController(vsync: this, duration: const Duration(seconds: 3))
        ..repeat();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _draw.forward();
    });
  }

  @override
  void dispose() {
    _draw.dispose();
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: Listenable.merge([_drawT, _spin]),
            builder: (context, _) => CustomPaint(
              size: Size(widget.size, widget.size),
              painter: _LiveRingPainter(
                progress: widget.progress * _drawT.value,
                spin: _spin.value,
                breathe: _drawT.value,
                stroke: widget.stroke,
                track: k.surface3,
                color: widget.color ?? k.accent,
              ),
            ),
          ),
          if (widget.center != null) widget.center!,
        ],
      ),
    );
  }
}

class _LiveRingPainter extends CustomPainter {
  _LiveRingPainter({
    required this.progress,
    required this.spin,
    required this.breathe,
    required this.stroke,
    required this.track,
    required this.color,
  });
  final double progress, spin, breathe, stroke;
  final Color track, color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = (size.shortestSide - stroke) / 2;
    canvas.drawCircle(
        c,
        r,
        Paint()
          ..color = track
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke);
    if (progress <= 0) return;

    final rect = Rect.fromCircle(center: c, radius: r);
    final sweep = 2 * math.pi * progress.clamp(0, 1);
    const start = -math.pi / 2;

    // Пульсуюче свічення (дихання).
    final glowA = 0.25 + 0.25 * (0.5 + 0.5 * math.sin(spin * 2 * math.pi));
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color.withValues(alpha: glowA)
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );
    // Основна дуга.
    canvas.drawArc(
      rect,
      start,
      sweep,
      false,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round,
    );
    // Яскрава «голова» дуги + біжуча цятка вздовж треку.
    final headAngle = start + sweep;
    final head = c + Offset(math.cos(headAngle), math.sin(headAngle)) * r;
    canvas.drawCircle(head, stroke * 0.9,
        Paint()..color = Colors.white.withValues(alpha: 0.9));

    final sparkAngle = start + 2 * math.pi * spin;
    if (2 * math.pi * spin <= sweep) {
      final spark = c + Offset(math.cos(sparkAngle), math.sin(sparkAngle)) * r;
      canvas.drawCircle(
          spark,
          stroke * 0.6,
          Paint()
            ..color = Colors.white.withValues(alpha: 0.7 * breathe)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
    }
  }

  @override
  bool shouldRepaint(_LiveRingPainter old) =>
      old.progress != progress || old.spin != spin;
}

// ─────────────────────────────────────────── Анімація появи (stagger fade-up)

/// Плавна поява знизу з невеликою затримкою за індексом — «екран оживає».
class StaggerReveal extends StatefulWidget {
  const StaggerReveal(
      {super.key,
      required this.index,
      required this.child,
      this.offset = 18,
      this.step = const Duration(milliseconds: 70)});
  final int index;
  final Widget child;
  final double offset;
  final Duration step;
  @override
  State<StaggerReveal> createState() => _StaggerRevealState();
}

class _StaggerRevealState extends State<StaggerReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  late final Animation<double> _t =
      CurvedAnimation(parent: _c, curve: const Cubic(0.16, 0.9, 0.3, 1));

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.step * widget.index, () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (context, child) => Opacity(
        opacity: _t.value,
        child: Transform.translate(
            offset: Offset(0, (1 - _t.value) * widget.offset), child: child),
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────── Чипи вибору

/// Чип-вибір (клієнт, послуга, час, пресет). Увімкнений — фірмовий градієнт
/// із свіченням, вимкнений — surface2 з тонкою лінією. Натиск дає haptic і
/// коротке стиснення: вибір відчувається фізично.
class ZChip extends StatefulWidget {
  const ZChip({
    super.key,
    required this.child,
    required this.selected,
    this.onTap,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
    this.radius = 999,
  });
  final Widget child;
  final bool selected;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  State<ZChip> createState() => _ZChipState();
}

class _ZChipState extends State<ZChip> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final on = widget.selected;
    return GestureDetector(
      onTapDown: (_) => setState(() => _down = true),
      onTapUp: (_) => setState(() => _down = false),
      onTapCancel: () => setState(() => _down = false),
      onTap: widget.onTap == null
          ? null
          : () {
              zTap();
              widget.onTap!();
            },
      child: AnimatedScale(
        scale: _down ? 0.95 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Motion.enter,
          padding: widget.padding,
          decoration: BoxDecoration(
            color: on ? null : k.surface2,
            gradient: on ? FX.brandButton : null,
            borderRadius: BorderRadius.circular(widget.radius),
            border: Border.all(color: on ? Colors.transparent : k.line),
            boxShadow: on
                ? const [
                    BoxShadow(
                        color: Color(0x808B8BF0),
                        blurRadius: 20,
                        spreadRadius: -8,
                        offset: Offset(0, 8))
                  ]
                : null,
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── Поле вводу

/// Поле вводу v3: UPPERCASE-мітка, поверхня surface2, при фокусі — акцентна
/// обводка й м'яке свічення (як у кнопки). Суфікс — для одиниць (₴, хв).
class ZField extends StatefulWidget {
  const ZField({
    super.key,
    this.label,
    this.hint,
    this.controller,
    this.keyboardType,
    this.inputFormatters,
    this.onChanged,
    this.autofocus = false,
    this.textInputAction,
    this.icon,
    this.suffix,
    this.maxLines = 1,
  });
  final String? label;
  final String? hint;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final IconData? icon;
  final String? suffix;
  final int maxLines;

  @override
  State<ZField> createState() => _ZFieldState();
}

class _ZFieldState extends State<ZField> {
  final FocusNode _node = FocusNode();

  @override
  void initState() {
    super.initState();
    _node.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final on = _node.hasFocus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.label != null) ...[
          ZLabel(widget.label!),
          const SizedBox(height: 8),
        ],
        AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Motion.enter,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          decoration: BoxDecoration(
            color: k.surface2,
            borderRadius: BorderRadius.circular(16),
            border:
                Border.all(color: on ? k.accent : k.line, width: on ? 1.5 : 1),
            boxShadow: on
                ? const [
                    BoxShadow(
                        color: Color(0x598B8BF0),
                        blurRadius: 26,
                        spreadRadius: -10,
                        offset: Offset(0, 10))
                  ]
                : null,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (widget.icon != null) ...[
                Icon(widget.icon, size: 18, color: on ? k.accent : k.ink3),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: TextField(
                  focusNode: _node,
                  controller: widget.controller,
                  keyboardType: widget.keyboardType,
                  inputFormatters: widget.inputFormatters,
                  onChanged: widget.onChanged,
                  autofocus: widget.autofocus,
                  textInputAction: widget.textInputAction,
                  maxLines: widget.maxLines,
                  style: AppTypography.body(k.ink)
                      .copyWith(fontSize: 15, fontWeight: FontWeight.w600),
                  cursorColor: k.accent,
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: widget.hint,
                    hintStyle:
                        AppTypography.body(k.ink3).copyWith(fontSize: 15),
                    contentPadding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                ),
              ),
              if (widget.suffix != null) ...[
                const SizedBox(width: 8),
                Text(widget.suffix!,
                    style: AppTypography.label(k.ink3)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────── Плитка дії

/// Дія в картці запису: іконка в кольоровому кружку + підпис. Натиск —
/// haptic і стиснення. [tone] фарбує іконку (акцент / успіх / небезпека).
class ZActionTile extends StatefulWidget {
  const ZActionTile({
    super.key,
    required this.icon,
    required this.label,
    this.onTap,
    this.tone,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? tone;

  @override
  State<ZActionTile> createState() => _ZActionTileState();
}

class _ZActionTileState extends State<ZActionTile> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final tone = widget.tone ?? k.accent;
    final enabled = widget.onTap != null;
    return GestureDetector(
      onTapDown: enabled ? (_) => setState(() => _down = true) : null,
      onTapUp: enabled ? (_) => setState(() => _down = false) : null,
      onTapCancel: enabled ? () => setState(() => _down = false) : null,
      onTap: enabled
          ? () {
              HapticFeedback.lightImpact();
              widget.onTap!();
            }
          : null,
      child: AnimatedScale(
        scale: _down ? 0.94 : 1,
        duration: const Duration(milliseconds: 110),
        curve: Curves.easeOut,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: k.surface2,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: k.line),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: tone.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(11),
                  ),
                  alignment: Alignment.center,
                  child: Icon(widget.icon, size: 18, color: tone),
                ),
                const SizedBox(height: 7),
                Text(
                  widget.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.label(k.ink2)
                      .copyWith(fontSize: 11.5, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────── Тости

/// Показ повідомлення знизу. Отримується з [zToaster] ДО await, тому лишається
/// робочим після того, як лист закрився й його context помер.
typedef ZToast = void Function(
  String message, {
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration,
});

/// Повідомлення знизу в стилі застосунку: поверхня surface2, скруглення,
/// акцентна дія, підняте над плаваючим нав-баром. Системний SnackBar сірий,
/// прямокутний і лізе під нав-бар — у темному інтерфейсі це чужий елемент.
///
/// Беремо тостер на початку операції:
/// `final toast = zToaster(context);` — і кличемо після збереження.
ZToast zToaster(BuildContext context) {
  final k = context.kavio;
  final messenger = ScaffoldMessenger.of(context);
  return (
    String message, {
    String? actionLabel,
    VoidCallback? onAction,
    Duration duration = const Duration(seconds: 5),
  }) {
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: k.surface2,
      elevation: 0,
      duration: duration,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 96),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: k.line),
      ),
      content: Text(message,
          style: AppTypography.body(k.ink)
              .copyWith(fontSize: 14, fontWeight: FontWeight.w600)),
      action: actionLabel == null
          ? null
          : SnackBarAction(
              label: actionLabel,
              textColor: k.accent,
              onPressed: () {
                zTap();
                onAction?.call();
              },
            ),
    ));
  };
}
