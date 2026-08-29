import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/z.dart';

/// Передоплата за візит.
///
/// Це позначка, а не платіж: застосунок нічого не проводить і нікуди не
/// переказує — гроші майстер отримує сам (переказ на картку, готівка), а тут
/// лише запам'ятовує суму, щоб на місці було видно, скільки лишилося доплатити.
/// Саме через передоплату майстри страхуються від неявок, і досі це доводилось
/// тримати в голові або в нотатках телефона.
Future<void> showDepositSheet(BuildContext context, Appointment a) =>
    showKavioSheet<void>(context,
        builder: (_) => _DepositSheet(appointment: a));

class _DepositSheet extends ConsumerStatefulWidget {
  const _DepositSheet({required this.appointment});
  final Appointment appointment;

  @override
  ConsumerState<_DepositSheet> createState() => _DepositSheetState();
}

class _DepositSheetState extends ConsumerState<_DepositSheet> {
  late final TextEditingController _amount;

  Appointment get _a => widget.appointment;

  /// Частки ціни, які майстри беруть найчастіше.
  static const _shares = [30, 50, 100];

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(
        text: _a.depositMinor > 0 ? '${(_a.depositMinor / 100).round()}' : '');
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  int get _minor => (int.tryParse(_amount.text.trim()) ?? 0) * 100;

  /// Передоплата більша за ціну — це вже не передоплата, а помилка вводу.
  int get _capped => _minor > _a.service.price ? _a.service.price : _minor;

  int get _left => _a.service.price - _capped;

  void _setShare(int percent) {
    zTap();
    final minor = (_a.service.price * percent / 100).round();
    setState(() => _amount.text = '${(minor / 100).round()}');
  }

  Future<void> _save() async {
    HapticFeedback.mediumImpact();
    final toast = zToaster(context);
    final navigator = Navigator.of(context);
    final was = _a.depositMinor;
    final repo = ref.read(appointmentsRepositoryProvider);
    final next = _capped;

    await repo.setDeposit(_a.id, next);
    navigator.pop();
    toast(
      next == 0
          ? t('Передоплату знято')
          : tp('Передоплата {sum} · {name}',
              {'sum': Fmt.money(next), 'name': _a.client.name}),
      actionLabel: was == next ? null : t('Повернути'),
      onAction: was == next ? null : () => repo.setDeposit(_a.id, was),
    );
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    final price = _a.service.price;
    var i = 0;
    Widget reveal(Widget c) => StaggerReveal(index: i++, child: c);

    return KavioSheet(
      title: t('Передоплата'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          reveal(ZHero(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZLabel('${_a.client.name} · ${_a.service.name}',
                    color: k.accent),
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(Fmt.money(_capped),
                        style: AppTypography.tabular(AppTypography.title1(
                            _capped > 0 ? k.success : k.ink3))),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        tp('з {sum}', {'sum': Fmt.money(price)}),
                        style:
                            AppTypography.label(k.ink3).copyWith(fontSize: 13),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                // Смуга «скільки вже внесено» — сума на місці читається одразу.
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: price == 0 ? 0 : _capped / price,
                    minHeight: 6,
                    backgroundColor: k.surface3,
                    valueColor: AlwaysStoppedAnimation(k.success),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  _left == 0
                      ? t('Оплачено повністю — на місці доплачувати нічого.')
                      : tp('На місці лишиться доплатити {sum}',
                          {'sum': Fmt.money(_left)}),
                  style: AppTypography.body(k.ink2).copyWith(fontSize: 13),
                ),
              ],
            ),
          )),
          const SizedBox(height: 18),
          reveal(ZLabel(t('Частина ціни'))),
          const SizedBox(height: 8),
          reveal(Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ZChip(
                selected: _capped == 0,
                onTap: () {
                  zTap();
                  setState(() => _amount.text = '');
                },
                child: _chipText(t('Без передоплати'), _capped == 0),
              ),
              for (final p in _shares)
                ZChip(
                  selected: _capped > 0 && _capped == (price * p / 100).round(),
                  onTap: () => _setShare(p),
                  child: _chipText(p == 100 ? t('Повна сума') : '$p%',
                      _capped > 0 && _capped == (price * p / 100).round()),
                ),
            ],
          )),
          const SizedBox(height: 18),
          reveal(ZField(
            label: t('Або своя сума'),
            hint: '0',
            controller: _amount,
            icon: Icons.savings_outlined,
            suffix: Fmt.currency.symbol,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (_) => setState(() {}),
          )),
          const SizedBox(height: 14),
          reveal(Text(
            t('Застосунок не приймає гроші — він лише запам’ятовує, що ви їх уже отримали.'),
            style: AppTypography.label(k.ink3).copyWith(fontSize: 12),
          )),
          const SizedBox(height: 18),
          reveal(ZButton(
            label: t('Зберегти'),
            icon: Icons.check,
            onTap: _save,
          )),
          const SizedBox(height: 4),
        ],
      ),
    );
  }

  Widget _chipText(String label, bool on) => Text(
        label,
        style: AppTypography.label(on ? Colors.white : context.kavio.ink)
            .copyWith(fontSize: 13, fontWeight: FontWeight.w600),
      );
}
