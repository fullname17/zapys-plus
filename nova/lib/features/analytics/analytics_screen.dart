import '../../core/localization/app_text.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/analytics_providers.dart';
import '../../design/theme.dart';
import '../../ui/format.dart';
import '../../ui/z.dart';

/// Аналітика рівня Stripe/Linear: великі числа з дельтою, ghost-лінія
/// порівняння, sparkline у KPI, теплова карта завантаженості, топ послуг.
class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});
  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  AnalyticsPeriod _period = AnalyticsPeriod.today;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final d = ref.watch(analyticsProvider(_period));
    var i = 0;
    Widget reveal(Widget c) => StaggerReveal(index: i++, child: c);

    return Container(
      color: k.canvas,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
          children: [
            reveal(Row(
              children: [
                Expanded(
                    child: Text(t('Аналітика'),
                        style: AppTypography.title1(k.ink))),
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                      color: k.surface2,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.tune, size: 18, color: k.ink2),
                ),
              ],
            )),
            const SizedBox(height: 14),
            reveal(ZSegmented(
              items: [t('Сьогодні'), t('Тиждень'), t('Місяць'), t('Рік')],
              index: _period.index,
              onChanged: (v) {
                zTap();
                setState(() => _period = AnalyticsPeriod.values[v]);
              },
            )),
            const SizedBox(height: 14),
            reveal(_RevenueHero(period: _period, d: d)),
            const SizedBox(height: 12),
            reveal(_KpiGrid(d: d)),
            const SizedBox(height: 12),
            reveal(_Heatmap(d: d)),
            const SizedBox(height: 12),
            reveal(_TopServices(d: d)),
          ],
        ),
      ),
    );
  }
}

