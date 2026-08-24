import 'package:flutter/material.dart';

import '../core/boot_uri.dart';
import '../design/theme.dart';
import 'z.dart';

/// Скелетони замість спінерів. Форма — точна копія майбутнього вмісту, тож
/// коли дані приходять, макет не «стрибає»: кістки просто стають текстом.
///
/// Один такт на весь екран: [ZSkeleton] роздає спільну анімацію всім [ZBone]
/// нижче по дереву, тому блиск проходить сторінкою в один рух, а не мерехтить
/// у кожному прямокутнику окремо.

/// Примусово показати скелетони (?skeleton=1) — для знімків екранів у CI.
/// Реальна БД локальна й віддає дані миттєво, інакше цей стан не зняти.
bool skeletonPreview() => bootParam('skeleton') == '1';

/// Спільний такт мерехтіння для піддерева.
class _SkeletonTick extends InheritedWidget {
  const _SkeletonTick({required this.t, required super.child});
  final Animation<double> t;

  static Animation<double>? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_SkeletonTick>()?.t;

  @override
  bool updateShouldNotify(_SkeletonTick old) => old.t != t;
}

/// Обгортка екрана-скелета: тримає єдиний такт для всіх кісток усередині.
class ZSkeleton extends StatefulWidget {
  const ZSkeleton({super.key, required this.child});
  final Widget child;

  @override
  State<ZSkeleton> createState() => _ZSkeletonState();
}

class _ZSkeletonState extends State<ZSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1500))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _SkeletonTick(t: _c, child: widget.child);
}

/// «Кістка» — прямокутник на місці майбутнього тексту чи аватара. Мерехтіння
/// іде від surface2 до surface3 з ледь помітним іридієм на піку: скелет
/// лишається у фірмовій гамі, а не сірим.
class ZBone extends StatefulWidget {
  const ZBone({
    super.key,
    this.width,
    this.height = 12,
    this.radius = 6,
  });

  /// Кругла кістка — під аватар.
  const ZBone.circle(double size, {super.key})
      : width = size,
        height = size,
        radius = size / 2;

  final double? width;
  final double height;
  final double radius;

  @override
  State<ZBone> createState() => _ZBoneState();
}

class _ZBoneState extends State<ZBone> with SingleTickerProviderStateMixin {
  AnimationController? _own;

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    // Поза [ZSkeleton] кістка веде власний такт — щоб її можна було ставити
    // будь-де, не думаючи про обгортку.
    final shared = _SkeletonTick.maybeOf(context);
    final anim = shared ??
        (_own ??= AnimationController(
            vsync: this, duration: const Duration(milliseconds: 1500))
          ..repeat());

    final reduce = MediaQuery.of(context).disableAnimations;
    final base = k.surface2;
    final hi = Color.lerp(k.surface3, k.accent, 0.10)!;

    final box = SizedBox(
      width: widget.width,
      height: widget.height,
      child: AnimatedBuilder(
        animation: anim,
        builder: (context, _) {
          final t = reduce ? 0.5 : anim.value;
          return DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              gradient: LinearGradient(
                begin: Alignment(-1.8 + t * 3.6, 0),
                end: Alignment(-0.4 + t * 3.6, 0),
                colors: [base, hi, base],
              ),
            ),
          );
        },
      ),
    );
    // Ширина задана явно — не даємо батьківському контейнеру її розтягнути.
    return widget.width == null
        ? box
        : Align(alignment: Alignment.centerLeft, child: box);
  }
}

/// М'яка заміна скелета на дані: контент проступає крізь кістки, а не
/// підмінює їх стрибком.
class ZSkeletonSwap extends StatelessWidget {
  const ZSkeletonSwap({
    super.key,
    required this.loading,
    required this.skeleton,
    required this.child,
  });
  final bool loading;
  final Widget skeleton;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 320),
      switchInCurve: Motion.enter,
      switchOutCurve: Motion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      child: loading
          ? ZSkeleton(key: const ValueKey('skeleton'), child: skeleton)
          : KeyedSubtree(key: const ValueKey('content'), child: child),
    );
  }
}

// ─────────────────────────────────────────── Скелети екранів

/// «Сьогодні»: шапка → три плитки → герой наступного клієнта → вільні вікна.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZBone(width: 120, height: 11),
                SizedBox(height: 8),
                ZBone(width: 190, height: 24, radius: 8),
              ],
            ),
            Spacer(),
            ZBone.circle(44),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 10),
              const Expanded(child: _StatBone()),
            ],
          ],
        ),
        const SizedBox(height: 12),
        Container(
          decoration: FX.hero(radius: 24),
          padding: const EdgeInsets.all(16),
          child: const Row(
            children: [
              ZBone.circle(48),
              SizedBox(width: 13),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ZBone(width: 140, height: 10),
                  SizedBox(height: 8),
                  ZBone(width: 110, height: 15, radius: 7),
                  SizedBox(height: 7),
                  ZBone(width: 160, height: 11),
                ],
              ),
              Spacer(),
              ZBone.circle(52),
            ],
          ),
        ),
        const SizedBox(height: 16),
        const ZBone(width: 96, height: 11),
        const SizedBox(height: 10),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(child: ZBone(height: 58, radius: 16)),
            ],
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 52,
          decoration: BoxDecoration(
            color: k.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: k.line),
          ),
        ),
      ],
    );
  }
}

