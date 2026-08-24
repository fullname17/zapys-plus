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

/// Клієнт — v3 bottom sheet, один і той самий для створення й редагування.
/// Живе превью зверху: аватар і підпис збираються просто під час набору, тож
/// видно, як клієнт з'явиться в списку. Зберігається в Drift (offline-first).
Future<void> showCreateClientSheet(BuildContext context) =>
    showKavioSheet<void>(context, builder: (_) => const _ClientSheet());

/// Редагування картки клієнта: ім'я, телефон, нотатка, плюс видалення.
Future<void> showEditClientSheet(BuildContext context, Client client) =>
    showKavioSheet<void>(context,
        builder: (_) => _ClientSheet(existing: client));

class _ClientSheet extends ConsumerStatefulWidget {
  const _ClientSheet({this.existing});
  final Client? existing;

  @override
  ConsumerState<_ClientSheet> createState() => _ClientSheetState();
}

class _ClientSheetState extends ConsumerState<_ClientSheet> {
  late final TextEditingController _name;
  late final TextEditingController _phone;
  late final TextEditingController _note;
  bool _saving = false;

  Client? get _existing => widget.existing;
  bool get _isEdit => _existing != null;

  @override
  void initState() {
    super.initState();
    final e = _existing;
    _name = TextEditingController(text: e?.name ?? '');
    _phone = TextEditingController(text: e?.phone ?? '');
    _note = TextEditingController(text: e?.note ?? '');
  }

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
    // Тостер беремо до await: контекст листа помре після pop.
    final toast = zToaster(context);
    final navigator = Navigator.of(context);

    final repo = ref.read(clientsRepositoryProvider);
    final e = _existing;
    final client = Client(
      // При редагуванні id незмінний — історія візитів лишається на місці.
      id: e?.id ?? 'c${DateTime.now().microsecondsSinceEpoch}',
      name: _name.text.trim(),
      phone: _phone.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      visitsCount: e?.visitsCount ?? 0,
      totalSpent: e?.totalSpent ?? 0,
    );

    if (_isEdit) {
      await repo.update(client);
    } else {
      await repo.add(client);
      await ref
          .read(analyticsServiceProvider)
          .track(AnalyticsEvent.clientCreated);
    }

    navigator.pop();
    toast(_isEdit
        ? tp('Картку {name} збережено', {'name': client.name})
        : tp('Клієнта {name} додано', {'name': client.name}));
  }

  /// Видалення забирає й візити клієнта — інакше в календарі лишились би
  /// записи, які нікуди не ведуть. Тому підтверджуємо окремо.
  Future<void> _delete() async {
    final e = _existing!;
    final confirmed = await showKavioSheet<bool>(context,
        builder: (c) => _ConfirmDelete(name: e.name));
    if (confirmed != true || !mounted) return;

    HapticFeedback.mediumImpact();
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    await ref.read(clientsRepositoryProvider).delete(e.id);
    navigator.pop();
    toast(tp('Клієнта {name} видалено', {'name': e.name}));
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    var i = 0;
    Widget reveal(Widget child) => StaggerReveal(index: i++, child: child);

    return KavioSheet(
      title: _isEdit ? t('Картка клієнта') : t('Новий клієнт'),
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
          if (_isEdit) ...[
            const SizedBox(height: 10),
            reveal(Center(
              child: TextButton(
                onPressed: () {
                  zTap();
                  _delete();
                },
                child: Text(t('Видалити клієнта'),
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

/// Підтвердження видалення клієнта: разом із карткою зникає історія візитів,
/// і «Повернути» тут уже не допоможе — тому питаємо заздалегідь.
class _ConfirmDelete extends StatelessWidget {
  const _ConfirmDelete({required this.name});
  final String name;

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return KavioSheet(
      title: t('Видалити клієнта?'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            tp('Картка {name} і вся історія візитів зникнуть назавжди.',
                {'name': name}),
            style: AppTypography.body(k.ink2).copyWith(fontSize: 14),
          ),
          const SizedBox(height: 20),
          ZButton(
            label: t('Видалити'),
            icon: Icons.delete_outline,
            onTap: () => Navigator.of(context).pop(true),
          ),
          const SizedBox(height: 10),
          ZButtonSecondary(
            label: t('Скасувати'),
            expand: true,
            onTap: () => Navigator.of(context).pop(false),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
