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
import '../../ui/kavio_sheet.dart';
import '../../ui/z.dart';
import '../create/appointment_reminders.dart';
import '../create/create_appointment_sheet.dart'
    show ClientPicker, ServicePicker;
import '../create/schedule_picker.dart';

/// Перенесення запису: змінюється лише час. Той самий вибір дня й слотів, що
/// і в «Новий запис», але власне вікно запису не рахується зайнятим — інакше
/// запис конфліктував би сам із собою.
Future<void> showMoveAppointmentSheet(BuildContext context, Appointment a) =>
    showKavioSheet<void>(context,
        builder: (_) => _EditSheet(appointment: a, timeOnly: true));

/// Редагування запису: клієнт, послуга і час. Id незмінний — історія клієнта
/// та нагадування лишаються прив'язаними до того самого візиту.
Future<void> showEditAppointmentSheet(BuildContext context, Appointment a) =>
    showKavioSheet<void>(context,
        builder: (_) => _EditSheet(appointment: a, timeOnly: false));

class _EditSheet extends ConsumerStatefulWidget {
  const _EditSheet({required this.appointment, required this.timeOnly});
  final Appointment appointment;
  final bool timeOnly;

  @override
  ConsumerState<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends ConsumerState<_EditSheet> {
  late Client _client;
  late Service _service;
  late DateTime _day;
  DateTime? _slot;

  Appointment get _a => widget.appointment;

  @override
  void initState() {
    super.initState();
    _client = _a.client;
    _service = _a.service;
    _day = DateTime(_a.start.year, _a.start.month, _a.start.day);
  }

  /// Чи є що зберігати. Для перенесення — лише новий час; для редагування —
  /// ще й клієнт із послугою.
  bool get _changed {
    if (widget.timeOnly) return _slot != null && _slot != _a.start;
    return (_slot != null && _slot != _a.start) ||
        _client.id != _a.client.id ||
        _service.id != _a.service.id;
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final services = ref.watch(servicesProvider).value ?? const <Service>[];
    final target = _slot ?? _a.start;

    return KavioSheet(
      title: widget.timeOnly ? t('Перенести запис') : t('Редагувати запис'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Що було — щоб зміна читалася як зміна, а не як новий запис.
          ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            child: Row(
              children: [
                ZAvatar(initials: _a.client.initials, size: 30),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(_a.client.name,
                      style:
                          AppTypography.title3(k.ink).copyWith(fontSize: 14)),
                ),
                Text(
                  tp('Було: {time}', {
                    'time': '${Fmt.dayMonth(_a.start)}, ${Fmt.time(_a.start)}'
                  }),
                  style: AppTypography.tabular(AppTypography.label(k.ink3))
                      .copyWith(fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          if (!widget.timeOnly) ...[
            ZLabel(t('Клієнт')),
            const SizedBox(height: 8),
            ClientPicker(
              clients: clients,
              selected: _client,
              onChanged: (c) => setState(() => _client = c),
            ),
            const SizedBox(height: 18),
            ZLabel(t('Послуга')),
            const SizedBox(height: 8),
            ServicePicker(
              services: services,
              selected: _service,
              onChanged: (s) => setState(() {
                _service = s;
                // Інша тривалість — старий слот міг перестати вміщатися.
                _slot = null;
              }),
            ),
            const SizedBox(height: 18),
          ],

          ZLabel(widget.timeOnly ? t('Новий час') : t('Коли')),
          const SizedBox(height: 8),
          ScheduleDayStrip(
            day: _day,
            onChanged: (d) => setState(() {
              _day = d;
              _slot = null;
            }),
          ),
          const SizedBox(height: 10),
          ScheduleSlots(
            day: _day,
            durationMinutes: _service.durationMinutes,
            selected: _slot,
            onChanged: (s) => setState(() => _slot = s),
            ignoreId: _a.id,
          ),
          const SizedBox(height: 20),

          ZButton(
            label: widget.timeOnly
                ? (_changed
                    ? tp('Перенести на {time}', {'time': Fmt.time(target)})
                    : t('Оберіть новий час'))
                : t('Зберегти зміни'),
            icon: widget.timeOnly ? Icons.swap_horiz : Icons.check,
            onTap: _changed ? () => _save(context) : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _save(BuildContext context) async {
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(appointmentsRepositoryProvider);
    final start = _slot ?? _a.start;

    // Остання перевірка перед записом: поки лист був відкритий, вікно могло
    // зайняти онлайн-бронювання.
    final dayStart = DateTime(start.year, start.month, start.day);
    final dayAppts = await repo
        .watchRange(dayStart, dayStart.add(const Duration(days: 1)))
        .first;
    final free = slotIsFree(
      dayAppointments: dayAppts,
      start: start,
      durationMinutes: _service.durationMinutes,
      ignoreId: _a.id,
    );
    if (!free) {
      HapticFeedback.heavyImpact();
      toast(t('Цей час уже зайнятий'));
      setState(() => _slot = null);
      return;
    }

    HapticFeedback.mediumImpact();
    final was = _a;
    final updated = _a.copyWith(
      client: _client,
      service: _service,
      start: start,
      // Перенесений запис знову чекає підтвердження від клієнта.
      status: start == _a.start
          ? _a.status
          : (_a.status == AppointmentStatus.completed
              ? _a.status
              : AppointmentStatus.pending),
    );

    await repo.update(updated);
    await cancelAppointmentReminders(ref, was);
    await scheduleAppointmentReminders(ref, updated);
    await ref.read(analyticsServiceProvider).track(widget.timeOnly
        ? AnalyticsEvent.appointmentMoved
        : AnalyticsEvent.appointmentEdited);
    navigator.pop();

    toast(
      widget.timeOnly
          ? tp('Запис перенесено на {time}',
              {'time': '${Fmt.dayMonth(start)}, ${Fmt.time(start)}'})
          : t('Зміни збережено'),
      actionLabel: t('Повернути'),
      onAction: () async {
        await repo.update(was);
        await cancelAppointmentReminders(ref, updated);
        await scheduleAppointmentReminders(ref, was);
      },
    );
  }
}
