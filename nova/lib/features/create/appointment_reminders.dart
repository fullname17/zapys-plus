import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/notifications/notification_scheduler.dart';
import '../../core/services/remote_config/remote_config_service.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';

/// Нагадування про візит. Винесено окремо, бо потрібні трьом сценаріям:
/// створення, перенесення й редагування — після зміни часу старі нагадування
/// вже неправильні, тож їх завжди переплановують разом із записом.
Future<void> scheduleAppointmentReminders(WidgetRef ref, Appointment a) async {
  if (!ref.read(featureFlagProvider(FeatureFlag.push))) return;
  final scheduler = ref.read(notificationSchedulerProvider);
  final now = DateTime.now();
  for (final off in ReminderPolicy.offsets) {
    final at = a.start.subtract(off);
    if (at.isAfter(now)) {
      await scheduler.schedule(ScheduledReminder(
        id: ReminderPolicy.reminderId(a.id, off),
        at: at,
        title: t('Нагадування про візит'),
        body:
            '${a.client.name} · ${a.service.name} ${t('о')} ${Fmt.time(a.start)}',
      ));
    }
  }
}

/// Знімає нагадування запису — при скасуванні або перед переплануванням.
Future<void> cancelAppointmentReminders(WidgetRef ref, Appointment a) async {
  if (!ref.read(featureFlagProvider(FeatureFlag.push))) return;
  await ref.read(notificationSchedulerProvider).cancelForAppointment(a.id);
}
