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
import '../calendar/calendar_screen.dart' show apptColor;
import 'appointment_reminders.dart';
import 'schedule_picker.dart';

/// Новий запис — v3 bottom sheet: клієнт → послуга → день і час → «Записати».
/// Створює реальний запис (Drift) на обраний час і планує нагадування.
Future<void> showCreateAppointmentSheet(BuildContext context, {DateTime? at}) =>
    showKavioSheet<void>(context, builder: (_) => _CreateSheet(at: at));

class _CreateSheet extends ConsumerStatefulWidget {
  const _CreateSheet({this.at});

  /// Час, з якого відкрили лист (тап по вільному вікну) — день підставляється
  /// одразу, щоб не шукати його в смузі вручну.
  final DateTime? at;

  @override
  ConsumerState<_CreateSheet> createState() => _CreateSheetState();
}

class _CreateSheetState extends ConsumerState<_CreateSheet> {
  Client? _client;
  Service? _service;
  late DateTime _day;
  DateTime? _slot;

  @override
  void initState() {
    super.initState();
    final at = widget.at ?? DateTime.now();
    _day = DateTime(at.year, at.month, at.day);
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(clientsProvider).value ?? const <Client>[];
    final services = ref.watch(servicesProvider).value ?? const <Service>[];
    final ready = _client != null && _service != null && _slot != null;

    return KavioSheet(
      title: t('Новий запис'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabel(t('Клієнт')),
          const SizedBox(height: 8),
          ClientPicker(
            clients: clients,
            selected: _client,
            onChanged: (c) => setState(() => _client = c),
            limit: 8,
          ),
          const SizedBox(height: 18),
          ZLabel(t('Послуга')),
          const SizedBox(height: 8),
          ServicePicker(
            services: services,
            selected: _service,
            onChanged: (s) => setState(() {
              _service = s;
              _slot = null;
            }),
          ),
          const SizedBox(height: 18),
          ZLabel(t('Коли')),
          const SizedBox(height: 8),
          ScheduleDayStrip(
            day: _day,
            onChanged: (d) => setState(() {
              _day = d;
              _slot = null;
            }),
          ),
          if (_service != null) ...[
            const SizedBox(height: 10),
            ScheduleSlots(
              day: _day,
              durationMinutes: _service!.durationMinutes,
              selected: _slot,
              onChanged: (s) => setState(() => _slot = s),
            ),
          ],
          const SizedBox(height: 20),
          ZButton(
            label: ready
                ? tp('Записати на {time}', {'time': Fmt.time(_slot!)})
                : t('Оберіть клієнта, послугу і час'),
            onTap: ready ? () => _create(context) : null,
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context) async {
    HapticFeedback.mediumImpact();
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final appt = Appointment(
      id: 'a${DateTime.now().microsecondsSinceEpoch}',
      client: _client!,
      service: _service!,
      start: _slot!,
      status: AppointmentStatus.confirmed,
    );
    await ref.read(appointmentsRepositoryProvider).add(appt);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.appointmentCreated);
    await scheduleAppointmentReminders(ref, appt);
    navigator.pop();
    toast(tp('Записано {name} · {time}',
        {'name': _client!.name, 'time': Fmt.time(_slot!)}));
  }
}

/// Вибір клієнта чипами. Спільний для «Новий запис» і «Редагувати запис».
/// При відкритті сам підкручується до вже обраного клієнта — інакше в
/// редагуванні поточний клієнт лишався б за краєм екрана.
class ClientPicker extends StatefulWidget {
  const ClientPicker({
    super.key,
    required this.clients,
    required this.selected,
    required this.onChanged,
    this.limit,
  });
  final List<Client> clients;
  final Client? selected;
  final ValueChanged<Client> onChanged;
  final int? limit;

  @override
  State<ClientPicker> createState() => _ClientPickerState();
}

class _ClientPickerState extends State<ClientPicker> {
  final GlobalKey _selectedKey = GlobalKey();
  bool _revealed = false;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final items = widget.limit == null
        ? widget.clients
        : widget.clients.take(widget.limit!).toList(growable: false);

    if (!_revealed && widget.selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final ctx = _selectedKey.currentContext;
        if (!mounted || ctx == null) return;
        _revealed = true;
        Scrollable.ensureVisible(ctx,
            alignment: 0.15,
            duration: const Duration(milliseconds: 420),
            curve: Motion.enter);
      });
    }

    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final c = items[i];
          final on = widget.selected?.id == c.id;
          return ZChip(
            key: on ? _selectedKey : null,
            selected: on,
            onTap: () => widget.onChanged(c),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // На градієнті звичайний аватар зливається — світлішаємо.
                ZAvatar(
                  initials: c.initials,
                  size: 24,
                  color: on ? Colors.white : null,
                  bg: on ? const Color(0x38FFFFFF) : null,
                ),
                const SizedBox(width: 7),
                Text(c.name.split(' ').first,
                    style: AppTypography.label(on ? Colors.white : k.ink)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// Вибір послуги чипами з кольоровою міткою категорії. Спільний для
/// «Новий запис» і «Редагувати запис».
class ServicePicker extends StatelessWidget {
  const ServicePicker({
    super.key,
    required this.services,
    required this.selected,
    required this.onChanged,
  });
  final List<Service> services;
  final Service? selected;
  final ValueChanged<Service> onChanged;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final s in services)
          ZChip(
            selected: selected?.id == s.id,
            onTap: () => onChanged(s),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                        // На градієнті кольорова мітка тоне — робимо її білою.
                        color: selected?.id == s.id
                            ? Colors.white
                            : apptColor(s.id, category: s.category),
                        borderRadius: BorderRadius.circular(3))),
                const SizedBox(width: 7),
                Text('${s.name} · ${Fmt.money(s.price)}',
                    style: AppTypography.label(
                            selected?.id == s.id ? Colors.white : k.ink)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
      ],
    );
  }
}
