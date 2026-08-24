import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/routes.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/analytics/analytics_events.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/status_pill.dart';
import '../../ui/z.dart';
import '../create/appointment_reminders.dart';
import 'calendar_screen.dart' show apptColor;
import 'edit_appointment_sheet.dart';

/// Картка запису v3 — усе про візит і всі дії над ним в одному листі.
///
/// Головна дія залежить від стану (підтвердити → завершити → записати ще раз),
/// далі рівний ряд дій «Перенести / Редагувати / Скасувати», а незворотне
/// «Видалити» лишається внизу окремо. Скасування й видалення показують
/// «Повернути» — жоден дотик не є фатальним.
Future<void> showAppointmentSheet(BuildContext context, Appointment a) =>
    showKavioSheet<void>(context,
        builder: (_) => _AppointmentSheet(appointment: a));

class _AppointmentSheet extends ConsumerWidget {
  const _AppointmentSheet({required this.appointment});

  final Appointment appointment;

  // ── Дії ───────────────────────────────────────────────────────────────

  Future<void> _setStatus(
      WidgetRef ref, BuildContext context, AppointmentStatus s) async {
    final navigator = Navigator.of(context);
    await ref
        .read(appointmentsRepositoryProvider)
        .updateStatus(appointment.id, s);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentStatusChanged(s.name));
    navigator.pop();
  }

  /// Завершення візиту → «Магічний перезапис» (фішка на касі).
  Future<void> _complete(WidgetRef ref, BuildContext context) async {
    final navigator = Navigator.of(context);
    final router = GoRouter.of(context);
    await ref
        .read(appointmentsRepositoryProvider)
        .updateStatus(appointment.id, AppointmentStatus.completed);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentStatusChanged('completed'));
    navigator.pop();
    router.push(Routes.rebook);
  }

  /// Скасування — м'яке: запис лишається в історії, але звільняє вікно.
  /// Нагадування знімаються, статус можна повернути одним дотиком.
  Future<void> _cancel(WidgetRef ref, BuildContext context) async {
    HapticFeedback.mediumImpact();
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final was = appointment.status;
    final repo = ref.read(appointmentsRepositoryProvider);

    await repo.updateStatus(appointment.id, AppointmentStatus.cancelled);
    await cancelAppointmentReminders(ref, appointment);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentCancelled);
    navigator.pop();

    toast(
      tp('Запис скасовано · {name}', {'name': appointment.client.name}),
      actionLabel: t('Повернути'),
      onAction: () async {
        await repo.updateStatus(appointment.id, was);
        await scheduleAppointmentReminders(ref, appointment);
      },
    );
  }

  /// Повернення скасованого запису на те саме місце.
  Future<void> _restore(WidgetRef ref, BuildContext context) async {
    final navigator = Navigator.of(context);
    await ref
        .read(appointmentsRepositoryProvider)
        .updateStatus(appointment.id, AppointmentStatus.confirmed);
    await scheduleAppointmentReminders(ref, appointment);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentRestored);
    navigator.pop();
  }

  /// Видалення — назавжди. Тому в тості лишається «Повернути»: об'єкт запису
  /// у нас на руках, тож відновлення — це просто вставка того самого id.
  Future<void> _delete(WidgetRef ref, BuildContext context) async {
    HapticFeedback.mediumImpact();
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(appointmentsRepositoryProvider);

    await repo.delete(appointment.id);
    await cancelAppointmentReminders(ref, appointment);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentDeleted);
    navigator.pop();

    toast(
      t('Запис видалено'),
      actionLabel: t('Повернути'),
      onAction: () async {
        await repo.add(appointment);
        await scheduleAppointmentReminders(ref, appointment);
      },
    );
  }

  // ── Вигляд ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final a = appointment;
    final c = apptColor(a.service.id);
    final cancelled = a.status == AppointmentStatus.cancelled;
    final done = a.status == AppointmentStatus.completed;
    final meta = [
      if (a.staff != null) a.staff!.name,
      if (a.resource != null) a.resource!.name,
    ].join(' · ');

    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return KavioSheet(
      title: t('Деталі запису'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Герой: хто, що, коли — і одразу перехід у картку клієнта.
          reveal(GestureDetector(
            onTap: () {
              zTap();
              Navigator.of(context).pop();
              context.push(Routes.clientDetailPath(a.client.id));
            },
            child: ZHero(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  ZAvatar(
                      initials: a.client.initials,
                      size: 46,
                      color: c,
                      bg: c.withValues(alpha: 0.18)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(a.client.name,
                            style: AppTypography.title2(k.ink)
                                .copyWith(fontSize: 18)),
                        const SizedBox(height: 3),
                        Text(
                          '${a.service.name} · ${Fmt.duration(a.service.durationMinutes)}',
                          style: AppTypography.label(k.ink2)
                              .copyWith(fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, size: 18, color: k.ink3),
                ],
              ),
            ),
          )),
          const SizedBox(height: 12),

          // Час · сума · статус.
          reveal(ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Icon(Icons.schedule, size: 16, color: k.ink3),
                const SizedBox(width: 8),
                Text(
                  Fmt.range(a.start, a.end),
                  style: AppTypography.tabular(AppTypography.title3(k.ink))
                      .copyWith(
                          fontSize: 14,
                          decoration:
                              cancelled ? TextDecoration.lineThrough : null),
                ),
                const SizedBox(width: 10),
                Text(Fmt.money(a.service.price),
                    style: AppTypography.tabular(AppTypography.label(k.ink2))
                        .copyWith(fontSize: 13)),
                const Spacer(),
                StatusPill(a.status),
              ],
            ),
          )),
          if (meta.isNotEmpty) ...[
            const SizedBox(height: 8),
            reveal(Padding(
              padding: const EdgeInsets.only(left: 4),
              child: Text(meta,
                  style: AppTypography.label(k.ink3).copyWith(fontSize: 12)),
            )),
          ],
          const SizedBox(height: 16),

          // Головна дія — залежить від того, де запис у своєму житті.
          reveal(
              _primaryAction(context, ref, cancelled: cancelled, done: done)),
          const SizedBox(height: 10),

          // Рівний ряд щоденних дій.
          reveal(Row(
            children: [
              Expanded(
                child: ZActionTile(
                  icon: Icons.swap_horiz,
                  label: t('Перенести'),
                  // Візит, який уже відбувся або скасований, переносити нікуди:
                  // для нового візиту є «Записати ще раз».
                  onTap: cancelled || done
                      ? null
                      : () {
                          Navigator.of(context).pop();
                          showMoveAppointmentSheet(context, a);
                        },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ZActionTile(
                  icon: Icons.tune,
                  label: t('Редагувати'),
                  onTap: () {
                    Navigator.of(context).pop();
                    showEditAppointmentSheet(context, a);
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ZActionTile(
                  icon: cancelled ? Icons.undo : Icons.event_busy,
                  label: cancelled ? t('Відновити') : t('Скасувати'),
                  tone: cancelled ? k.success : k.danger,
                  onTap: () => cancelled
                      ? _restore(ref, context)
                      : _cancel(ref, context),
                ),
              ),
            ],
          )),
          const SizedBox(height: 14),

          // Рідкісні дії — тихим рядком, щоб не конкурували з головними.
          reveal(Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!done && !cancelled) ...[
                _QuietAction(
                  label: t('Не прийшов'),
                  color: k.warning,
                  onTap: () =>
                      _setStatus(ref, context, AppointmentStatus.noShow),
                ),
                Text('·',
                    style: AppTypography.label(k.ink3).copyWith(fontSize: 13)),
              ],
              _QuietAction(
                label: t('Видалити'),
                color: k.danger,
                onTap: () => _delete(ref, context),
              ),
            ],
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _primaryAction(BuildContext context, WidgetRef ref,
      {required bool cancelled, required bool done}) {
    if (cancelled) {
      return ZButton(
        label: t('Відновити запис'),
        icon: Icons.undo,
        onTap: () => _restore(ref, context),
      );
    }
    if (done) {
      return ZButton(
        label: t('Записати ще раз'),
        icon: Icons.auto_awesome,
        onTap: () {
          Navigator.of(context).pop();
          GoRouter.of(context).push(Routes.rebook);
        },
      );
    }
    if (appointment.status == AppointmentStatus.confirmed ||
        appointment.status == AppointmentStatus.inProgress) {
      return ZButton(
        label: t('Завершити візит'),
        icon: Icons.check_circle_outline,
        onTap: () => _complete(ref, context),
      );
    }
    return ZButton(
      label: t('Підтвердити запис'),
      icon: Icons.check,
      onTap: () => _setStatus(ref, context, AppointmentStatus.confirmed),
    );
  }
}

/// Текстова дія без ваги кнопки — для рідкісних і незворотних кроків.
class _QuietAction extends StatelessWidget {
  const _QuietAction(
      {required this.label, required this.color, required this.onTap});
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: () {
        zTap();
        onTap();
      },
      style: TextButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label,
          style: AppTypography.label(color)
              .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
    );
  }
}
