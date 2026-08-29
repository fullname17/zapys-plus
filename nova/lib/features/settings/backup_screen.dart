import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/backup/save_file.dart';
import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../ui/z.dart';

/// Резервна копія бази.
///
/// Уся робота майстра — клієнти, історія візитів, ціни — лежить тільки на
/// цьому пристрої. Загубився телефон, перевстановили застосунок, почистили
/// дані браузера — і з ними зникло все. Хмарної синхронізації ще немає, тож
/// поки що страховка одна: забрати копію файлом і покласти її туди, де вона
/// переживе телефон.
class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});

  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  bool _busy = false;

  String _fileName() {
    final now = DateTime.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'zapys-${now.year}-${two(now.month)}-${two(now.day)}.json';
  }

  Future<String> _json() async {
    final data = await ref.read(backupRepositoryProvider).exportAll();
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final toast = zToaster(context);
    try {
      HapticFeedback.mediumImpact();
      final where = await saveBackupFile(_fileName(), await _json());
      toast(kIsWeb
          ? tp('Файл {name} завантажено', {'name': where})
          : tp('Збережено: {path}', {'path': where}));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _copy() async {
    if (_busy) return;
    setState(() => _busy = true);
    final toast = zToaster(context);
    try {
      await Clipboard.setData(ClipboardData(text: await _json()));
      toast(t('Копію скопійовано — вставте її в нотатки чи месенджер'));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final clients = ref.watch(clientsProvider).value?.length ?? 0;
    final services = ref.watch(servicesProvider).value?.length ?? 0;
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
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  reveal(Text(t('Резервна копія'),
                      style: AppTypography.title1(k.ink))),
                  const SizedBox(height: 10),
                  reveal(Text(
                    t('Ваші дані зберігаються на цьому пристрої. Заберіть копію файлом — і робота переживе загублений телефон.'),
                    style: AppTypography.body(k.ink2).copyWith(fontSize: 13.5),
                  )),
                  const SizedBox(height: 18),
                  reveal(ZHero(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                              color: k.accentTint,
                              borderRadius: BorderRadius.circular(14)),
                          child: Icon(Icons.inventory_2_outlined,
                              size: 21, color: k.accent),
                        ),
                        const SizedBox(width: 13),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(t('У копію потрапляє все'),
                                  style: AppTypography.title3(k.ink)
                                      .copyWith(fontSize: 15)),
                              const SizedBox(height: 3),
                              Text(
                                tp('{c} клієнтів · {s} послуг · усі візити, розклад і фото робіт',
                                    {'c': clients, 's': services}),
                                style: AppTypography.label(k.ink2)
                                    .copyWith(fontSize: 12, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  )),
                  const SizedBox(height: 16),
                  reveal(ZButton(
                    label: t('Зберегти файл'),
                    icon: Icons.download_outlined,
                    onTap: _busy ? null : _save,
                  )),
                  const SizedBox(height: 10),
                  reveal(ZButtonSecondary(
                    label: t('Скопіювати текстом'),
                    expand: true,
                    onTap: _busy ? null : _copy,
                  )),
                  const SizedBox(height: 20),
                  reveal(ZLabel(t('Що з цим робити'))),
                  const SizedBox(height: 8),
                  reveal(const _Steps()),
                  const SizedBox(height: 16),
                  reveal(ZCard(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, size: 17, color: k.ink3),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t('Поки що копію можна тільки зберегти. Відновлення з файлу з’явиться разом із хмарою — тоді ж дані почнуть копіюватися самі.'),
                            style: AppTypography.body(k.ink3)
                                .copyWith(fontSize: 12.5, height: 1.5),
                          ),
                        ),
                      ],
                    ),
                  )),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Просто й по кроках: людині, яка вперше чує слово «бекап», має бути
/// зрозуміло, куди подіти файл.
class _Steps extends StatelessWidget {
  const _Steps();

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final steps = [
      t('Натисніть «Зберегти файл» — він ляже у ваші документи чи завантаження.'),
      t('Надішліть його собі в месенджер або покладіть у хмару (Google Drive, iCloud).'),
      t('Робіть це раз на тиждень — цього досить, щоб нічого не втратити.'),
    ];
    return ZCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var i = 0; i < steps.length; i++) ...[
            if (i > 0) const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                      color: k.surface2,
                      borderRadius: BorderRadius.circular(8)),
                  child: Text('${i + 1}',
                      style: AppTypography.tabular(AppTypography.label(k.ink2))
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(steps[i],
                      style: AppTypography.body(k.ink2)
                          .copyWith(fontSize: 13, height: 1.5)),
                ),
              ],
            ),
          ],
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
