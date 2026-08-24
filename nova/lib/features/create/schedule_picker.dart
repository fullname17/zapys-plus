import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/z.dart';

/// Спільний вибір часу для «Новий запис», «Перенести» і «Редагувати».
/// Одна фізика й один вигляд у всіх трьох сценаріях: перенос відчувається так
/// само, як створення, і не має власних правил зайнятості.

/// Робочий день студії. Слоти йдуть по пів години, останній має вміститися
/// цілком до закриття.
const int kOpenHour = 10;
const int kCloseHour = 20;
const int kSlotStepMinutes = 30;

/// Вільні початки на [day] під послугу тривалістю [durationMinutes].
///
/// [ignoreId] виключає сам запис, який переносимо — інакше він конфліктує
/// сам із собою, і власний поточний час не показується як вільний.
/// Скасовані записи та неявки місце не тримають (див. [Appointment.isActive]).
List<DateTime> freeSlotsFor({
  required List<Appointment> dayAppointments,
  required DateTime day,
  required int durationMinutes,
  String? ignoreId,
}) {
  final close = DateTime(day.year, day.month, day.day, kCloseHour);
  final busy = dayAppointments
      .where((a) => a.isActive && a.id != ignoreId)
      .toList(growable: false);

  final slots = <DateTime>[];
  for (var h = kOpenHour; h < kCloseHour; h++) {
    for (var m = 0; m < 60; m += kSlotStepMinutes) {
      final start = DateTime(day.year, day.month, day.day, h, m);
      final end = start.add(Duration(minutes: durationMinutes));
      if (!end.isBefore(close)) continue;
      final overlaps =
          busy.any((a) => start.isBefore(a.end) && end.isAfter(a.start));
      if (!overlaps) slots.add(start);
    }
  }
  return slots;
}

/// Чи вільний конкретний час (для перевірки перед збереженням).
bool slotIsFree({
  required List<Appointment> dayAppointments,
  required DateTime start,
  required int durationMinutes,
  String? ignoreId,
}) {
  final end = start.add(Duration(minutes: durationMinutes));
  return !dayAppointments.any((a) =>
      a.isActive &&
      a.id != ignoreId &&
      start.isBefore(a.end) &&
      end.isAfter(a.start));
}

/// Смуга найближчих днів. Обраний день — фірмовий градієнт, решта — surface2.
/// Вигляд один-в-один як у «Новий запис» (екран уже звірений із макетом), тож
/// «Перенести» й «Редагувати» не виглядають як інший застосунок.
class ScheduleDayStrip extends StatelessWidget {
  const ScheduleDayStrip({
    super.key,
    required this.day,
    required this.onChanged,
    this.days = 10,
    this.from,
  });
  final DateTime day;
  final ValueChanged<DateTime> onChanged;
  final int days;
  final DateTime? from;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final now = DateTime.now();
    final first = from ?? DateTime(now.year, now.month, now.day);
    return SizedBox(
      height: 62,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = first.add(Duration(days: i));
          final on = d == day;
          return GestureDetector(
            onTap: () {
              zTap();
              onChanged(d);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              curve: Motion.enter,
              width: 50,
              decoration: BoxDecoration(
                color: on ? null : k.surface2,
                gradient: on ? FX.brandButton : null,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(Fmt.weekday(d).substring(0, 2),
                      style: AppTypography.label(on ? Colors.white70 : k.ink3)
                          .copyWith(fontSize: 10)),
                  Text('${d.day}',
                      style: AppTypography.tabular(
                              AppTypography.title3(on ? Colors.white : k.ink))
                          .copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Сітка вільних слотів на обраний день. Сама читає записи дня з БД, тож
/// зайнятість завжди свіжа — і в «Новий запис», і в «Перенести».
class ScheduleSlots extends ConsumerWidget {
  const ScheduleSlots({
    super.key,
    required this.day,
    required this.durationMinutes,
    required this.selected,
    required this.onChanged,
    this.ignoreId,
  });
  final DateTime day;
  final int durationMinutes;
  final DateTime? selected;
  final ValueChanged<DateTime> onChanged;
  final String? ignoreId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final dayStart = DateTime(day.year, day.month, day.day);
    final appts = ref
            .watch(rangeAppointmentsProvider(
                (start: dayStart, end: dayStart.add(const Duration(days: 1)))))
            .value ??
        const <Appointment>[];

    final slots = freeSlotsFor(
      dayAppointments: appts,
      day: dayStart,
      durationMinutes: durationMinutes,
      ignoreId: ignoreId,
    );

    if (slots.isEmpty) {
      return Text(t('На цей день вільних вікон немає'),
          style: AppTypography.label(k.ink3).copyWith(fontSize: 13));
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in slots)
          ZChip(
            selected: selected == s,
            onTap: () => onChanged(s),
            child: Text(
              Fmt.time(s),
              style: AppTypography.tabular(
                      AppTypography.label(selected == s ? Colors.white : k.ink))
                  .copyWith(fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
      ],
    );
  }
}
