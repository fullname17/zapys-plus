import '../../core/localization/app_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/boot_uri.dart';
import '../../core/time/demo_clock.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/skeleton.dart';
import '../../ui/z.dart';
import '../create/create_appointment_sheet.dart';
import 'appointment_sheet.dart';
import 'edit_appointment_sheet.dart';

enum CalendarView { day, week, month }

/// Початковий режим можна задати через ?view=week|month у URL — це
/// використовується для знімків екранів у CI (кожен режим — окремим маршрутом).
CalendarView _initialView() {
  return switch (bootParam('view')) {
    'week' => CalendarView.week,
    'month' => CalendarView.month,
    _ => CalendarView.day,
  };
}

final calendarViewProvider =
    StateProvider<CalendarView>((ref) => _initialView());

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
DateTime _weekStart(DateTime d) =>
    _dateOnly(d).subtract(Duration(days: d.weekday - 1));

/// Палітра груп послуг: кожна категорія отримує свій сталий колір, тож у
/// календарі видно тип візиту без підпису. Базові б'юті-групи закріплені за
/// звичними кольорами, решта розкладається по палітрі за назвою — так будь-яка
/// сфера (тату, грумінг, автосервіс) одразу виглядає осмислено.
const List<Color> _categoryPalette = [
  Color(0xFF9A9AF6), // iris
  Color(0xFF46D08A), // зелений
  Color(0xFFE6B24E), // бурштин
  Color(0xFFE86FA6), // рожевий
  Color(0xFF5B8DEF), // синій
  Color(0xFFB07CE8), // фіолетовий
  Color(0xFF46C2D0), // бірюзовий
];

const Map<String, Color> _pinnedCategoryColors = {
  'Манікюр': Color(0xFF9A9AF6),
  'Педикюр': Color(0xFF46D08A),
};

