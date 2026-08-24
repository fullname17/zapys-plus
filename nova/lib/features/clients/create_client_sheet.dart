import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../core/services/analytics/analytics_events.dart';
import '../../core/services/analytics/analytics_service.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/z.dart';

/// Новий клієнт — v3 bottom sheet. Живе превью зверху: аватар і підпис
/// збираються просто під час набору, тож видно, як клієнт з'явиться в списку.
/// Зберігається в Drift (offline-first) → список оновлюється реактивно.
Future<void> showCreateClientSheet(BuildContext context) =>
    showKavioSheet<void>(context, builder: (_) => const _CreateClientSheet());

class _CreateClientSheet extends ConsumerStatefulWidget {
  const _CreateClientSheet();

  @override
  ConsumerState<_CreateClientSheet> createState() => _CreateClientSheetState();
}

class _CreateClientSheetState extends ConsumerState<_CreateClientSheet> {
  final _name = TextEditingController();
  final _phone = TextEditingController();
  final _note = TextEditingController();
  bool _saving = false;

  // Міток тут немає навмисно: «Постійна» і «VIP» продукт виводить із
  // поведінки клієнта (візити й витрати), а не проставляє руками.

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _note.dispose();
    super.dispose();
  }

  bool get _valid => _name.text.trim().isNotEmpty;

  String get _initials {
    final parts = _name.text.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '—';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Future<void> _save() async {
    if (!_valid || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    final client = Client(
      id: 'c${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
    );
    await ref.read(clientsRepositoryProvider).add(client);
    await ref
        .read(analyticsServiceProvider)
        .track(AnalyticsEvent.clientCreated);

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(
          content: Text(tp('Клієнта {name} додано', {'name': client.name}))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return KavioSheet(
      title: t('Новий клієнт'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Превью майбутнього рядка в списку клієнтів.
          reveal(ZHero(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                AnimatedScale(
                  scale: _valid ? 1 : 0.94,
                  duration: const Duration(milliseconds: 220),
                  curve: Motion.enter,
                  child: ZAvatar(initials: _initials, size: 46, ring: _valid),
                ),
                const SizedBox(width: 13),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _valid ? _name.text.trim() : t('Як звати клієнта'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.title2(_valid ? k.ink : k.ink3)
                            .copyWith(fontSize: 18),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _phone.text.trim().isEmpty
                            ? t('Телефон')
                            : _phone.text.trim(),
                        style:
                            AppTypography.tabular(AppTypography.label(k.ink2))
                                .copyWith(fontSize: 13),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          )),
          const SizedBox(height: 18),

          reveal(ZField(
            label: t("Ім'я"),
            hint: t('Як звати клієнта'),
            controller: _name,
            icon: Icons.person_outline,
            autofocus: true,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 14),
          reveal(ZField(
            label: t('Телефон'),
            hint: '+380 67 123 45 67',
            controller: _phone,
            icon: Icons.phone_outlined,
            keyboardType: TextInputType.phone,
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 18),

          reveal(ZField(
            label: t('Нотатки'),
            hint: t('Улюблений колір, алергії, побажання'),
            controller: _note,
            icon: Icons.sticky_note_2_outlined,
            maxLines: 2,
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
