import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../ui/z.dart';
import '../create/create_appointment_sheet.dart';

/// «Пора на повтор» — список клієнтів, у кого настав строк послуги.
///
/// Це найпростіша й найдорожча втрата в роботі майстра: людина не пішла до
/// іншого, вона просто забула. Строк бере не здогадка, а число, яке майстер
/// сам поставив послузі («корекція через 21 день»). Тих, хто вже записаний
/// наперед, у списку немає.
class RepeatDueScreen extends ConsumerWidget {
  const RepeatDueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final all = ref.watch(repeatDueProvider);
    final due = all.where((r) => r.isDue).toList();
    final soon = all.where((r) => !r.isDue).toList();
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
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
                children: [
                  reveal(Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: k.warningTint,
                            borderRadius: BorderRadius.circular(11)),
                        child: Icon(Icons.replay, size: 17, color: k.warning),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(t('Пора на повтор'),
                            style: AppTypography.title1(k.ink)),
                      ),
                    ],
                  )),
                  const SizedBox(height: 10),
                  reveal(Text(
                    all.isEmpty
                        ? t(
                            'Зараз кликати нікого — усі або щойно були, або вже записані.')
                        : tp('Строк настав у {n}. Ще {m} — на підході.',
                            {'n': due.length, 'm': soon.length}),
                    style: AppTypography.body(k.ink3).copyWith(fontSize: 13),
                  )),
                  const SizedBox(height: 16),
                  if (all.isEmpty)
                    reveal(const _Empty())
                  else ...[
                    if (due.isNotEmpty) ...[
                      reveal(ZLabel(t('Час настав'), color: k.warning)),
                      const SizedBox(height: 8),
                      for (final r in due)
                        reveal(Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DueRow(due: r),
                        )),
                      const SizedBox(height: 12),
                    ],
                    if (soon.isNotEmpty) ...[
                      reveal(ZLabel(t('Скоро'))),
                      const SizedBox(height: 8),
                      for (final r in soon)
                        reveal(Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _DueRow(due: r),
                        )),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Текст запрошення. Майстер бачить його до того, як натисне — нічого не
/// йде за спиною.
String repeatInvitation(RepeatDue r) => tp(
      '{name}, вітаю! Час оновити {service} — підібрати вам зручний день?',
      {
        'name': r.client.name.split(' ').first,
        'service': r.service.name.toLowerCase(),
      },
    );

/// Підпис під іменем: строк послуги і на скільки він минув.
String repeatFacts(RepeatDue r) {
  final every = tp('раз на {n} {d}', {
    'n': r.repeatAfterDays,
    'd': tn(r.repeatAfterDays, 'день', 'дні', 'днів'),
  });
  final when = r.isDue
      ? (r.overdueDays == 0
          ? t('строк сьогодні')
          : tp('прострочено {n} {d}', {
              'n': r.overdueDays,
              'd': tn(r.overdueDays, 'день', 'дні', 'днів'),
            }))
      : tp('через {n} {d}', {
          'n': -r.overdueDays,
          'd': tn(-r.overdueDays, 'день', 'дні', 'днів'),
        });
  return '$every · $when';
}

class _DueRow extends StatelessWidget {
  const _DueRow({required this.due});
  final RepeatDue due;

  Future<void> _write(BuildContext context) async {
    final toast = zToaster(context);
    final phone = due.client.phone.replaceAll(RegExp(r'[^0-9+]'), '');
    final uri = Uri(
      scheme: 'sms',
      path: phone,
      queryParameters: {'body': repeatInvitation(due)},
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok) toast(t('Не вдалося відкрити повідомлення'));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final r = due;
    return Semantics(
      label: '${r.client.name}, ${r.service.name}, ${repeatFacts(r)}',
      child: ZCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ZAvatar(initials: r.client.initials, size: 40),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(r.client.name,
                      style:
                          AppTypography.title3(k.ink).copyWith(fontSize: 14.5)),
                  const SizedBox(height: 1),
                  Text('${r.service.name} · ${repeatFacts(r)}',
                      maxLines: 2,
                      style: AppTypography.label(r.isDue ? k.warning : k.ink3)
                          .copyWith(fontSize: 11.5, height: 1.35)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Semantics(
              button: true,
              label: t('Написати клієнту'),
              child: GestureDetector(
                onTap: () {
                  zTap();
                  _write(context);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: k.accentTint,
                      borderRadius: BorderRadius.circular(12)),
                  child: Icon(Icons.send_outlined, size: 17, color: k.accent),
                ),
              ),
            ),
            const SizedBox(width: 7),
            Semantics(
              button: true,
              label: t('Записати'),
              child: GestureDetector(
                // Клієнт уже погодився усно — записуємо одразу.
                onTap: () {
                  zTap();
                  showCreateAppointmentSheet(context);
                },
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                      color: k.surface2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: k.line)),
                  child: Icon(Icons.event_available_outlined,
                      size: 17, color: k.ink2),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Порожній список — це нормальний стан, а не помилка.
class _Empty extends StatelessWidget {
  const _Empty();

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(t('Список порожній'),
              style: AppTypography.title3(k.ink).copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            t('Він наповнюється сам: поставте послузі строк повтору — і застосунок нагадає, коли клієнта пора кликати.'),
            style:
                AppTypography.body(k.ink2).copyWith(fontSize: 13, height: 1.5),
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        Semantics(
          button: true,
          label: t('Назад'),
          child: const ZBackButton(),
        ),
      ]),
    );
  }
}