Color _colorForCategory(String name) {
  final pinned = _pinnedCategoryColors[name];
  if (pinned != null) return pinned;
  var hash = 0;
  for (final unit in name.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return _categoryPalette[hash % _categoryPalette.length];
}

/// Колір запису. Спершу за групою послуги, далі — за id (демо-послуги сиду
/// заведені до появи категорій у формі створення).
Color apptColor(String serviceId, {String? category}) {
  if (category != null && category.trim().isNotEmpty) {
    return _colorForCategory(category.trim());
  }
  if (serviceId.contains('gel') ||
      serviceId.contains('man') ||
      serviceId.contains('art')) {
    return const Color(0xFF9A9AF6);
  }
  if (serviceId.contains('spa') ||
      serviceId.contains('exp') ||
      serviceId.contains('ped')) {
    return const Color(0xFF46D08A);
  }
  return const Color(0xFFE6B24E);
}

/// Календар — серце продукту. День (лінія «зараз» + вільні вікна), Тиждень,
/// Місяць-пульс. Реактивні дані з Drift, тап по запису → картка.
class CalendarScreen extends ConsumerStatefulWidget {
  const CalendarScreen({super.key});

  @override
  ConsumerState<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends ConsumerState<CalendarScreen> {
  /// Листи (картка запису, перенесення, редагування) — теж екрани продукту,
  /// тож їх треба звіряти з макетами. ?sheet=appointment|move|edit відкриває
  /// потрібний лист на першому записі дня одразу після завантаження даних —
  /// той самий механізм, що й ?view= для режимів календаря.
  bool _sheetOpened = false;

  void _maybeOpenBootSheet(List<Appointment> day) {
    if (_sheetOpened) return;
    final which = bootParam('sheet');
    if (which == null || day.isEmpty) return;
    _sheetOpened = true;

    final items = [...day]..sort((a, b) => a.start.compareTo(b.start));
    // Найближчий майбутній живий запис — на ньому видно всі дії картки.
    final now = demoNow();
    final a = items.firstWhere(
      (x) => x.isActive && x.start.isAfter(now),
      orElse: () => items.first,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      switch (which) {
        case 'appointment':
          showAppointmentSheet(context, a);
        case 'move':
          showMoveAppointmentSheet(context, a);
        case 'edit':
          showEditAppointmentSheet(context, a);
        case 'create':
          showCreateAppointmentSheet(context);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final view = ref.watch(calendarViewProvider);
    _maybeOpenBootSheet(
        ref.watch(dayAppointmentsProvider).value ?? const <Appointment>[]);
    return Container(
      color: context.kavio.canvas,
      child: SafeArea(
        bottom: false,
        child: switch (view) {
          CalendarView.day => const _DayView(),
          CalendarView.week => const _WeekView(),
          CalendarView.month => const _MonthView(),
        },
      ),
    );
  }
}

class _Seg extends ConsumerWidget {
  const _Seg();
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(calendarViewProvider);
    return ZSegmented(
      items: [t('День'), t('Тиждень'), t('Місяць')],
      index: view.index,
      onChanged: (i) => ref.read(calendarViewProvider.notifier).state =
          CalendarView.values[i],
    );
  }
}

// ─────────────────────────────────────────── День

class _DayView extends ConsumerWidget {
  const _DayView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final day = ref.watch(selectedDayProvider);
    final apptsAsync = ref.watch(dayAppointmentsProvider);
    if (skeletonPreview() || (apptsAsync.isLoading && !apptsAsync.hasValue)) {
      return const ZSkeleton(child: CalendarDaySkeleton());
    }
    final list = apptsAsync.value ?? const <Appointment>[];
    final now = demoNow();
    final isToday = _dateOnly(day) == _dateOnly(now);

    final completed = list
        .where((a) => a.status == AppointmentStatus.completed)
        .fold<int>(0, (s, a) => s + a.service.price);
    // Скасовані записи та неявки місце не тримають — ні в лічильнику, ні у
    // вільних годинах: вікно реально вільне й на нього можна записати.
    final live = list.where((a) => a.isActive).toList(growable: false);
    final schedule = scheduleOrFallback(ref);
    final freeMin = _freeMinutes(live, day, schedule);

    void shift(int d) => ref.read(selectedDayProvider.notifier).state =
        _dateOnly(day).add(Duration(days: d));

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(Fmt.weekday(day),
                      style:
                          AppTypography.label(k.ink3).copyWith(fontSize: 12)),
                  Text(Fmt.dayMonth(day), style: AppTypography.title1(k.ink)),
                ],
              ),
            ),
            _RoundBtn(icon: Icons.chevron_left, onTap: () => shift(-1)),
            const SizedBox(width: 8),
            _RoundBtn(icon: Icons.chevron_right, onTap: () => shift(1)),
          ],
        ),
        const SizedBox(height: 14),
        const _Seg(),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
                child: ZStatCard(label: t('Записів'), value: '${live.length}')),
            const SizedBox(width: 8),
            Expanded(
                child: ZStatCard(
                    label: t('Виручка'), value: Fmt.money(completed))),
            const SizedBox(width: 8),
            Expanded(
                child: ZStatCard(
                    label: t('Вільно'),
                    value: tp('{n} год', {'n': (freeMin / 60).round()}))),
          ],
        ),
        const SizedBox(height: 16),
        if (list.isEmpty)
          _EmptyDay()
        else
          ..._timeline(context, list, now, isToday, day, schedule),
      ],
    );
  }

  /// Скільки годин дня ще вільні — у межах робочого дня майстра, з відрахунком
  /// перерви. У вихідний вільних годин немає, а не «10».
  int _freeMinutes(List<Appointment> list, DateTime day, Schedule schedule) {
    final wd = schedule.forDate(day);
    if (!wd.isOpen) return 0;
    DateTime at(int m) =>
        DateTime(day.year, day.month, day.day).add(Duration(minutes: m));
    final open = at(wd.openMinutes);
    final close = at(wd.closeMinutes);
    final total = close.difference(open).inMinutes;

    var busy = wd.hasBreak ? wd.breakEndMinutes! - wd.breakStartMinutes! : 0;
    for (final a in list) {
      final s = a.start.isBefore(open) ? open : a.start;
      final e = a.end.isAfter(close) ? close : a.end;
      if (e.isAfter(s)) busy += e.difference(s).inMinutes;
    }
    return (total - busy).clamp(0, total);
  }

  /// Стрічка дня: записи, вільні вікна й лінія «зараз» — усе строго за часом.
  ///
  /// Вільні вікна рахуємо тільки по живих записах (скасований візит місце не
  /// тримає), але в список вставляємо за їхнім власним часом. Інакше вікно,
  /// що відкрилося замість скасованого запису, з'їжджало вниз і опинялося
  /// під карткою, яку воно замінює.
  List<Widget> _timeline(BuildContext context, List<Appointment> list,
      DateTime now, bool isToday, DateTime day, Schedule schedule) {
    final items = [...list]..sort((a, b) => a.start.compareTo(b.start));
    final wd = schedule.forDate(day);

    // 1. Збираємо рядки з мітками часу, ще не малюючи.
    final rows = <({DateTime at, int order, Widget child})>[];
    for (final a in items) {
      rows.add((
        at: a.start,
        order: 1,
        child: _TimelineRow(time: Fmt.time(a.start), child: _ApptCard(a)),
      ));
    }

    if (wd.isOpen) {
      DateTime at(int m) =>
          DateTime(day.year, day.month, day.day).add(Duration(minutes: m));
      final live = items.where((a) => a.isActive).toList();
      var cursor = at(wd.openMinutes);
      final close = at(wd.closeMinutes);

      void gap(DateTime from, DateTime to) {
        final minutes = to.difference(from).inMinutes;
        if (minutes < 40) return;
        rows.add((
          at: from,
          order: 0, // вікно йде перед карткою, що починається тієї ж хвилини
          child: _TimelineRow(
            time: Fmt.time(from),
            child: ZFreeSlot(
              duration: Fmt.duration(minutes),
              // Тап по вікну відкриває лист уже на потрібному дні.
              onTap: () => showCreateAppointmentSheet(context, at: from),
            ),
          ),
        ));
      }

      for (final a in live) {
        if (a.start.isAfter(cursor)) gap(cursor, a.start);
        if (a.end.isAfter(cursor)) cursor = a.end;
      }
      if (cursor.isBefore(close)) gap(cursor, close);
    }

    if (isToday) {
      rows.add((at: now, order: 2, child: _NowLine(time: now)));
    }

    // 2. Сортуємо все за часом і лише тоді анімуємо появу.
    rows.sort((a, b) {
      final byTime = a.at.compareTo(b.at);
      return byTime != 0 ? byTime : a.order.compareTo(b.order);
    });
    return [
      for (var i = 0; i < rows.length; i++)
        StaggerReveal(index: i, child: rows[i].child),
    ];
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.time, required this.child});
  final String time;
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(top: 4, right: 6),
              child: Text(time,
                  textAlign: TextAlign.right,
                  style: AppTypography.tabular(AppTypography.label(k.ink3))
                      .copyWith(fontSize: 12)),
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _ApptCard extends StatelessWidget {
  const _ApptCard(this.a);
  final Appointment a;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    // Скасований запис і неявка лишаються на таймлайні (це історія дня), але
    // гаснуть: колір послуги йде в сірий, картка притишується, час
    // закреслюється. Вікно при цьому вже вважається вільним.
    final active = a.isActive;
    final c =
        active ? apptColor(a.service.id, category: a.service.category) : k.ink3;
    return GestureDetector(
      onTap: () => showAppointmentSheet(context, a),
      child: AnimatedOpacity(
        opacity: active ? 1 : 0.55,
        duration: const Duration(milliseconds: 220),
        curve: Motion.enter,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: const Alignment(-0.8, -1),
                    end: const Alignment(0.8, 1),
                    colors: [
                      c.withValues(alpha: active ? 0.18 : 0.10),
                      c.withValues(alpha: active ? 0.07 : 0.04),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: c.withValues(alpha: active ? 0.28 : 0.18),
                      width: 1),
                ),
                padding: const EdgeInsets.fromLTRB(15, 12, 13, 12),
                child: Row(
                  children: [
                    ZAvatar(
                        initials: a.client.initials,
                        size: 30,
                        color: c,
                        bg: c.withValues(alpha: 0.18)),
                    const SizedBox(width: 9),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(a.client.name,
                              style: AppTypography.title3(k.ink).copyWith(
                                fontSize: 14,
                                decoration:
                                    active ? null : TextDecoration.lineThrough,
                                decorationColor: k.ink3,
                              )),
                          Text(
                              active
                                  ? '${a.service.name} · ${Fmt.duration(a.service.durationMinutes)}'
                                  : '${a.service.name} · ${t(a.status.label)}',
                              style: AppTypography.label(k.ink2)
                                  .copyWith(fontSize: 12)),
                        ],
                      ),
                    ),
                    Text(Fmt.money(a.service.price),
                        style:
                            AppTypography.tabular(AppTypography.title3(k.ink))
                                .copyWith(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800,
                                    decoration: active
                                        ? null
                                        : TextDecoration.lineThrough,
                                    decorationColor: k.ink3)),
                  ],
                ),
              ),
              Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  child: Container(width: 3, color: c)),
            ],
          ),
        ),
      ),
    );
  }
}

