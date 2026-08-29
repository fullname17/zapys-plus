import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/time/demo_clock.dart';
import '../domain/models.dart';
import 'providers.dart';

/// Період аналітики. Кожен знає власні межі, попередній період для порівняння
/// і на скільки кошиків різати графік.
enum AnalyticsPeriod { today, week, month, year }

extension AnalyticsPeriodX on AnalyticsPeriod {
  /// Скільки днів охоплює період.
  int get days => switch (this) {
        AnalyticsPeriod.today => 1,
        AnalyticsPeriod.week => 7,
        AnalyticsPeriod.month => 30,
        AnalyticsPeriod.year => 365,
      };

  /// Скільки точок на графіку. Для дня — по годинах робочого часу.
  int get buckets => switch (this) {
        AnalyticsPeriod.today => 8,
        AnalyticsPeriod.week => 7,
        AnalyticsPeriod.month => 10,
        AnalyticsPeriod.year => 12,
      };
}

/// Готові числа для екрана «Аналітика». Раніше всі графіки й KPI були зашиті
/// масивами й не змінювалися ніколи — тепер це справжні записи майстра.
@immutable
class AnalyticsData {
  const AnalyticsData({
    required this.revenue,
    required this.prevRevenue,
    required this.visits,
    required this.prevVisits,
    required this.avgCheck,
    required this.prevAvgCheck,
    required this.cancelPercent,
    required this.prevCancelPercent,
    required this.series,
    required this.prevSeries,
    required this.heatmap,
    required this.loadPercent,
    required this.topServices,
  });

  final int revenue, prevRevenue;
  final int visits, prevVisits;
  final int avgCheck, prevAvgCheck;
  final int cancelPercent, prevCancelPercent;

  /// Нормовані 0..1 значення для графіка (поточний і попередній період).
  final List<double> series, prevSeries;

  /// Теплова карта: 5 смуг часу × 7 днів тижня, нормовано 0..1.
  final List<List<double>> heatmap;

  /// Завантаженість періоду: зайняті хвилини проти робочих.
  final int loadPercent;

  /// Топ послуг: назва, виручка, частка від максимуму.
  final List<(String, int, double)> topServices;

  /// Приріст у відсотках; null — попередній період порожній, порівнювати нема з чим.
  int? get deltaPercent => prevRevenue <= 0
      ? null
      : (((revenue - prevRevenue) / prevRevenue) * 100).round();

  int? get avgCheckDelta => prevAvgCheck <= 0
      ? null
      : (((avgCheck - prevAvgCheck) / prevAvgCheck) * 100).round();

  int? get visitsDelta => prevVisits <= 0
      ? null
      : (((visits - prevVisits) / prevVisits) * 100).round();

  int get cancelDelta => cancelPercent - prevCancelPercent;
}

/// Смуги часу теплової карти — ті самі підписи, що на екрані.
const List<int> kHeatmapHours = [10, 12, 14, 16, 18];

