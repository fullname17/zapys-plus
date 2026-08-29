import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/industry/visit_fields.dart';
import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/z.dart';

/// Параметри роботи й нотатка до візиту.
///
/// Через це майстри й досі носять паперовий зошит: наступного разу треба
/// згадати вигин і товщину вій, формулу кольору, номер лаку. Поля підставляє
/// сфера майстра, значення — свої або з пресетів.
Future<void> showVisitDetailsSheet(BuildContext context, Appointment a) =>
    showKavioSheet<void>(context, builder: (_) => _VisitDetailsSheet(a));

class _VisitDetailsSheet extends ConsumerStatefulWidget {
  const _VisitDetailsSheet(this.appointment);
  final Appointment appointment;

  @override
  ConsumerState<_VisitDetailsSheet> createState() => _VisitDetailsSheetState();
}

class _VisitDetailsSheetState extends ConsumerState<_VisitDetailsSheet> {
  final _controllers = <String, TextEditingController>{};
  late final TextEditingController _note;
  bool _saving = false;

  Appointment get _a => widget.appointment;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: _a.note ?? '');
  }

  /// Контролер поля створюється при першій появі: набір полів приходить із
  /// провайдера сфери, тож у initState його ще немає.
  TextEditingController _controllerFor(String label) =>
      _controllers.putIfAbsent(
          label, () => TextEditingController(text: _a.params[label] ?? ''));

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final toast = zToaster(context);
    final navigator = Navigator.of(context);

    // Порожні поля не зберігаємо — інакше картка обростає пустими рядками.
    final params = <String, String>{
      for (final e in _controllers.entries)
        if (e.value.text.trim().isNotEmpty) e.key: e.value.text.trim(),
    };
    await ref
        .read(appointmentsRepositoryProvider)
        .setDetails(_a.id, _note.text, params);

    navigator.pop();
    toast(t('Записано в картку візиту'));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final industry = ref.watch(industryProvider).value;
    final fields = VisitFields.forIndustry(industry);
    var i = 0;
    Widget reveal(Widget c) => StaggerReveal(index: i++, child: c);

    return KavioSheet(
      title: t('Робота'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          reveal(Text(
            tp('{name} · {service}',
                {'name': _a.client.name, 'service': _a.service.name}),
            style: AppTypography.label(k.ink3).copyWith(fontSize: 13),
          )),
          const SizedBox(height: 6),
          reveal(Text(
            t('Наступного разу ці записи будуть перед очима — не доведеться згадувати.'),
            style: AppTypography.body(k.ink2).copyWith(fontSize: 13),
          )),
          const SizedBox(height: 18),
          for (final f in fields) ...[
            reveal(ZField(
              label: t(f.label),
              controller: _controllerFor(f.label),
              onChanged: (_) => setState(() {}),
            )),
            if (f.presets.isNotEmpty) ...[
              const SizedBox(height: 8),
              reveal(Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in f.presets)
                    ZChip(
                      selected: _controllerFor(f.label).text == p,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 7),
                      onTap: () {
                        zTap();
                        final c = _controllerFor(f.label);
                        // Повторний дотик знімає значення — поле не пастка.
                        setState(() => c.text = c.text == p ? '' : p);
                      },
                      child: Text(
                        p,
                        style: AppTypography.label(
                                _controllerFor(f.label).text == p
                                    ? Colors.white
                                    : k.ink2)
                            .copyWith(
                                fontSize: 12.5, fontWeight: FontWeight.w600),
                      ),
                    ),
                ],
              )),
            ],
            const SizedBox(height: 16),
          ],
          reveal(ZField(
            label: t('Нотатка'),
            hint: t('Як пройшло, що врахувати наступного разу'),
            controller: _note,
            maxLines: 4,
          )),
          const SizedBox(height: 20),
          reveal(ZButton(
            label: t('Зберегти'),
            icon: Icons.check,
            onTap: _saving ? null : _save,
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