class _NowLine extends StatelessWidget {
  const _NowLine({required this.time});
  final DateTime time;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Text(Fmt.time(time),
                  textAlign: TextAlign.right,
                  style: AppTypography.tabular(AppTypography.label(k.accent))
                      .copyWith(fontSize: 11, fontWeight: FontWeight.w800)),
            ),
          ),
          Container(
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: k.accent,
              shape: BoxShape.circle,
              boxShadow: const [
                BoxShadow(color: Color(0xBF8B8BF0), blurRadius: 10)
              ],
            ),
          ),
          Expanded(
            child: Container(
              height: 2,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                    colors: [k.accent, k.accent.withValues(alpha: 0)]),
              ),
            ),
          ),
          Text(t('зараз'),
              style: AppTypography.label(k.accent)
                  .copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _RoundBtn extends StatelessWidget {
  const _RoundBtn({required this.icon, required this.onTap});
  final IconData icon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34,
        height: 34,
        decoration: BoxDecoration(
            color: k.surface2, borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 18, color: k.ink2),
      ),
    );
  }
}

class _EmptyDay extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Padding(
      padding: const EdgeInsets.only(top: 60),
      child: Column(
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: k.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: k.line),
            ),
            child:
                Icon(Icons.event_available_outlined, size: 36, color: k.accent),
          ),
          const SizedBox(height: 16),
          Text(t('Вільний день'), style: AppTypography.title2(k.ink)),
          const SizedBox(height: 8),
          SizedBox(
            width: 240,
            child: Text(
              t('Жодного запису. Ідеальний час додати перший або поділитися онлайн-записом.'),
              textAlign: TextAlign.center,
              style: AppTypography.body(k.ink2).copyWith(fontSize: 14),
            ),
          ),
          const SizedBox(height: 20),
          ZButton(
              label: t('＋ Новий запис'),
              expand: false,
              onTap: () => showCreateAppointmentSheet(context)),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────── Тиждень

