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

/// Послуга — v3 bottom sheet, один і той самий для створення й редагування.
/// Зверху живий рядок каталогу: кольорова мітка категорії, назва, тривалість
/// і ціна складаються під час набору. Тривалість і ціна мають пресети.
/// Ціна вводиться в гривнях, зберігається в мінорних одиницях (×100).
Future<void> showCreateServiceSheet(BuildContext context) =>
    showKavioSheet<void>(context, builder: (_) => const _ServiceSheet());

/// Редагування наявної послуги: ті самі поля, плюс «Прибрати з каталогу».
Future<void> showEditServiceSheet(BuildContext context, Service service) =>
    showKavioSheet<void>(context,
        builder: (_) => _ServiceSheet(existing: service));

class _ServiceSheet extends ConsumerStatefulWidget {
  const _ServiceSheet({this.existing});
  final Service? existing;

  @override
  ConsumerState<_ServiceSheet> createState() => _ServiceSheetState();
}

class _ServiceSheetState extends ConsumerState<_ServiceSheet> {
  late final TextEditingController _name;
  late final TextEditingController _duration;
  late final TextEditingController _price;
  bool _saving = false;

  Service? get _existing => widget.existing;
  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    _name = TextEditingController(text: e?.name ?? '');
    _duration = TextEditingController(text: '${e?.durationMinutes ?? 60}');
    _price = TextEditingController(
        text: e == null ? '' : '${(e.price / 100).round()}');
    _repeatAfterDays = e?.repeatAfterDays;
    if (e?.category != null) _categoryId = e!.category!;
  }

  /// Категорія визначає колір мітки в календарі й каталозі — той самий
  /// [apptColor], тільки обраний явно, а не вгаданий з id.
  /// Групи каталогу. Список рухомий: сюди підмішуються категорії, які вже є
  /// в майстра (з шаблону його сфери), тож барбер не обирає між манікюром і
  /// педикюром.
  static const _fallbackCategories = ['Манікюр', 'Педикюр', 'Інше'];
  String _categoryId = '';

  static const _durationPresets = [30, 45, 60, 90];
  static const _pricePresets = [350, 500, 650, 750];

  /// Через скільки днів послугу зазвичай повторюють. null — послуга разова.
  int? _repeatAfterDays;
  static const _repeatPresets = [14, 21, 28, 45, 60];

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

  Color get _categoryColor => apptColor('', category: _categoryId);

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(servicesRepositoryProvider);

    final service = Service(
      // При редагуванні id незмінний, інакше минулі записи осиротіли б.
      id: _existing?.id ?? 'sv_${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      durationMinutes: _minutes,
      price: _major * 100,
      category: _categoryId,
      repeatAfterDays: _repeatAfterDays,
    );

    if (_isEdit) {
      await repo.update(service);
    } else {
      await repo.add(service);
      await ref
          .read(analyticsServiceProvider)
          .track(AnalyticsEvent.serviceCreated);
    }

    navigator.pop();
    toast(_isEdit
        ? tp('Послугу «{name}» змінено', {'name': service.name})
        : tp('Послугу «{name}» додано', {'name': service.name}));
  }

  /// Прибирання з каталогу м'яке: минулі візити на цю послугу лишаються
  /// цілими, інакше з історії клієнта зникли б записи.
  Future<void> _archive() async {
    final e = _existing!;
    HapticFeedback.mediumImpact();
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final repo = ref.read(servicesRepositoryProvider);

    await repo.archive(e.id);
    navigator.pop();
    toast(
      tp('Послугу «{name}» прибрано', {'name': e.name}),
      actionLabel: t('Повернути'),
      onAction: () => repo.update(e),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;

    // Групи майстра + запасні, щоб було з чого обрати на порожньому каталозі.
    final existing = (ref.watch(servicesProvider).value ?? const <Service>[])
        .map((s) => s.category)
        .whereType<String>()
        .toSet();
    final categories = <String>{...existing, ..._fallbackCategories}.toList();
    if (_categoryId.isEmpty) _categoryId = categories.first;

    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return KavioSheet(
      title: _isEdit ? t('Послуга') : t('Нова послуга'),
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
              for (final c in categories)
                ZChip(
                  selected: _categoryId == c,
                  onTap: () => setState(() => _categoryId = c),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            color: _categoryId == c
                                ? Colors.white
                                : apptColor('', category: c),
                            borderRadius: BorderRadius.circular(3)),
                      ),
                      const SizedBox(width: 7),
                      Text(t(c),
                          style: AppTypography.label(
                                  _categoryId == c ? Colors.white : k.ink)
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
          const SizedBox(height: 18),

          // Ритм послуги. З нього застосунок сам збирає список «кого пора
          // кликати» — раніше майстер тримав ці строки в голові.
          reveal(ZLabel(t('Повторювати через'))),
          const SizedBox(height: 8),
          reveal(Text(
            t('Через скільки днів клієнту зазвичай треба на цю послугу знову.'),
            style: AppTypography.label(k.ink3).copyWith(fontSize: 12),
          )),
          const SizedBox(height: 10),
          reveal(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ZChip(
                selected: _repeatAfterDays == null,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                onTap: () {
                  zTap();
                  setState(() => _repeatAfterDays = null);
                },
                child: Text(
                  t('Не нагадувати'),
                  style: AppTypography.label(
                          _repeatAfterDays == null ? Colors.white : k.ink2)
                      .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              for (final d in _repeatPresets)
                ZChip(
                  selected: _repeatAfterDays == d,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  onTap: () {
                    zTap();
                    setState(() => _repeatAfterDays = d);
                  },
                  child: Text(
                    '$d ${tn(d, 'день', 'дні', 'днів')}',
                    style: AppTypography.tabular(AppTypography.label(
                            _repeatAfterDays == d ? Colors.white : k.ink2))
                        .copyWith(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          )),
          const SizedBox(height: 22),

          reveal(ZButton(
            label: t('Зберегти'),
            icon: Icons.check,
            onTap: _valid && !_saving ? _save : null,
          )),
          if (_isEdit) ...[
            const SizedBox(height: 10),
            reveal(Center(
              child: TextButton(
                onPressed: () {
                  zTap();
                  _archive();
                },
                child: Text(t('Прибрати з каталогу'),
                    style: AppTypography.label(k.danger)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            )),
          ],
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
