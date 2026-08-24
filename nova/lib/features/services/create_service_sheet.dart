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

/// Нова послуга — v3 bottom sheet. Зверху живий рядок каталогу: кольорова
/// мітка категорії, назва, тривалість і ціна складаються під час набору.
/// Тривалість і ціна мають пресети — типова послуга додається у три дотики.
/// Ціна вводиться в гривнях, зберігається в мінорних одиницях (×100).
Future<void> showCreateServiceSheet(BuildContext context) =>
    showKavioSheet<void>(context, builder: (_) => const _CreateServiceSheet());

class _CreateServiceSheet extends ConsumerStatefulWidget {
  const _CreateServiceSheet();

  @override
  ConsumerState<_CreateServiceSheet> createState() =>
      _CreateServiceSheetState();
}

class _CreateServiceSheetState extends ConsumerState<_CreateServiceSheet> {
  final _name = TextEditingController();
  final _duration = TextEditingController(text: '60');
  final _price = TextEditingController();
  bool _saving = false;

  /// Категорія визначає колір мітки в календарі й каталозі — той самий
  /// [apptColor], тільки обраний явно, а не вгаданий з id.
  static const _categories = <(String, String, Color)>[
    ('cat_man', 'Манікюр', Color(0xFF9A9AF6)),
    ('cat_ped', 'Педикюр', Color(0xFF46D08A)),
    ('cat_other', 'Інше', Color(0xFFE6B24E)),
  ];
  String _categoryId = 'cat_man';

  static const _durationPresets = [30, 45, 60, 90];
  static const _pricePresets = [350, 500, 650, 750];

  @override
  void dispose() {
    _name.dispose();
    _duration.dispose();
    _price.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;
  int get _minutes => int.tryParse(_duration.text.trim()) ?? 60;
  int get _major => int.tryParse(_price.text.trim()) ?? 0;

  Color get _categoryColor =>
      _categories.firstWhere((c) => c.$1 == _categoryId).$3;

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final service = Service(
      // Категорія зашита в id — саме звідти каталог і календар беруть колір.
      id: '${_categoryId}_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      durationMinutes: _minutes,
      price: _major * 100,
      category: _categoryId,
    );
    await ref.read(servicesRepositoryProvider).add(service);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.serviceCreated);

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
          content: Text(tp('Послугу «{name}» додано', {'name': service.name}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return KavioSheet(
      title: t('Нова послуга'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Превью майбутнього рядка каталогу.
          reveal(ZCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Motion.enter,
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                      color: _categoryColor,
                      borderRadius: BorderRadius.circular(4)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _valid ? _name.text.trim() : t('Напр. Гель-лак'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title3(_valid ? k.ink : k.ink3)
                            .copyWith(fontSize: 15),
                      ),
                      const SizedBox(height: 2),
                      Text(Fmt.duration(_minutes),
                          style: AppTypography.label(k.ink3)
                              .copyWith(fontSize: 12)),
                    ],
                  ),
                ),
                Text(Fmt.money(_major * 100),
                    style: AppTypography.tabular(AppTypography.title3(k.ink))
                        .copyWith(fontSize: 15, fontWeight: FontWeight.w800)),
              ],
            ),
          )),
          const SizedBox(height: 18),

          reveal(ZField(
            label: t('Назва'),
            hint: t('Напр. Гель-лак'),
            controller: _name,
            icon: Icons.spa_outlined,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 18),

          reveal(ZLabel(t('Категорія'))),
          const SizedBox(height: 8),
          reveal(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in _categories)
                ZChip(
                  selected: _categoryId == c.$1,
                  onTap: () => setState(() => _categoryId = c.$1),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _categoryId == c.$1 ? Colors.white : c.$3,
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 7),
                      Text(t(c.$2),
                          style: AppTypography.label(
                                  _categoryId == c.$1 ? Colors.white : k.ink)
                              .copyWith(
                                  fontSize: 13, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ),
            ],
          )),
          const SizedBox(height: 18),

          reveal(ZField(
            label: t('Тривалість, хв'),
            hint: '60',
            controller: _duration,
            icon: Icons.schedule,
            suffix: t('хв'),
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 8),
          reveal(_Presets(
            values: _durationPresets,
            selected: _minutes,
            format: (v) => '$v',
            onPick: (v) => setState(() => _duration.text = '$v'),
          )),
          const SizedBox(height: 18),

          reveal(ZField(
            label: t('Ціна'),
            hint: '0',
            controller: _price,
            icon: Icons.payments_outlined,
            suffix: Fmt.currency.symbol,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 8),
          reveal(_Presets(
            values: _pricePresets,
            selected: _major,
            format: (v) => Fmt.money(v * 100),
            onPick: (v) => setState(() => _price.text = '$v'),
          )),
          const SizedBox(height: 22),

          reveal(ZButton(
            label: t('Зберегти'),
            icon: Icons.check,
            onTap: _valid && !_saving ? _save : null,
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

/// Ряд швидких значень під полем: типова тривалість і типова ціна в один дотик.
class _Presets extends StatelessWidget {
  const _Presets({
    required this.values,
    required this.selected,
    required this.format,
    required this.onPick,
  });
  final List<int> values;
  final int selected;
  final String Function(int) format;
  final ValueChanged<int> onPick;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final v in values)
          ZChip(
            selected: selected == v,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            onTap: () => onPick(v),
            child: Text(
              format(v),
              style: AppTypography.tabular(AppTypography.label(
                      selected == v ? Colors.white : k.ink2))
                  .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
            ),
          ),
      ],
    );
  }
}