class _WeekView extends ConsumerWidget {
  const _WeekView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final day = ref.watch(selectedDayProvider);
    final start = _weekStart(day);
    final end = start.add(const Duration(days: 7));
    final list =
        ref.watch(rangeAppointmentsProvider((start: start, end: end))).value ??
            const <Appointment>[];
    final today = _dateOnly(demoNow());

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Text(t('Тиждень'), style: AppTypography.title1(k.ink)),
        const SizedBox(height: 14),
        const _Seg(),
        const SizedBox(height: 16),
        Row(
          children: [
            const SizedBox(width: 22),
            for (var i = 0; i < 7; i++)
              Expanded(
                  child: _WeekHeadCell(
                      date: start.add(Duration(days: i)), today: today)),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 430,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 22,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final h in [10, 12, 14, 16, 18])
                      Text('$h',
                          style:
                              AppTypography.tabular(AppTypography.label(k.ink3))
                                  .copyWith(fontSize: 9)),
                  ],
                ),
              ),
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: _WeekColumn(
                    date: start.add(Duration(days: i)),
                    today: today,
                    items: list
                        .where((a) =>
                            _dateOnly(a.start) == start.add(Duration(days: i)))
                        .toList(),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekHeadCell extends StatelessWidget {
  const _WeekHeadCell({required this.date, required this.today});
  final DateTime date;
  final DateTime today;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final isToday = _dateOnly(date) == today;
    final names = [
      t('Пн'),
      t('Вт'),
      t('Ср'),
      t('Чт'),
      t('Пт'),
      t('Сб'),
      t('Нд')
    ];
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 2),
      padding: const EdgeInsets.symmetric(vertical: 7),
      decoration: BoxDecoration(
        color: isToday ? k.accentTint : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(names[date.weekday - 1],
              style: AppTypography.label(isToday ? k.accent : k.ink3)
                  .copyWith(fontSize: 10)),
          Text('${date.day}',
              style: AppTypography.tabular(
                      AppTypography.title3(isToday ? k.accent : k.ink))
                  .copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _WeekColumn extends StatelessWidget {
  const _WeekColumn(
      {required this.date, required this.today, required this.items});
  final DateTime date;
  final DateTime today;
  final List<Appointment> items;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final isToday = _dateOnly(date) == today;
    const topH = 10.0, botH = 18.0; // 10:00–18:00
    double frac(DateTime t) =>
        ((t.hour + t.minute / 60) - topH) / (botH - topH);
    return LayoutBuilder(builder: (context, box) {
      final h = box.maxHeight;
      return Container(
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: isToday ? k.accentTint.withValues(alpha: 0.4) : k.surface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: k.line),
        ),
        child: Stack(
          children: [
            for (final a in items)
              Positioned(
                left: 3,
                right: 3,
                top: (frac(a.start).clamp(0.0, 1.0)) * h,
                height: ((a.service.durationMinutes / 60 / (botH - topH)) * h)
                    .clamp(10.0, h),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: const Alignment(-0.8, -1),
                              end: const Alignment(0.8, 1),
                              colors: [
                                apptColor(a.service.id).withValues(alpha: 0.36),
                                apptColor(a.service.id).withValues(alpha: 0.16),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(
                                color: apptColor(a.service.id)
                                    .withValues(alpha: 0.5),
                                width: 1),
                          ),
                        ),
                      ),
                      Positioned(
                          left: 0,
                          top: 0,
                          bottom: 0,
                          child: Container(
                              width: 2.5, color: apptColor(a.service.id))),
                    ],
                  ),
                ),
              ),
          ],
        ),
      );
    });
  }
}

