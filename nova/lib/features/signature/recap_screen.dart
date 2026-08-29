import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import 'package:flutter/services.dart';

import '../../ui/format.dart';
import '../../ui/z.dart';

/// Текст підсумку для буфера обміну — коротко й по-людськи.
String _summaryText(RecapData d) {
  final parts = <String>[
    '${t('Зароблено сьогодні')}: ${Fmt.money(d.revenue)}',
    '${d.visits} ${tn(d.visits, 'клієнт', 'клієнти', 'клієнтів')}',
    if (d.newClients > 0) '${d.newClients} ${t('уперше')}',
    '${t('у кріслі')}: ${Fmt.hours(d.busyMinutes)}',
    if (d.tomorrowCount > 0)
      '${t('Завтра')}: ${d.tomorrowCount} ${tn(d.tomorrowCount, 'запис', 'записи', 'записів')}',
  ];
  return parts.join('\n');
}

/// Фішка «Підсумок дня»: щовечірній момент гордості — скільки зароблено,
/// клієнтів, оцінка, і що на завтра. Live-дані сьогодні + шаринг.
class RecapScreen extends ConsumerWidget {
  const RecapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final d = ref.watch(recapProvider);
    var i = 0;
    Widget reveal(Widget c) => StaggerReveal(index: i++, child: c);

    return Scaffold(
      backgroundColor: k.canvas,
      body: Stack(
        children: [
          const Positioned(
            top: -40,
            left: 0,
            right: 0,
            child: Center(child: GlowOrb(size: 320)),
          ),
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(12, 8, 12, 4),
                  child: Row(children: [
                    ZBackButton(),
                  ]),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                    children: [
                      reveal(Column(
                        children: [
                          const Text('🌙', style: TextStyle(fontSize: 34)),
                          const SizedBox(height: 8),
                          Text(t('Гарний день, Софіє!'),
                              style: AppTypography.title1(k.ink)),
                          const SizedBox(height: 6),
                          Text(t('Ось як він пройшов'),
                              style: AppTypography.label(k.ink2)
                                  .copyWith(fontSize: 13)),
                        ],
                      )),
                      const SizedBox(height: 16),
                      reveal(ZHero(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          children: [
                            ZLabel(t('Зароблено сьогодні'), color: k.ink2),
                            const SizedBox(height: 2),
                            Text(Fmt.money(d.revenue),
                                style: AppTypography.tabular(
                                        AppTypography.display(k.ink))
                                    .copyWith(fontSize: 40)),
                            const SizedBox(height: 8),
                            if (d.deltaPercent != null)
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  ZPill(
                                      '${d.deltaPercent! >= 0 ? '▲' : '▼'} ${d.deltaPercent!.abs()}%',
                                      color: d.deltaPercent! >= 0
                                          ? k.success
                                          : k.danger,
                                      bg: d.deltaPercent! >= 0
                                          ? k.successTint
                                          : k.dangerTint),
                                  const SizedBox(width: 8),
                                  Text(t('проти минулого робочого дня'),
                                      style: AppTypography.label(k.ink3)
                                          .copyWith(fontSize: 12)),
                                ],
                              ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 12),
                      reveal(Row(
                        children: [
                          _tile(k, '${d.visits}', t('клієнтів')),
                          const SizedBox(width: 10),
                          _tile(k, '${d.newClients}', t('уперше')),
                          const SizedBox(width: 10),
                          _tile(k, Fmt.hours(d.busyMinutes), t('у кріслі')),
                        ],
                      )),
                      const SizedBox(height: 12),
                      reveal(ZCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 15, vertical: 14),
                        child: Row(
                          children: [
                            const Text('☀️', style: TextStyle(fontSize: 20)),
                            const SizedBox(width: 11),
                            Expanded(
                              child: Text.rich(TextSpan(
                                style: AppTypography.body(k.ink)
                                    .copyWith(fontSize: 13, height: 1.4),
                                children: [
                                  TextSpan(
                                      text: '${t('Завтра')}: ',
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w800)),
                                  TextSpan(
                                      text: d.tomorrowCount == 0
                                          ? t('записів немає — можна видихнути.')
                                          : '${d.tomorrowCount} ${tn(d.tomorrowCount, 'запис', 'записи', 'записів')}, '),
                                  if (d.tomorrowFirst != null)
                                    TextSpan(
                                        text: tp('перший о {time}.', {
                                          'time': Fmt.time(d.tomorrowFirst!)
                                        }),
                                        style: TextStyle(color: k.accent)),
                                ],
                              )),
                            ),
                          ],
                        ),
                      )),
                      const SizedBox(height: 18),
                      reveal(Builder(builder: (context) {
                        return ZButtonSecondary(
                          label: t('Поділитися підсумком'),
                          expand: true,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          // Системного «поділитися» ще немає, тож кладемо текст
                          // у буфер — його можна вставити куди завгодно.
                          onTap: () {
                            zTap();
                            Clipboard.setData(
                                ClipboardData(text: _summaryText(d)));
                            zToaster(context)(t('Підсумок скопійовано'));
                          },
                        );
                      })),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(KavioColors k, String v, String l) => Expanded(
        child: ZCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            children: [
              // «3 год 30 хв» довше за «7» — стискаємо, щоб плитки лишалися
              // однаковими, а не роз'їжджалися по висоті.
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(v,
                    maxLines: 1,
                    softWrap: false,
                    style: AppTypography.tabular(AppTypography.title1(k.ink))
                        .copyWith(fontSize: 24)),
              ),
              const SizedBox(height: 2),
              Text(l,
                  style: AppTypography.label(k.ink3).copyWith(fontSize: 11)),
            ],
          ),
        ),
      );
}
