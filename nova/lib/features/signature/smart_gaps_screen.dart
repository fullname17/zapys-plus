import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../ui/format.dart';
import '../../ui/z.dart';
import '../create/create_appointment_sheet.dart';

/// Фішка «Розумні вікна»: застосунок сам ранжує, кого запросити у вільний час,
/// і готує текст повідомлення.
///
/// Раніше екран показував вигадану клієнтку з «92% прийде». Тепер це реальні
/// вікна дня, реальні клієнти з бази, а замість вигаданого відсотка — факти:
/// як часто людина ходить і скільки не була.
class SmartGapsScreen extends ConsumerWidget {
  const SmartGapsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final windows = ref.watch(dashboardProvider).freeWindows;
    final pairs = ref.watch(smartGapsProvider);
    var idx = 0;
    Widget reveal(Widget c) => StaggerReveal(index: idx++, child: c);

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
                            color: k.accentTint,
                            borderRadius: BorderRadius.circular(11)),
                        child:
                            Icon(Icons.auto_awesome, size: 17, color: k.accent),
                      ),
                      const SizedBox(width: 10),
                      Text(t('Розумні вікна'),
                          style: AppTypography.title1(k.ink)),
                    ],
                  )),
                  const SizedBox(height: 10),
                  reveal(Text(
                    windows.isEmpty
                        ? t('Сьогодні вільних вікон немає — день щільний.')
                        : pairs.isEmpty
                            ? tp(
                                'Сьогодні вільних вікон: {n}. Кликати поки нікого — усі ходять за своїм ритмом.',
                                {
                                    'n': windows.length
                                  })
                            : tp(
                                'Сьогодні вільних вікон: {n}. Ось кого варто запросити.',
                                {'n': windows.length}),
                    style: AppTypography.body(k.ink3).copyWith(fontSize: 13),
                  )),
                  const SizedBox(height: 16),
                  if (pairs.isNotEmpty) ...[
                    reveal(
                        _CandidateHero(at: pairs.first.$1, c: pairs.first.$2)),
                    if (pairs.length > 1) ...[
                      const SizedBox(height: 16),
                      reveal(ZLabel(t('Ще кандидати'))),
                      const SizedBox(height: 8),
                      for (final p in pairs.skip(1))
                        reveal(Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _CandidateRow(at: p.$1, c: p.$2),
                        )),
                    ],
                  ] else if (windows.isNotEmpty)
                    reveal(_EmptyCandidates(at: windows.first)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Текст запрошення. Готовий до відправки, але майстер бачить його до того, як
/// натисне — нічого не йде за спиною.
String invitationText(DateTime at, GapCandidate c) => tp(
      '{name}, вітаю! Є віконце сьогодні о {time} на {service}. Записати?',
      {
        'name': c.client.name.split(' ').first,
        'time': Fmt.time(at),
        'service': c.service.name.toLowerCase(),
      },
    );

/// Підпис під іменем: як часто ходить і скільки не була. Факти замість
/// вигаданої ймовірності.
String candidateFacts(GapCandidate c) {
  final rhythm = c.cadenceDays == null
      ? null
      // «раз на 21 день» / «раз на 30 днів» — правильно за будь-якого числа,
      // на відміну від «кожні 21 день». Стать клієнта нам невідома, тож
      // формулювання нейтральні: «без візиту», а не «не була».
      : tp('раз на {n} {d}', {
          'n': c.cadenceDays!,
          'd': tn(c.cadenceDays!, 'день', 'дні', 'днів'),
        });
  final away = tp('без візиту {n} {d}', {
    'n': c.daysSince,
    'd': tn(c.daysSince, 'день', 'дні', 'днів'),
  });
  return rhythm == null ? away : '$rhythm · $away';
}

/// Відкрити SMS із готовим текстом. Месенджерів у застосунку ще немає, а SMS
/// є в кожному телефоні — тож поки так.
Future<void> sendInvitation(
    BuildContext context, DateTime at, GapCandidate c) async {
  final toast = zToaster(context);
  final phone = c.client.phone.replaceAll(RegExp(r'[^0-9+]'), '');
  final uri = Uri(
    scheme: 'sms',
    path: phone,
    queryParameters: {'body': invitationText(at, c)},
  );
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok) toast(t('Не вдалося відкрити повідомлення'));
}

class _CandidateHero extends StatelessWidget {
  const _CandidateHero({required this.at, required this.c});
  final DateTime at;
  final GapCandidate c;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZHero(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ZLabel(
              '${t('Вікно')} · ${Fmt.range(at, at.add(Duration(minutes: c.service.durationMinutes)))}',
              color: k.accent),
          const SizedBox(height: 12),
          Row(
            children: [
              ZAvatar(initials: c.client.initials, size: 44),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.client.name,
                        style: AppTypography.title3(k.ink).copyWith(
                            fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(candidateFacts(c),
                        style:
                            AppTypography.label(k.ink2).copyWith(fontSize: 12)),
                  ],
                ),
              ),
              Text(Fmt.money(c.service.price),
                  style: AppTypography.tabular(AppTypography.title3(k.ink))
                      .copyWith(fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 14),
          ZGlass(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
            child: Text(
              '«${invitationText(at, c)}»',
              style: AppTypography.body(k.ink2)
                  .copyWith(fontSize: 12.5, height: 1.45),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ZButton(
                  label: t('Надіслати'),
                  icon: Icons.send_outlined,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  onTap: () => sendInvitation(context, at, c),
                ),
              ),
              const SizedBox(width: 9),
              GestureDetector(
                // Клієнт уже погодився усно — записуємо одразу, без листування.
                onTap: () {
                  zTap();
                  showCreateAppointmentSheet(context, at: at);
                },
                child: Container(
                  width: 50,
                  height: 46,
                  decoration: FX.buttonSecondary(k),
                  child: Icon(Icons.event_available_outlined,
                      size: 18, color: k.ink2),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CandidateRow extends StatelessWidget {
  const _CandidateRow({required this.at, required this.c});
  final DateTime at;
  final GapCandidate c;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          ZAvatar(initials: c.client.initials, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(c.client.name,
                    style: AppTypography.title3(k.ink).copyWith(fontSize: 14)),
                Text('${Fmt.time(at)} · ${candidateFacts(c)}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.label(k.ink3).copyWith(fontSize: 12)),
              ],
            ),
          ),
          GestureDetector(
            onTap: () {
              zTap();
              sendInvitation(context, at, c);
            },
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                  color: k.accentTint, borderRadius: BorderRadius.circular(12)),
              child: Icon(Icons.send_outlined, size: 17, color: k.accent),
            ),
          ),
        ],
      ),
    );
  }
}

/// Вікна є, а кликати нема кого — теж нормальний стан дня.
class _EmptyCandidates extends StatelessWidget {
  const _EmptyCandidates({required this.at});
  final DateTime at;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tp('Вікно о {time} вільне', {'time': Fmt.time(at)}),
              style: AppTypography.title3(k.ink).copyWith(fontSize: 15)),
          const SizedBox(height: 6),
          Text(
            t('Можна поділитися посиланням на онлайн-запис або додати клієнта вручну.'),
            style: AppTypography.body(k.ink2).copyWith(fontSize: 13),
          ),
          const SizedBox(height: 14),
          ZButton(
            label: t('Новий запис'),
            icon: Icons.add,
            onTap: () => showCreateAppointmentSheet(context, at: at),
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
    return const Padding(
      padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
      child: Row(children: [
        ZBackButton(),
      ]),
    );
  }
}