// ─────────────────────────────────────────── Місяць

class _MonthView extends ConsumerWidget {
  const _MonthView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final day = ref.watch(selectedDayProvider);
    final monthStart = DateTime(day.year, day.month, 1);
    final nextMonth = DateTime(day.year, day.month + 1, 1);
    final list = ref
            .watch(
                rangeAppointmentsProvider((start: monthStart, end: nextMonth)))
            .value ??
        const <Appointment>[];
    final counts = <int, int>{};
    for (final a in list) {
      counts[a.start.day] = (counts[a.start.day] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(1, (m, v) => v > m ? v : m);
    final daysInMonth = DateTime(day.year, day.month + 1, 0).day;
    final leading = monthStart.weekday - 1;
    final today = demoNow();
    final labels = [
      t('Пн'),
      t('Вт'),
      t('Ср'),
      t('Чт'),
      t('Пт'),
      t('Сб'),
      t('Нд')
    ];

    final cells = <Widget>[];
    for (var i = 0; i < leading; i++) {
      cells.add(const SizedBox());
    }
    for (var dnum = 1; dnum <= daysInMonth; dnum++) {
      final count = counts[dnum] ?? 0;
      final intensity = count / maxCount;
      final isToday = dnum == today.day && day.month == today.month;
      cells.add(_MonthCell(
        day: dnum,
        intensity: intensity,
        isToday: isToday,
        onTap: () {
          ref.read(selectedDayProvider.notifier).state =
              DateTime(day.year, day.month, dnum);
          ref.read(calendarViewProvider.notifier).state = CalendarView.day;
        },
      ));
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(_monthName(day.month), style: AppTypography.title1(k.ink)),
            Text(
                Fmt.money(list
                    .where((a) => a.status == AppointmentStatus.completed)
                    .fold<int>(0, (s, a) => s + a.service.price)),
                style: AppTypography.label(k.ink2).copyWith(fontSize: 13)),
          ],
        ),
        const SizedBox(height: 14),
        const _Seg(),
        const SizedBox(height: 16),
        Row(
          children: [
            for (final l in labels)
              Expanded(
                child: Center(
                  child: Text(l,
                      style: AppTypography.label(k.ink3)
                          .copyWith(fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: 5,
          crossAxisSpacing: 5,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
        const SizedBox(height: 16),
        _MonthLegend(),
      ],
    );
  }

  String _monthName(int m) {
    const names = [
      'Січень',
      'Лютий',
      'Березень',
      'Квітень',
      'Травень',
      'Червень',
      'Липень',
      'Серпень',
      'Вересень',
      'Жовтень',
      'Листопад',
      'Грудень'
    ];
    return t(names[m - 1]);
  }
}

class _MonthCell extends StatelessWidget {
  const _MonthCell({
    required this.day,
    required this.intensity,
    required this.isToday,
    required this.onTap,
  });
  final int day;
  final double intensity;
  final bool isToday;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final has = intensity > 0;
    return GestureDetector(
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: has
                ? const Color(0xFF8B8BF0)
                    .withValues(alpha: 0.1 + intensity * 0.55)
                : k.surface,
            borderRadius: BorderRadius.circular(11),
            border: Border.all(color: isToday ? k.accent : k.line),
            boxShadow: isToday
                ? const [
                    BoxShadow(
                        color: Color(0xBF8B8BF0),
                        blurRadius: 12,
                        spreadRadius: -4,
                        offset: Offset(0, 4))
                  ]
                : null,
          ),
          child: Stack(
            children: [
              Positioned(
                top: 5,
                right: 5,
                child: Text('$day',
                    style: AppTypography.tabular(AppTypography.label(
                            intensity > 0.6 ? Colors.white : k.ink2))
                        .copyWith(
                            fontSize: 10,
                            fontWeight:
                                isToday ? FontWeight.w800 : FontWeight.w600)),
              ),
              if (has)
                Positioned(
                  left: 5,
                  bottom: 5,
                  child: Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                        color: intensity > 0.75 ? Colors.white : k.accent,
                        shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MonthLegend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Row(
      children: [
        Text(t('тихо'),
            style: AppTypography.label(k.ink3).copyWith(fontSize: 10)),
        const SizedBox(width: 8),
        for (final o in [0.16, 0.36, 0.58, 0.8, 1.0])
          Container(
            width: 16,
            height: 8,
            margin: const EdgeInsets.only(right: 4),
            decoration: BoxDecoration(
                color: const Color(0xFF8B8BF0).withValues(alpha: o),
                borderRadius: BorderRadius.circular(3)),
          ),
        const SizedBox(width: 4),
        Text(t('щільно'),
            style: AppTypography.label(k.ink3).copyWith(fontSize: 10)),
      ],
    );
  }
}
