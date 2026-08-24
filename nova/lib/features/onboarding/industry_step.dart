import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/industry/industry_templates.dart';
import '../../core/localization/app_text.dart';
import '../../core/services/analytics/analytics_events.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../ui/z.dart';

/// «Чим ви займаєтесь» — останній крок онбордингу.
///
/// Каталог сфер (IndustryCatalog) існував із самого початку, але його ніхто не
/// викликав: усі отримували манікюрний прайс, навіть автосервіс. Цей екран
/// вмикає його — обрав сферу, і за пів хвилини маєш свої категорії, послуги й
/// орієнтовні ціни, які далі правиш під себе.
class IndustryStep extends ConsumerStatefulWidget {
  const IndustryStep({super.key, required this.onDone});

  /// Викликається після застосування шаблону (або пропуску).
  final VoidCallback onDone;

  @override
  ConsumerState<IndustryStep> createState() => _IndustryStepState();
}

class _IndustryStepState extends ConsumerState<IndustryStep> {
  String? _selected;
  bool _applying = false;

  Future<void> _apply() async {
    final id = _selected;
    if (id == null || _applying) return;
    setState(() => _applying = true);

    final template = IndustryCatalog.byId(id);
    await ref.read(workspaceRepositoryProvider).applyIndustry(
      id,
      [
        for (final e in template.flatServices)
          (
            e.category,
            e.service.name,
            e.service.durationMinutes,
            e.service.price
          ),
      ],
    );
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.industrySelected(id));
    if (mounted) widget.onDone();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    const items = IndustryCatalog.all;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(t('Чим ви\nзаймаєтесь?'),
                  style: AppTypography.display(k.ink)),
              const SizedBox(height: 10),
              Text(
                t('Підставимо ваші послуги, тривалість і приблизні ціни. Потім усе можна змінити.'),
                style: AppTypography.body(k.ink2).copyWith(fontSize: 15),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.38,
            ),
            itemCount: items.length,
            itemBuilder: (context, i) {
              final it = items[i];
              return StaggerReveal(
                index: i,
                step: const Duration(milliseconds: 35),
                child: _IndustryTile(
                  template: it,
                  selected: _selected == it.id,
                  onTap: () => setState(() => _selected = it.id),
                ),
              );
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
          child: Column(
            children: [
              ZButton(
                label: _selected == null
                    ? t('Оберіть сферу')
                    : t('Підготувати застосунок'),
                icon: Icons.auto_awesome,
                onTap: _selected == null || _applying ? null : _apply,
              ),
              const SizedBox(height: 10),
              TextButton(
                onPressed: () {
                  zTap();
                  widget.onDone();
                },
                child: Text(t('Налаштую сам'),
                    style: AppTypography.label(k.ink3)
                        .copyWith(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Плитка сфери: іконка у власному кольорі, назва, кількість послуг у шаблоні.
class _IndustryTile extends StatelessWidget {
  const _IndustryTile({
    required this.template,
    required this.selected,
    required this.onTap,
  });
  final IndustryTemplate template;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final count = template.flatServices.length;
    return GestureDetector(
      onTap: () {
        zTap();
        onTap();
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Motion.enter,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: k.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: selected ? template.color : k.line,
              width: selected ? 1.5 : 1),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: template.color.withValues(alpha: 0.45),
                    blurRadius: 26,
                    spreadRadius: -10,
                    offset: const Offset(0, 10),
                  )
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: template.color.withValues(alpha: selected ? 0.24 : 0.14),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Icon(template.icon, size: 19, color: template.color),
            ),
            const SizedBox(height: 10),
            Text(
              t(template.title),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.title3(k.ink).copyWith(fontSize: 14),
            ),
            const SizedBox(height: 2),
            Text(
              '$count ${tn(count, 'послуга', 'послуги', 'послуг')}',
              style: AppTypography.label(k.ink3).copyWith(fontSize: 11.5),
            ),
          ],
        ),
      ),
    );
  }
}
