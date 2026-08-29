import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/skeleton.dart';
import '../../ui/z.dart';
import '../create/schedule_picker.dart' show hhmm;

/// Розклад майстра: години по кожному дню, вихідні, перерва і крок сітки.
/// Це той екран, без якого застосунок вигадує розклад за майстра — раніше всі
/// вільні вікна рахувалися як «10:00–20:00 щодня, по пів години».
class ScheduleScreen extends ConsumerWidget {
  const ScheduleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final async = ref.watch(scheduleProvider);
    final loading = skeletonPreview() || (async.isLoading && !async.hasValue);
    final schedule = async.value ?? Schedule.fallback;

    Future<void> save(Schedule next) =>
        ref.read(scheduleRepositoryProvider).save(next);

    Future<void> setDay(WorkingDay day) => save(schedule.copyWith(days: [
          for (final d in schedule.days) d.weekday == day.weekday ? day : d,
        ]));

    var i = 0;
    Widget reveal(Widget c) => StaggerReveal(index: i++, child: c);

    return Scaffold(
      backgroundColor: k.canvas,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const _TopBar(),
            Expanded(
              child: ZSkeletonSwap(
                loading: loading,
                skeleton: const RowsSkeleton(count: 7),
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                  children: [
                    reveal(Text(
                      t('Застосунок пропонує клієнтам тільки цей час.'),
                      style:
                          AppTypography.body(k.ink2).copyWith(fontSize: 13.5),
                    )),
                    const SizedBox(height: 18),
                    reveal(ZLabel(t('Тиждень'))),
                    const SizedBox(height: 10),
                    for (final d in schedule.days)
                      reveal(Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: _DayRow(day: d, onChanged: setDay),
                      )),
                    const SizedBox(height: 8),
                    reveal(ZLabel(t('Крок запису'))),
                    const SizedBox(height: 8),
                    reveal(Text(
                      t('Через скільки хвилин можна починати наступний візит.'),
                      style: AppTypography.label(k.ink3).copyWith(fontSize: 12),
                    )),
                    const SizedBox(height: 10),
                    reveal(Wrap(
                      spacing: 8,
                      children: [
                        for (final step in const [5, 10, 15, 30])
                          ZChip(
                            selected: schedule.slotStepMinutes == step,
                            onTap: () =>
                                save(schedule.copyWith(slotStepMinutes: step)),
                            child: Text(
                              Fmt.duration(step),
                              style: AppTypography.tabular(AppTypography.label(
                                      schedule.slotStepMinutes == step
                                          ? Colors.white
                                          : k.ink))
                                  .copyWith(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600),
                            ),
                          ),
                      ],
                    )),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Рядок дня: перемикач «працюю», години й перерва.
class _DayRow extends StatelessWidget {
  const _DayRow({required this.day, required this.onChanged});
  final WorkingDay day;
  final ValueChanged<WorkingDay> onChanged;

  static const _names = [
    'Понеділок',
    'Вівторок',
    'Середа',
    'Четвер',
    "П'ятниця",
    'Субота',
    'Неділя'
  ];

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final on = day.isOpen;

    Future<void> pick(BuildContext context, String title, int current,
        ValueChanged<int> apply) async {
      final picked =
          await showTimeChooser(context, title: title, current: current);
      if (picked != null) apply(picked);
    }

    return ZCard(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(t(_names[day.weekday - 1]),
                    style: AppTypography.title3(on ? k.ink : k.ink3)
                        .copyWith(fontSize: 15)),
              ),
              if (!on)
                Text(t('вихідний'),
                    style:
                        AppTypography.label(k.ink3).copyWith(fontSize: 12.5)),
              const SizedBox(width: 8),
              Switch(
                value: on,
                activeThumbColor: Colors.white,
                activeTrackColor: k.accent,
                inactiveTrackColor: k.surface3,
                onChanged: (v) {
                  zTap();
                  onChanged(day.copyWith(isOpen: v));
                },
              ),
            ],
          ),
          if (on) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                _TimeButton(
                  label: hhmm(day.openMinutes),
                  onTap: () => pick(context, t('Початок дня'), day.openMinutes,
                      (v) => onChanged(day.copyWith(openMinutes: v))),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('—',
                      style:
                          AppTypography.label(k.ink3).copyWith(fontSize: 13)),
                ),
                _TimeButton(
                  label: hhmm(day.closeMinutes),
                  onTap: () => pick(context, t('Кінець дня'), day.closeMinutes,
                      (v) => onChanged(day.copyWith(closeMinutes: v))),
                ),
                const Spacer(),
                if (!day.hasBreak)
                  GestureDetector(
                    onTap: () {
                      zTap();
                      onChanged(day.copyWith(
                          breakStartMinutes: 840, breakEndMinutes: 900));
                    },
                    child: Text('+ ${t('перерва')}',
                        style: AppTypography.label(k.accent).copyWith(
                            fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
            if (day.hasBreak) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.free_breakfast_outlined, size: 15, color: k.ink3),
                  const SizedBox(width: 8),
                  _TimeButton(
                    label: hhmm(day.breakStartMinutes!),
                    small: true,
                    onTap: () => pick(
                        context,
                        t('Початок перерви'),
                        day.breakStartMinutes!,
                        (v) => onChanged(day.copyWith(breakStartMinutes: v))),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: Text('—',
                        style:
                            AppTypography.label(k.ink3).copyWith(fontSize: 12)),
                  ),
                  _TimeButton(
                    label: hhmm(day.breakEndMinutes!),
                    small: true,
                    onTap: () => pick(
                        context,
                        t('Кінець перерви'),
                        day.breakEndMinutes!,
                        (v) => onChanged(day.copyWith(breakEndMinutes: v))),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      zTap();
                      onChanged(day.copyWith(clearBreak: true));
                    },
                    child: Text(t('прибрати'),
                        style: AppTypography.label(k.ink3).copyWith(
                            fontSize: 12, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton(
      {required this.label, required this.onTap, this.small = false});
  final String label;
  final VoidCallback onTap;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
            horizontal: small ? 10 : 13, vertical: small ? 6 : 8),
        decoration: BoxDecoration(
          color: k.surface2,
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: k.line),
        ),
        child: Text(label,
            style: AppTypography.tabular(AppTypography.label(k.ink)).copyWith(
                fontSize: small ? 12.5 : 14, fontWeight: FontWeight.w700)),
      ),
    );
  }
}

/// Вибір часу чипами по 15 хвилин — у стилі застосунку, без системного
/// годинника Material, який вибивається з темної теми.
Future<int?> showTimeChooser(BuildContext context,
    {required String title, required int current}) {
  return showKavioSheet<int>(context, builder: (sheetContext) {
    final k = sheetContext.kavio;
    return KavioSheet(
      title: title,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (var m = 6 * 60; m <= 23 * 60 + 45; m += 15)
            ZChip(
              selected: m == current,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              onTap: () => Navigator.of(sheetContext).pop(m),
              child: Text(
                hhmm(m),
                style: AppTypography.tabular(AppTypography.label(
                        m == current ? Colors.white : k.ink))
                    .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  });
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 20, 4),
      child: Row(
        children: [
          const ZBackButton(),
          const SizedBox(width: 10),
          Expanded(
              child: Text(t('Розклад'), style: AppTypography.title1(k.ink))),
        ],
      ),
    );
  }
}