class _RevenueHero extends StatelessWidget {
  const _RevenueHero({required this.period, required this.d});
  final AnalyticsPeriod period;
  final AnalyticsData d;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final delta = d.deltaPercent;
    return ZHero(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabel('${t('Виручка')} · ${t(periodTitleKey(period))}',
              color: k.ink2),
          Text(Fmt.money(d.revenue),
              style: AppTypography.tabular(AppTypography.display(k.ink))
                  .copyWith(fontSize: 36, height: 1.05)),
          const SizedBox(height: 6),
          Row(
            children: [
              if (delta != null) ...[
                ZPill('${delta >= 0 ? '▲' : '▼'} ${delta.abs()}%',
                    color: delta >= 0 ? k.success : k.danger,
                    bg: delta >= 0 ? k.successTint : k.dangerTint),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                    delta == null
                        ? tp('{v} записів', {'v': d.visits})
                        : tp('проти {sum} · {p}', {
                            'sum': Fmt.money(d.prevRevenue),
                            'p': t(prevPeriodKey(period)),
                          }),
                    style: AppTypography.label(k.ink3).copyWith(fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          SizedBox(
            height: 96,
            child: CustomPaint(
              size: Size.infinite,
              painter: _AreaChartPainter(cur: d.series, prev: d.prevSeries),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              _Legend(dashed: false, label: t(periodTitleKey(period))),
              const SizedBox(width: 14),
              _Legend(dashed: true, label: t(prevPeriodKey(period))),
            ],
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.dashed, required this.label});
  final bool dashed;
  final String label;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Row(
      children: [
        SizedBox(
          width: 14,
          height: 3,
          child: CustomPaint(painter: _LineSwatch(dashed: dashed)),
        ),
        const SizedBox(width: 5),
        Text(label, style: AppTypography.label(k.ink3).copyWith(fontSize: 10)),
      ],
    );
  }
}

class _LineSwatch extends CustomPainter {
  _LineSwatch({required this.dashed});
  final bool dashed;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = dashed ? Colors.white54 : Colors.white
      ..strokeWidth = 2;
    if (dashed) {
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, 1.5), Offset(x + 3, 1.5), p);
        x += 6;
      }
    } else {
      canvas.drawLine(const Offset(0, 1.5), Offset(size.width, 1.5), p);
    }
  }

  @override
  bool shouldRepaint(_LineSwatch oldDelegate) => false;
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.cur, required this.prev});

  /// Виручка по кошиках періоду, нормована 0..1. Раніше обидві лінії були
  /// зашиті константами й малювали один і той самий «красивий» графік.
  final List<double> cur, prev;

  @override
  void paint(Canvas canvas, Size size) {
    Offset pt(List<double> s, int i) =>
        Offset(size.width * i / (s.length - 1), size.height * (1 - s[i]));

    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var g = 1; g < 4; g++) {
      final y = size.height * g / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final ghost = Paint()
      ..color = Colors.white.withValues(alpha: 0.28)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final gp = Path()..moveTo(pt(prev, 0).dx, pt(prev, 0).dy);
    for (var i = 1; i < prev.length; i++) {
      gp.lineTo(pt(prev, i).dx, pt(prev, i).dy);
    }
    _dash(canvas, gp, ghost);

    final fill = Path()..moveTo(0, size.height);
    for (var i = 0; i < cur.length; i++) {
      fill.lineTo(pt(cur, i).dx, pt(cur, i).dy);
    }
    fill.lineTo(size.width, size.height);
    fill.close();
    canvas.drawPath(
      fill,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x57B9B9FF), Color(0x00B9B9FF)],
        ).createShader(Offset.zero & size),
    );

    final line = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.8
      ..strokeJoin = StrokeJoin.round
      ..strokeCap = StrokeCap.round;
    final lp = Path()..moveTo(pt(cur, 0).dx, pt(cur, 0).dy);
    for (var i = 1; i < cur.length; i++) {
      lp.lineTo(pt(cur, i).dx, pt(cur, i).dy);
    }
    canvas.drawPath(lp, line);

    final end = pt(cur, cur.length - 1);
    canvas.drawCircle(
        end, 9, Paint()..color = Colors.white.withValues(alpha: 0.18));
    canvas.drawCircle(end, 4.5, Paint()..color = Colors.white);
  }

  void _dash(Canvas canvas, Path path, Paint paint) {
    for (final m in path.computeMetrics()) {
      var d = 0.0;
      while (d < m.length) {
        canvas.drawPath(m.extractPath(d, d + 4), paint);
        d += 8;
      }
    }
  }

  @override
  bool shouldRepaint(_AreaChartPainter old) =>
      !listEquals(old.cur, cur) || !listEquals(old.prev, prev);
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.d});
  final AnalyticsData d;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    // Прибутку поки не рахуємо: собівартості послуг у продукті немає, тож
    // показувати «прибуток» замість виручки було б обманом.
    final tiles = <Widget>[
      _KpiTile(
          label: t('Виручка'),
          value: Fmt.money(d.revenue),
          delta: d.deltaPercent,
          spark: d.series,
          color: k.success),
      _KpiTile(
          label: t('Сер. чек'),
          value: Fmt.money(d.avgCheck),
          delta: d.avgCheckDelta,
          spark: d.series,
          color: k.accent),
      _KpiTile(
          label: t('Записів'),
          value: '${d.visits}',
          delta: d.visitsDelta,
          spark: d.series,
          color: k.accent),
      _KpiTile(
          label: t('Скасувань'),
          value: '${d.cancelPercent}%',
          delta: d.cancelDelta == 0 ? null : d.cancelDelta,
          // Менше скасувань — краще, тож стрілка рахується навпаки.
          lowerIsBetter: true,
          spark: d.prevSeries,
          color: k.danger),
    ];
    return Column(
      children: [
        Row(children: [
          Expanded(child: tiles[0]),
          const SizedBox(width: 10),
          Expanded(child: tiles[1])
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(child: tiles[2]),
          const SizedBox(width: 10),
          Expanded(child: tiles[3])
        ]),
      ],
    );
  }
}

class _KpiTile extends StatelessWidget {
  const _KpiTile(
      {required this.label,
      required this.value,
      required this.delta,
      required this.spark,
      required this.color,
      this.lowerIsBetter = false});
  final String label, value;

