import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/analytics/analytics_events.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/z.dart';
import '../create/appointment_reminders.dart';
import '../create/create_appointment_sheet.dart';

/// Фішка «Магічний перезапис»: на касі, після оплати, застосунок ловить
/// наступний візит («ходить кожні 3 тижні → записати наперед?»).
///
/// Ритм рахується з історії клієнта, вільне вікно шукається в його ж часі доби,
/// а кнопка справді створює запис. Раніше екран був макетом: Олена, 12 серпня,
/// 10:30 — однакові в кого завгодно.
class MagicRebookScreen extends ConsumerWidget {
  const MagicRebookScreen({super.key, this.appointmentId});

  /// Візит, який щойно завершили. Якщо екран відкрили з меню — беремо
  /// останній завершений сьогодні.
  final String? appointmentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final s = ref.watch(rebookSuggestionProvider(appointmentId));
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
              child: s == null
                  ? const _NothingCompleted()
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                      children: [
                        reveal(Text(t('Візит завершено'),
                            style: AppTypography.title1(k.ink))),
                        const SizedBox(height: 6),
                        reveal(Text(
                            '${s.appointment.client.name} · ${s.appointment.service.name} · ${Fmt.money(s.appointment.service.price)}',
                            style: AppTypography.label(k.ink3)
                                .copyWith(fontSize: 13))),
                        const SizedBox(height: 16),
                        reveal(_PaidCard(amount: s.appointment.service.price)),
                        const SizedBox(height: 14),
                        reveal(_RebookHero(suggestion: s)),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Екран відкрили, а завершених візитів сьогодні ще немає.
class _NothingCompleted extends StatelessWidget {
  const _NothingCompleted();

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: k.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: k.line),
              ),
              child: Icon(Icons.auto_awesome, size: 34, color: k.accent),
            ),
            const SizedBox(height: 16),
            Text(t('Перезапис з’явиться після візиту'),
                textAlign: TextAlign.center,
                style: AppTypography.title2(k.ink)),
            const SizedBox(height: 8),
            Text(
              t('Завершіть візит у картці запису — і застосунок сам запропонує, коли записати клієнта наступного разу.'),
              textAlign: TextAlign.center,
              style: AppTypography.body(k.ink2).copyWith(fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}

class _PaidCard extends StatelessWidget {
  const _PaidCard({required this.amount});
  final int amount;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x1A46D08A), Color(0xFF151519)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0x4046D08A)),
      ),
      padding: const EdgeInsets.all(18),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
                color: k.successTint, borderRadius: BorderRadius.circular(16)),
            child: Icon(Icons.check, color: k.success, size: 26),
          ),
          const SizedBox(height: 12),
          Text(t('Оплату отримано'),
              style: AppTypography.title3(k.ink).copyWith(fontSize: 17)),
          const SizedBox(height: 2),
          Text('+${Fmt.money(amount)}',
              style: AppTypography.tabular(AppTypography.title3(k.success))
                  .copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

class _RebookHero extends ConsumerWidget {
  const _RebookHero({required this.suggestion});
  final RebookSuggestion suggestion;

  Future<void> _book(BuildContext context, WidgetRef ref) async {
    final slot = suggestion.slot!;
    final a = suggestion.appointment;
    HapticFeedback.mediumImpact();
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(appointmentsRepositoryProvider);

    final next = Appointment(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      client: a.client,
      service: a.service,
      start: slot,
      status: AppointmentStatus.confirmed,
    );
    await repo.add(next);
    await scheduleAppointmentReminders(ref, next);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentCreated);

    navigator.pop();
    toast(
      tp('Записано на {date}',
          {'date': '${Fmt.dayMonth(slot)}, ${Fmt.time(slot)}'}),
      actionLabel: t('Повернути'),
      onAction: () => repo.delete(next.id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final s = suggestion;
    final a = s.appointment;
    final name = a.client.name.split(' ').first;

    final headline = s.cadenceDays == null
        ? tp('{name} — перший візит. Записати наперед?', {'name': name})
        : tp('{name} приходить раз на {n} {d}. Записати наперед?', {
            'name': name,
            'n': s.cadenceDays!,
            'd': tn(s.cadenceDays!, 'день', 'дні', 'днів'),
          });

    return ZHero(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabel('✦ ${t('Магічний перезапис')}', color: k.accent),
          const SizedBox(height: 8),
          Text(headline,
              style: AppTypography.title3(k.ink)
                  .copyWith(fontSize: 16, height: 1.35)),
          const SizedBox(height: 14),
          if (s.slot != null)
            Container(
              decoration: BoxDecoration(
                  color: k.surface2, borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 12),
              child: Row(
                children: [
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                        color: k.accentTint,
                        borderRadius: BorderRadius.circular(11)),
                    child:
                        Icon(Icons.calendar_today, size: 17, color: k.accent),
                  ),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                            '${Fmt.weekday(s.slot!)}, ${Fmt.dayMonth(s.slot!)}',
                            style: AppTypography.label(k.ink).copyWith(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        Text('${Fmt.time(s.slot!)} · ${t('вільно')}',
                            style: AppTypography.label(k.ink3)
                                .copyWith(fontSize: 11)),
                      ],
                    ),
                  ),
                  Text(Fmt.money(a.service.price),
                      style: AppTypography.tabular(AppTypography.label(k.ink))
                          .copyWith(fontSize: 13, fontWeight: FontWeight.w800)),
                ],
              ),
            )
          else
            Text(
              t('Найближчі два тижні вільних вікон немає — оберіть дату вручну.'),
              style: AppTypography.body(k.ink2).copyWith(fontSize: 13),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (s.slot != null) ...[
                Expanded(
                  child: ZButton(
                    label: tp(
                        'Записати на {date}', {'date': Fmt.dayMonth(s.slot!)}),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () => _book(context, ref),
                  ),
                ),
                const SizedBox(width: 9),
                ZButtonSecondary(
                  label: t('Інший'),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  onTap: () {
                    zTap();
                    showCreateAppointmentSheet(context, at: s.slot);
                  },
                ),
              ] else
                Expanded(
                  child: ZButton(
                    label: t('Обрати дату'),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    onTap: () {
                      zTap();
                      showCreateAppointmentSheet(context);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar();
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        GestureDetector(
          onTap: () => Navigator.of(context).maybePop(),
          child: Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
                color: k.surface2, borderRadius: BorderRadius.circular(12)),
            child: Icon(Icons.chevron_left, color: k.ink2),
          ),
        ),
      ]),
    );
  }
}
