import '../boot_uri.dart';

/// Годинник застосунку.
///
/// У продукті це справжній час. Демо-режим (?demo=1) прив'язує «зараз» до
/// приємної денної точки — 14:20 — щоб знімки екранів у CI завжди виглядали
/// однаково: наступний клієнт за 25 хвилин, денні вільні вікна на місці.
/// Раніше демо-час був увімкнений завжди, і застосунок вважав, що зараз 14:20
/// навіть о дев'ятій ранку в майстра.
bool get _demoClock => bootParam('demo') == '1';

DateTime demoNow() {
  final n = DateTime.now();
  return _demoClock ? DateTime(n.year, n.month, n.day, 14, 20) : n;
}

/// Сьогоднішня опівніч (для прив'язки записів того ж дня).
DateTime demoToday() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}