  /// null — попереднього періоду немає, порівнювати нема з чим. Показуємо
  /// просто число, без вигаданої стрілки.
  final int? delta;
  final List<double> spark;
  final Color color;
  final bool lowerIsBetter;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: ZLabel(label)),
              if (delta != null)
                Builder(builder: (context) {
                  final good = lowerIsBetter ? delta! < 0 : delta! >= 0;
                  return ZPill('${delta! >= 0 ? '▲' : '▼'} ${delta!.abs()}%',
                      color: good ? k.success : k.danger,
                      bg: good ? k.successTint : k.dangerTint);
                }),
            ],
          ),
          const SizedBox(height: 4),
          Text(value,
              style: AppTypography.tabular(AppTypography.title1(k.ink))
                  .copyWith(fontSize: 22)),
          const SizedBox(height: 6),
          SizedBox(
            height: 26,
            child: CustomPaint(
                size: Size.infinite, painter: _SparkPainter(spark, color)),
          ),
        ],
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  _SparkPainter(this.data, this.color);
  final List<double> data;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final mn = data.reduce(math.min), mx = data.reduce(math.max);
    final rng = (mx - mn) == 0 ? 1.0 : (mx - mn);
    Offset pt(int i) => Offset(size.width * i / (data.length - 1),
        size.height * (1 - (data[i] - mn) / rng));
    final p = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < data.length; i++) {
      p.lineTo(pt(i).dx, pt(i).dy);
    }
    canvas.drawPath(
      p,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter oldDelegate) => false;
}

class _Heatmap extends StatelessWidget {
  const _Heatmap({required this.d});
  final AnalyticsData d;

  static const hours = ['10', '12', '14', '16', '18'];
  static List<String> get days =>
      [t('Пн'), t('Вт'), t('Ср'), t('Чт'), t('Пт'), t('Сб'), t('Нд')];

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              ZLabel(t('Завантаженість по днях')),
              Row(
                children: [
                  ZRing(
                      progress: d.loadPercent / 100,
                      size: 30,
                      stroke: 3.5,
                      glow: false),
                  const SizedBox(width: 8),
                  Text('${d.loadPercent}%',
                      style: AppTypography.tabular(AppTypography.title3(k.ink))
                          .copyWith(fontSize: 16, fontWeight: FontWeight.w800)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  for (final h in hours) ...[
                    SizedBox(
                      height: 20,
                      child: Text(h,
                          style:
                              AppTypography.tabular(AppTypography.label(k.ink3))
                                  .copyWith(fontSize: 9)),
                    ),
                    const SizedBox(height: 4),
                  ],
                ],
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    for (final row in d.heatmap) ...[
                      Row(
                        children: [
                          for (final v in row)
                            Expanded(
                              child: Container(
                                height: 20,
                                margin: const EdgeInsets.only(right: 4),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF8B8BF0)
                                      .withValues(alpha: 0.08 + v * 0.9),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 4),
                    ],
                    Row(
                      children: [
                        for (final day in days)
                          Expanded(
                            child: Text(day,
                                textAlign: TextAlign.center,
                                style: AppTypography.label(k.ink3)
                                    .copyWith(fontSize: 10)),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopServices extends StatelessWidget {
  const _TopServices({required this.d});
  final AnalyticsData d;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabel(t('Популярні послуги')),
          const SizedBox(height: 12),
          if (d.topServices.isEmpty)
            Text(t('За цей період завершених візитів не було.'),
                style: AppTypography.label(k.ink3).copyWith(fontSize: 12.5)),
          for (final it in d.topServices) ...[
            Row(
              children: [
                Expanded(
                  child: Text(it.$1,
                      style: AppTypography.label(k.ink)
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
                ),
                Text(Fmt.money(it.$2),
                    style: AppTypography.tabular(AppTypography.label(k.ink2))
                        .copyWith(fontSize: 12)),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: it.$3,
                minHeight: 7,
                backgroundColor: k.surface2,
                valueColor: const AlwaysStoppedAnimation(Color(0xFF9595F5)),
              ),
            ),
            const SizedBox(height: 11),
          ],
        ],
      ),
    );
  }
}
