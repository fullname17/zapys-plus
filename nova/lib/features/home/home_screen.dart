import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/skeleton.dart';
import '../../ui/z.dart';
import '../create/create_appointment_sheet.dart';

/// Головний екран «Сьогодні» — дашборд дня. Відкривається з плавним stagger:
/// картки виринають знизу. Показує пульс дня: записи, виручку, наступного
/// клієнта з відліком, вільні вікна та інсайт повернення.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final day = ref.watch(dayAppointmentsProvider);
    final d = ref.watch(dashboardProvider);
    final repeatDue = ref.watch(repeatDueProvider).where((r) => r.isDue).length;
    final now = DateTime.now();

    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return Container(
      color: k.canvas,
      child: SafeArea(
        bottom: false,
        child: ZSkeletonSwap(
          loading: skeletonPreview() || (day.isLoading && !day.hasValue),
          skeleton: const HomeSkeleton(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              // Шапка.
              reveal(Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${Fmt.weekday(now)}, ${Fmt.dayMonth(now)}',
                            style: AppTypography.label(k.ink3)
                                .copyWith(fontSize: 13)),
                        const SizedBox(height: 2),
                        Text('${t('Привіт')}, Софіє 👋',
                            style: AppTypography.title1(k.ink)),
                      ],
                    ),
                  ),
                  const ZAvatar(initials: 'С', size: 44, ring: true),
                ],
              )),
              const SizedBox(height: 16),

              // Три показники.
              reveal(Row(
                children: [
                  Expanded(
                      child: ZStatCard(
                          label: t('Записів'),
                          value: '${d.visits}',
                          // Коли майстер сьогодні звільниться — з останнього
                          // живого запису, а не зашите «до 19:00».
                          sub: d.busyUntil == null
                              ? null
                              : tp('до {time}',
                                  {'time': Fmt.time(d.busyUntil!)}))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ZStatCard(
                          label: t('Виручка'), value: Fmt.money(d.revenue))),
                  const SizedBox(width: 10),
                  Expanded(
                      child: ZStatCard(
                          label: t('Вікна'),
                          value: '${d.freeWindows.length}',
                          sub: t('вільні'))),
                ],
              )),
              const SizedBox(height: 12),

              // Наступний клієнт.
              reveal(_NextClientHero(next: d.next, minutes: d.minutesToNext)),
              const SizedBox(height: 16),

              // Вільні вікна.
              if (d.freeWindows.isNotEmpty) ...[
                reveal(ZLabel(t('Вільні вікна'))),
                const SizedBox(height: 8),
                reveal(Row(
                  children: [
                    for (var w = 0; w < d.freeWindows.length; w++) ...[
                      if (w > 0) const SizedBox(width: 8),
                      Expanded(
                          child: _FreeWindowChip(
                              time: Fmt.time(d.freeWindows[w]))),
                    ],
                  ],
                )),
                const SizedBox(height: 14),
              ],

              // Інсайти повернення. Обидва ведуть на свій екран — раніше
              // картка виглядала як кнопка, але нічого не робила.
              if (d.lapsedCount > 0)
                reveal(_InsightCard(
                  icon: Icons.auto_awesome,
                  tone: k.success,
                  text: tp('{n} {c} давно не були — запросити?', {
                    'n': d.lapsedCount,
                    'c': tn(d.lapsedCount, 'клієнт', 'клієнти', 'клієнтів'),
                  }),
                  onTap: () => context.push(Routes.smartGaps),
                )),
              if (repeatDue > 0) ...[
                if (d.lapsedCount > 0) const SizedBox(height: 10),
                reveal(_InsightCard(
                  icon: Icons.replay,
                  tone: k.warning,
                  text: tp('{n} {c} — пора на повтор', {
                    'n': repeatDue,
                    'c': tn(repeatDue, 'клієнт', 'клієнти', 'клієнтів'),
                  }),
                  onTap: () => context.push(Routes.repeatDue),
                )),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NextClientHero extends StatelessWidget {
  const _NextClientHero({required this.next, required this.minutes});
  final Appointment? next;
  final int minutes;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    if (next == null) {
      return ZHero(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            const Text('🌙', style: TextStyle(fontSize: 26)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Записів більше немає',
                      style: AppTypography.title3(k.ink)),
                  const SizedBox(height: 2),
                  Text('Гарний день — можна видихнути',
                      style:
                          AppTypography.label(k.ink2).copyWith(fontSize: 13)),
                ],
              ),
            ),
          ],
        ),
      );
    }
    final a = next!;
    final progress = ((60 - minutes).clamp(0, 60)) / 60;
    return ZHero(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          ZAvatar(initials: a.client.initials, size: 48),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                ZLabel(
                    '${t('Наступний клієнт')} · ${tp('за {n} хв', {
                          'n': minutes
                        })}',
                    color: k.accent),
                const SizedBox(height: 2),
                Text(a.client.name,
                    style: AppTypography.title3(k.ink)
                        .copyWith(fontSize: 17, fontWeight: FontWeight.w800)),
                const SizedBox(height: 1),
                Text(
                    '${a.service.name} · ${Fmt.time(a.start)} · ${Fmt.money(a.service.price)}',
                    style: AppTypography.label(k.ink2).copyWith(fontSize: 13)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ZLiveRing(
            progress: progress,
            size: 52,
            stroke: 4,
            center: Text('$minutes′',
                style: AppTypography.tabular(AppTypography.label(k.ink))
                    .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _FreeWindowChip extends StatelessWidget {
  const _FreeWindowChip({required this.time});
  final String time;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return GestureDetector(
      onTap: () => showCreateAppointmentSheet(context),
      child: CustomPaint(
        painter: _DashChipPainter(),
        child: Container(
          decoration: BoxDecoration(
              color: const Color(0x0F8B8BF0),
              borderRadius: BorderRadius.circular(16)),
          padding: const EdgeInsets.symmetric(vertical: 11),
          child: Column(
            children: [
              Text(time,
                  style: AppTypography.tabular(AppTypography.title3(k.ink))
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(t('заповнити'),
                  style: AppTypography.label(k.accent).copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashChipPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final rrect =
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = const Color(0x808B8BF0)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final m in path.computeMetrics()) {
      var dist = 0.0;
      while (dist < m.length) {
        final len = (6.0).clamp(0, m.length - dist).toDouble();
        canvas.drawPath(m.extractPath(dist, dist + len), paint);
        dist += 11;
      }
    }
  }

  @override
  bool shouldRepaint(_DashChipPainter oldDelegate) => false;
}

/// Підказка дня: коротка думка застосунку і перехід туди, де з нею щось
/// можна зробити.
class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.icon,
    required this.text,
    required this.tone,
    required this.onTap,
  });

  /// Іконка, а не емодзі: шрифт емодзі CanvasKit тягне з мережі, і на повільному
  /// з'єднанні на його місці кілька секунд стоїть порожній квадрат.
  final IconData icon;
  final String text;
  final Color tone;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Semantics(
      button: true,
      label: text,
      child: GestureDetector(
        onTap: () {
          zTap();
          onTap();
        },
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [tone.withValues(alpha: 0.08), k.surface],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: k.line, width: 1),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          child: Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tone.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, size: 16, color: tone),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(text,
                    style: AppTypography.body(k.ink).copyWith(fontSize: 13)),
              ),
              const SizedBox(width: 8),
              Text(t('Показати'),
                  style: AppTypography.label(tone)
                      .copyWith(fontSize: 13, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