class _StatBone extends StatelessWidget {
  const _StatBone();

  @override
  Widget build(BuildContext context) {
    return const ZCard(
      padding: EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          ZBone(width: 52, height: 9),
          SizedBox(height: 10),
          ZBone(width: 68, height: 20, radius: 7),
          SizedBox(height: 8),
          ZBone(width: 44, height: 9),
        ],
      ),
    );
  }
}

/// День календаря: заголовок → сегменти → плитки → стрічка часу.
class CalendarDaySkeleton extends StatelessWidget {
  const CalendarDaySkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZBone(width: 84, height: 10),
                SizedBox(height: 8),
                ZBone(width: 150, height: 24, radius: 8),
              ],
            ),
            Spacer(),
            ZBone(width: 34, height: 34, radius: 11),
            SizedBox(width: 8),
            ZBone(width: 34, height: 34, radius: 11),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 44,
          decoration: BoxDecoration(
              color: k.surface2, borderRadius: BorderRadius.circular(14)),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(child: _StatBone()),
            ],
          ],
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < 4; i++) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: 44,
                  child: Padding(
                    padding: EdgeInsets.only(top: 4, right: 6),
                    child: ZBone(height: 10),
                  ),
                ),
                Expanded(
                  child: Container(
                    height: 62,
                    decoration: BoxDecoration(
                      color: k.surface,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: k.line),
                    ),
                    padding: const EdgeInsets.fromLTRB(15, 12, 13, 12),
                    child: const Row(
                      children: [
                        ZBone.circle(30),
                        SizedBox(width: 9),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ZBone(width: 128, height: 11),
                            SizedBox(height: 7),
                            ZBone(width: 92, height: 10),
                          ],
                        ),
                        Spacer(),
                        ZBone(width: 48, height: 12),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Список клієнтів / послуг: однакові «дорогі» рядки.
class RowsSkeleton extends StatelessWidget {
  const RowsSkeleton({super.key, this.count = 6, this.padding});
  final int count;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: padding ?? const EdgeInsets.fromLTRB(20, 0, 20, 120),
      itemCount: count,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const ZCard(
        padding: EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            ZBone.circle(44),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ZBone(width: 132, height: 12),
                SizedBox(height: 8),
                ZBone(width: 98, height: 10),
              ],
            ),
            Spacer(),
            ZBone(width: 56, height: 13),
          ],
        ),
      ),
    );
  }
}

/// Каталог послуг: заголовок → пошук → картки категорій із рядками.
class ServicesSkeleton extends StatelessWidget {
  const ServicesSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final k = context.kavio;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 120),
      children: [
        const Row(
          children: [
            ZBone(width: 132, height: 24, radius: 8),
            Spacer(),
            ZBone(width: 34, height: 34, radius: 11),
          ],
        ),
        const SizedBox(height: 14),
        Container(
          height: 42,
          decoration: BoxDecoration(
            color: k.surface2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: k.line),
          ),
        ),
        const SizedBox(height: 16),
        for (final rows in const [3, 2]) ...[
          const Padding(
            padding: EdgeInsets.only(left: 2, bottom: 10),
            child: Row(
              children: [
                ZBone(width: 70, height: 10),
                Spacer(),
                ZBone(width: 62, height: 10),
              ],
            ),
          ),
          ZCard(
            padding: const EdgeInsets.all(4),
            child: Column(
              children: [
                for (var i = 0; i < rows; i++)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 13),
                    decoration: BoxDecoration(
                      border: i == 0
                          ? null
                          : Border(top: BorderSide(color: k.line)),
                    ),
                    child: const Row(
                      children: [
                        ZBone(width: 10, height: 10, radius: 4),
                        SizedBox(width: 12),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            ZBone(width: 138, height: 11),
                            SizedBox(height: 7),
                            ZBone(width: 56, height: 9),
                          ],
                        ),
                        Spacer(),
                        ZBone(width: 52, height: 12),
                      ],
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
      ],
    );
  }
}

/// Картка клієнта: аватар → теги → швидкі дії → LTV → секції.
class ClientDetailSkeleton extends StatelessWidget {
  const ClientDetailSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 120),
      children: [
        const Center(child: ZBone.circle(84)),
        const SizedBox(height: 14),
        const Center(child: ZBone(width: 186, height: 22, radius: 8)),
        const SizedBox(height: 10),
        const Center(child: ZBone(width: 138, height: 11)),
        const SizedBox(height: 18),
        Row(
          children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              const Expanded(child: ZBone(height: 64, radius: 16)),
            ],
          ],
        ),
        const SizedBox(height: 16),
        Container(
          decoration: FX.hero(radius: 24),
          padding: const EdgeInsets.all(18),
          child: const Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ZBone(width: 108, height: 10),
              SizedBox(height: 10),
              ZBone(width: 164, height: 26, radius: 8),
              SizedBox(height: 10),
              ZBone(width: 132, height: 11),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const ZBone(width: 118, height: 11),
        const SizedBox(height: 10),
        ZCard(
          child: Column(
            children: [
              for (var i = 0; i < 3; i++) ...[
                if (i > 0) const SizedBox(height: 14),
                const Row(
                  children: [
                    ZBone(width: 10, height: 10, radius: 4),
                    SizedBox(width: 12),
                    ZBone(width: 128, height: 11),
                    Spacer(),
                    ZBone(width: 34, height: 11),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