final analyticsProvider =
    Provider.family<AnalyticsData, AnalyticsPeriod>((ref, period) {
  final today = demoToday();
  // Період закінчується завтра опівночі, щоб «сьогодні» рахувалося цілком.
  final end = today.add(const Duration(days: 1));
  final start = end.subtract(Duration(days: period.days));
  final prevStart = start.subtract(Duration(days: period.days));

  final all = ref
          .watch(rangeAppointmentsProvider((start: prevStart, end: end)))
          .value ??
      const <Appointment>[];

  bool inRange(Appointment a, DateTime from, DateTime to) =>
      !a.start.isBefore(from) && a.start.isBefore(to);

  final cur = all.where((a) => inRange(a, start, end)).toList();
  final prev = all.where((a) => inRange(a, prevStart, start)).toList();

  int revenueOf(List<Appointment> list) => list
      .where((a) => a.status == AppointmentStatus.completed)
      .fold(0, (s, a) => s + a.service.price);

  int visitsOf(List<Appointment> list) => list.where((a) => a.isActive).length;

  int avgOf(List<Appointment> list) {
    final done = list.where((a) => a.status == AppointmentStatus.completed);
    if (done.isEmpty) return 0;
    return revenueOf(list) ~/ done.length;
  }

  int cancelOf(List<Appointment> list) {
    if (list.isEmpty) return 0;
    final lost = list
        .where((a) =>
            a.status == AppointmentStatus.cancelled ||
            a.status == AppointmentStatus.noShow)
        .length;
    return ((lost / list.length) * 100).round();
  }

  /// Виручка по кошиках періоду, нормована спільним максимумом — щоб дві лінії
  /// на графіку були порівнянні між собою.
  List<int> bucketsOf(List<Appointment> list, DateTime from, DateTime to) {
    final n = period.buckets;
    final out = List<int>.filled(n, 0);
    final span = to.difference(from).inMinutes;
    if (span <= 0) return out;
    for (final a in list) {
      if (a.status != AppointmentStatus.completed) continue;
      final offset = a.start.difference(from).inMinutes;
      final i = ((offset / span) * n).floor().clamp(0, n - 1);
      out[i] += a.service.price;
    }
    return out;
  }

  final curB = bucketsOf(cur, start, end);
  final prevB = bucketsOf(prev, prevStart, start);
  final peak = [...curB, ...prevB].fold<int>(0, (m, v) => v > m ? v : m);
  List<double> norm(List<int> b) =>
      peak == 0 ? b.map((_) => 0.0).toList() : b.map((v) => v / peak).toList();

  // Теплова карта: скільки часу зайнято в кожній смузі × дні тижня.
  final heat = [
    for (var band = 0; band < kHeatmapHours.length; band++)
      List<double>.filled(7, 0),
  ];
  var heatPeak = 0.0;
  for (final a in cur) {
    if (!a.isActive) continue;
    final band = kHeatmapHours.indexWhere((h) => a.start.hour < h + 2);
    final row = band < 0 ? kHeatmapHours.length - 1 : band;
    final col = a.start.weekday - 1;
    heat[row][col] += a.service.durationMinutes.toDouble();
    if (heat[row][col] > heatPeak) heatPeak = heat[row][col];
  }
  final heatmap = [
    for (final row in heat)
      [for (final v in row) heatPeak == 0 ? 0.0 : v / heatPeak],
  ];

  // Завантаженість: зайняті хвилини проти робочих у періоді.
  final schedule = ref.watch(scheduleProvider).value ?? Schedule.fallback;
  var workMinutes = 0;
  for (var d = 0; d < period.days; d++) {
    final day = schedule.forDate(start.add(Duration(days: d)));
    if (!day.isOpen) continue;
    workMinutes += day.closeMinutes - day.openMinutes;
    if (day.hasBreak) {
      workMinutes -= day.breakEndMinutes! - day.breakStartMinutes!;
    }
  }
  final busyMinutes = cur
      .where((a) => a.isActive)
      .fold<int>(0, (s, a) => s + a.service.durationMinutes);
  final load =
      workMinutes == 0 ? 0 : ((busyMinutes / workMinutes) * 100).round();

  // Топ послуг за виручкою.
  final byService = <String, (String, int)>{};
  for (final a in cur.where((a) => a.status == AppointmentStatus.completed)) {
    final e = byService[a.service.id];
    byService[a.service.id] = (a.service.name, (e?.$2 ?? 0) + a.service.price);
  }
  final top = byService.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
  final topPeak = top.isEmpty ? 0 : top.first.$2;
  final topServices = [
    for (final s in top.take(4))
      (s.$1, s.$2, topPeak == 0 ? 0.0 : s.$2 / topPeak),
  ];

  return AnalyticsData(
    revenue: revenueOf(cur),
    prevRevenue: revenueOf(prev),
    visits: visitsOf(cur),
    prevVisits: visitsOf(prev),
    avgCheck: avgOf(cur),
    prevAvgCheck: avgOf(prev),
    cancelPercent: cancelOf(cur),
    prevCancelPercent: cancelOf(prev),
    series: norm(curB),
    prevSeries: norm(prevB),
    heatmap: heatmap,
    loadPercent: load.clamp(0, 100),
    topServices: topServices,
  );
});

/// Скільки хвилин у періоді — для підпису «за 7 днів» тощо. Тримаємо поряд,
/// щоб екран не рахував дати сам.
String periodTitleKey(AnalyticsPeriod p) => switch (p) {
      AnalyticsPeriod.today => 'сьогодні',
      AnalyticsPeriod.week => 'за тиждень',
      AnalyticsPeriod.month => 'за місяць',
      AnalyticsPeriod.year => 'за рік',
    };

String prevPeriodKey(AnalyticsPeriod p) => switch (p) {
      AnalyticsPeriod.today => 'вчора',
      AnalyticsPeriod.week => 'попередній тиждень',
      AnalyticsPeriod.month => 'попередній місяць',
      AnalyticsPeriod.year => 'попередній рік',
    };
