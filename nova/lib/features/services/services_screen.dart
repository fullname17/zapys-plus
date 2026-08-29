import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../core/boot_uri.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/skeleton.dart';
import '../../ui/z.dart';
import '../calendar/calendar_screen.dart' show apptColor;
import 'create_service_sheet.dart';

/// Послуги: категорії, пошук, кольорові мітки, швидкі дії. Каталог реактивно з БД.
class ServicesScreen extends ConsumerStatefulWidget {
  const ServicesScreen({super.key});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  bool _sheetOpened = false;

  /// ?sheet=service відкриває лист створення одразу — для знімків екранів.
  void _maybeOpenBootSheet() {
    if (_sheetOpened || bootParam('sheet') != 'service') return;
    _sheetOpened = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) showCreateServiceSheet(context);
    });
  }

  /// Група послуги — назва категорії з бази. Для демо-послуг сиду, заведених
  /// до появи категорій, лишається запасний розбір за id.
  static String _cat(Service s) {
    final c = s.category;
    if (c != null && c.trim().isNotEmpty) return c.trim();
    final id = s.id;
    return (id.contains('spa') || id.contains('exp') || id.contains('ped'))
        ? 'Педикюр'
        : 'Манікюр';
  }

  @override
  Widget build(BuildContext context) {
    _maybeOpenBootSheet();
    final k = context.kavio;
    final servicesAsync = ref.watch(servicesProvider);
    final loading = skeletonPreview() ||
        (servicesAsync.isLoading && !servicesAsync.hasValue);
    final services = servicesAsync.value ?? const <Service>[];

    final groups = <String, List<Service>>{};
    for (final s in services) {
      groups.putIfAbsent(_cat(s), () => []).add(s);
    }
    // Порядок груп — як їх завела сфера; звичні б'юті-групи лишаємо зверху.
    const order = ['Манікюр', 'Педикюр'];
    final cats = [
      ...order.where(groups.containsKey),
      ...groups.keys.where((c) => !order.contains(c)),
    ];

    var idx = 0;
    Widget reveal(Widget c) => StaggerReveal(index: idx++, child: c);

    return Scaffold(
      backgroundColor: k.canvas,
      body: SafeArea(
        bottom: false,
        child: ZSkeletonSwap(
          loading: loading,
          skeleton: const ServicesSkeleton(),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
            children: [
              reveal(Row(
                children: [
                  Expanded(
                      child: Text(t('Послуги'),
                          style: AppTypography.title1(k.ink))),
                  Semantics(
                    button: true,
                    label: t('Нова послуга'),
                    child: GestureDetector(
                      onTap: () => showCreateServiceSheet(context),
                      child: Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                            color: k.surface2,
                            borderRadius: BorderRadius.circular(11)),
                        child: Icon(Icons.add, color: k.accent, size: 20),
                      ),
                    ),
                  ),
                ],
              )),
              const SizedBox(height: 14),
              reveal(const _SearchBar()),
              const SizedBox(height: 16),
              for (final cat in cats) ...[
                reveal(Padding(
                  padding: const EdgeInsets.only(left: 2, bottom: 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ZLabel(t(cat)),
                      Text(
                          '${groups[cat]!.length} ${tn(groups[cat]!.length, 'послуга', 'послуги', 'послуг')}',
                          style: AppTypography.label(k.ink3)
                              .copyWith(fontSize: 12)),
                    ],
                  ),
                )),
                reveal(_CategoryCard(items: groups[cat]!)),
                const SizedBox(height: 16),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar();
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZGlass(
      radius: 14,
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      child: Row(
        children: [
          Icon(Icons.search, size: 18, color: k.ink3),
          const SizedBox(width: 10),
          Text(t('Пошук послуги'),
              style: AppTypography.body(k.ink3).copyWith(fontSize: 14)),
        ],
      ),
    );
  }
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({required this.items});
  final List<Service> items;
  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ZCard(
      padding: const EdgeInsets.all(4),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++)
            Semantics(
              button: true,
              label:
                  '${items[i].name}, ${Fmt.duration(items[i].durationMinutes)}, ${Fmt.money(items[i].price)}',
              excludeSemantics: true,
              child: GestureDetector(
                onTap: () {
                  zTap();
                  showEditServiceSheet(context, items[i]);
                },
                behavior: HitTestBehavior.opaque,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
                  decoration: BoxDecoration(
                    border:
                        i == 0 ? null : Border(top: BorderSide(color: k.line)),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: apptColor(items[i].id,
                                category: items[i].category),
                            borderRadius: BorderRadius.circular(4)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(items[i].name,
                                style: AppTypography.label(k.ink).copyWith(
                                    fontSize: 14, fontWeight: FontWeight.w600)),
                            Text(
                                [
                                  Fmt.duration(items[i].durationMinutes),
                                  // Строк повтору видно одразу з каталогу —
                                  // саме він наповнює «Пора на повтор».
                                  if (items[i].repeatAfterDays != null)
                                    tp('повтор через {n} {d}', {
                                      'n': items[i].repeatAfterDays!,
                                      'd': tn(items[i].repeatAfterDays!, 'день',
                                          'дні', 'днів'),
                                    }),
                                ].join(' · '),
                                style: AppTypography.label(k.ink3)
                                    .copyWith(fontSize: 12)),
                          ],
                        ),
                      ),
                      Text(Fmt.money(items[i].price),
                          style:
                              AppTypography.tabular(AppTypography.label(k.ink))
                                  .copyWith(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700)),
                      const SizedBox(width: 10),
                      Icon(Icons.chevron_right, size: 18, color: k.ink3),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
