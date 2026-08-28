import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/services/subscriptions/entitlements.dart';
import '../core/time/demo_clock.dart';
import '../domain/models.dart';
import '../domain/repositories.dart';
import '../features/create/schedule_picker.dart';
import 'db/database.dart';
import 'repositories/drift_repositories.dart';

/// Поточний тариф користувача (демо: Pro). У проді — з SubscriptionService.
final currentPlanProvider = Provider<Plan>((ref) => Plan.pro);

/// Riverpod-проводка. Экраны читают провайдеры, а не БД напрямую.
/// Drift-потоки делают всё реактивным и offline-first.

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  // Сид демо-данных при первом запуске (fire-and-forget; потоки обновятся).
  // ignore: discarded_futures
  db.ensureSeeded();
  ref.onDispose(db.close);
  return db;
});

final clientsRepositoryProvider = Provider<ClientsRepository>(
    (ref) => DriftClientsRepository(ref.watch(databaseProvider)));
final servicesRepositoryProvider = Provider<ServicesRepository>(
    (ref) => DriftServicesRepository(ref.watch(databaseProvider)));
final appointmentsRepositoryProvider = Provider<AppointmentsRepository>(
    (ref) => DriftAppointmentsRepository(ref.watch(databaseProvider)));
final workspaceRepositoryProvider = Provider<WorkspaceRepository>(
    (ref) => DriftWorkspaceRepository(ref.watch(databaseProvider)));
final scheduleRepositoryProvider = Provider<ScheduleRepository>(
    (ref) => DriftScheduleRepository(ref.watch(databaseProvider)));

/// Розклад майстра. Поки не завантажився — типовий тиждень, щоб екрани не
/// чекали й не показували порожній календар.
final scheduleProvider = StreamProvider<Schedule>(
    (ref) => ref.watch(scheduleRepositoryProvider).watch());

Schedule scheduleOrFallback(WidgetRef ref) =>
    ref.watch(scheduleProvider).value ?? Schedule.fallback;

/// Все клиенты (реактивно из БД).
final clientsProvider = StreamProvider<List<Client>>(
    (ref) => ref.watch(clientsRepositoryProvider).watchAll());

/// Один клиент по id (из общего потока — мгновенно, без отдельного запроса).
final clientByIdProvider = Provider.family<Client?, String>((ref, id) {
  final list = ref.watch(clientsProvider).value ?? const <Client>[];
  for (final c in list) {
    if (c.id == id) return c;
  }
  return null;
});

/// Все записи клиента (история/метрики карточки).
final clientAppointmentsProvider =
    StreamProvider.family<List<Appointment>, String>((ref, id) =>
        ref.watch(appointmentsRepositoryProvider).watchForClient(id));

/// Каталог услуг (реактивно из БД).
final servicesProvider = StreamProvider<List<Service>>(
    (ref) => ref.watch(servicesRepositoryProvider).watchAll());

/// Выбранный день календаря.
final selectedDayProvider = StateProvider<DateTime>((ref) => DateTime.now());

/// Записи выбранного дня (реактивно из БД).
final dayAppointmentsProvider = StreamProvider<List<Appointment>>((ref) {
  final day = ref.watch(selectedDayProvider);
  return ref.watch(appointmentsRepositoryProvider).watchDay(day);
});

/// Записи в диапазоне (Неделя/Месяц). Ключ-запись обеспечивает кэш по диапазону:
/// одинаковый [start, end) переиспользует поток без повторного запроса.
typedef DateRange = ({DateTime start, DateTime end});

final rangeAppointmentsProvider =
    StreamProvider.family<List<Appointment>, DateRange>((ref, range) {
  return ref
      .watch(appointmentsRepositoryProvider)
      .watchRange(range.start, range.end);
});

/// Дневная сводка для экранов «Сегодня»/«Обзор».
@immutable
class DaySummary {
  const DaySummary(
      {required this.revenue, required this.visits, required this.load});
  final int revenue;
  final int visits;
  final int load;
}

final daySummaryProvider = Provider<DaySummary>((ref) {
  final appts =
      ref.watch(dayAppointmentsProvider).value ?? const <Appointment>[];
  final revenue = appts
      .where((a) =>
          a.status == AppointmentStatus.completed ||
          a.status == AppointmentStatus.confirmed)
      .fold<int>(0, (sum, a) => sum + a.service.price);
  final load =
      appts.isEmpty ? 0 : ((appts.length / 8) * 100).clamp(0, 100).round();
  return DaySummary(revenue: revenue, visits: appts.length, load: load);
});

/// Клієнти, які давно не приходили: останній візит понад [kLapsedDays] днів
/// тому або візитів не було зовсім. Раніше це число було зашите (завжди «3»).
const int kLapsedDays = 45;

final lastVisitsProvider = StreamProvider<Map<String, DateTime>>(
    (ref) => ref.watch(databaseProvider).watchLastVisits());

final lapsedClientsProvider = Provider<List<Client>>((ref) {
  final clients = ref.watch(clientsProvider).value ?? const <Client>[];
  final last =
      ref.watch(lastVisitsProvider).value ?? const <String, DateTime>{};
  final now = demoNow();
  return [
    for (final c in clients)
      if (now.difference(last[c.id] ?? DateTime(2000)).inDays > kLapsedDays) c,
  ];
});

/// Дані головного екрана «Сьогодні»: зароблено, кількість, наступний клієнт,
/// вільні вікна, інсайт повернення.
@immutable
class DashboardData {
  const DashboardData({
    required this.revenue,
    required this.visits,
    required this.freeWindows,
    required this.next,
    required this.minutesToNext,
    required this.lapsedCount,
    required this.busyUntil,
  });
  final int revenue; // зароблено (завершені), у мін. одиницях
  final int visits; // усього записів на день
  final List<DateTime> freeWindows; // вільні початки в робочих годинах
  final Appointment? next; // найближчий майбутній запис
  final int minutesToNext; // хвилин до наступного
  final int lapsedCount; // клієнти, що давно не були
  final DateTime? busyUntil; // кінець останнього живого запису дня
}

final dashboardProvider = Provider<DashboardData>((ref) {
  final appts =
      ref.watch(dayAppointmentsProvider).value ?? const <Appointment>[];
  final now = demoNow();

  final revenue = appts
      .where((a) => a.status == AppointmentStatus.completed)
      .fold<int>(0, (s, a) => s + a.service.price);

  Appointment? next;
  for (final a in appts) {
    if (a.start.isAfter(now) &&
        a.status != AppointmentStatus.cancelled &&
        a.status != AppointmentStatus.noShow) {
      if (next == null || a.start.isBefore(next.start)) next = a;
    }
  }
  final minutesToNext =
      next == null ? 0 : next.start.difference(now).inMinutes.clamp(0, 999);

  // Вільні вікна: гепи ≥40 хв від «зараз» до кінця робочого дня (20:00).
  final dayEnd = DateTime(now.year, now.month, now.day, 20);
  final busy = appts
      .where(
          (a) => a.status != AppointmentStatus.cancelled && a.end.isAfter(now))
      .map((a) => (a.start, a.end))
      .toList()
    ..sort((x, y) => x.$1.compareTo(y.$1));
  final windows = <DateTime>[];
  var cursor = now;
  for (final b in busy) {
    if (b.$1.isAfter(cursor) && b.$1.difference(cursor).inMinutes >= 40) {
      windows.add(_ceilTo15(cursor));
    }
    if (b.$2.isAfter(cursor)) cursor = b.$2;
  }
  if (cursor.isBefore(dayEnd) && dayEnd.difference(cursor).inMinutes >= 40) {
    windows.add(_ceilTo15(cursor));
  }

  DateTime? busyUntil;
  for (final a in appts.where((a) => a.isActive)) {
    if (busyUntil == null || a.end.isAfter(busyUntil)) busyUntil = a.end;
  }

  return DashboardData(
    revenue: revenue,
    busyUntil: busyUntil,
    visits: appts.length,
    freeWindows: windows.take(3).toList(),
    next: next,
    minutesToNext: minutesToNext,
    lapsedCount: ref.watch(lapsedClientsProvider).length,
  );
});

DateTime _ceilTo15(DateTime t) {
  final m = t.minute;
  final add = (15 - (m % 15)) % 15;
  final r = t.add(Duration(minutes: add == 0 ? 15 : add));
  return DateTime(r.year, r.month, r.day, r.hour, r.minute);
}

/// Кількість візитів по клієнтах — щоб відрізнити новачка від постійного.
final visitCountsProvider = StreamProvider<Map<String, int>>(
    (ref) => ref.watch(databaseProvider).watchVisitCounts());

/// Підсумок дня. Усе рахується з бази: раніше на цьому екрані були намальовані
/// «▲ 12%», «4.9★» і «завтра 5 записів», однакові щовечора.
@immutable
class RecapData {
  const RecapData({
    required this.revenue,
    required this.visits,
    required this.newClients,
    required this.busyMinutes,
    required this.deltaPercent,
    required this.tomorrowCount,
    required this.tomorrowFirst,
  });

  final int revenue; // зароблено за завершеними візитами
  final int visits; // скільки клієнтів прийшло
  final int newClients; // з них уперше
  final int busyMinutes; // скільки часу в кріслі
  final int?
      deltaPercent; // проти попереднього робочого дня; null — немає з чим
  final int tomorrowCount; // записів на завтра
  final DateTime? tomorrowFirst; // о котрій завтра починається день
}

final recapProvider = Provider<RecapData>((ref) {
  final today = demoToday();
  final tomorrow = today.add(const Duration(days: 1));
  // Два тижні назад — вистачає, щоб знайти попередній робочий день.
  final history = ref
          .watch(rangeAppointmentsProvider((
            start: today.subtract(const Duration(days: 14)),
            end: tomorrow.add(const Duration(days: 1)),
          )))
          .value ??
      const <Appointment>[];
  final counts = ref.watch(visitCountsProvider).value ?? const <String, int>{};

  bool sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  final todayDone = history
      .where((a) => sameDay(a.start, today))
      .where((a) => a.status == AppointmentStatus.completed)
      .toList();
  final todayLive =
      history.where((a) => sameDay(a.start, today) && a.isActive).toList();

  final revenue = todayDone.fold<int>(0, (s, a) => s + a.service.price);
  final busy = todayDone.fold<int>(0, (s, a) => s + a.service.durationMinutes);
  final newClients =
      todayDone.where((a) => (counts[a.client.id] ?? 1) <= 1).length;

  // Попередній день, коли взагалі були завершені візити.
  int? delta;
  for (var back = 1; back <= 14; back++) {
    final day = today.subtract(Duration(days: back));
    final done = history
        .where((a) =>
            sameDay(a.start, day) && a.status == AppointmentStatus.completed)
        .toList();
    if (done.isEmpty) continue;
    final prev = done.fold<int>(0, (s, a) => s + a.service.price);
    if (prev > 0) delta = (((revenue - prev) / prev) * 100).round();
    break;
  }

  final tomorrowList = history
      .where((a) => sameDay(a.start, tomorrow) && a.isActive)
      .toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  return RecapData(
    revenue: revenue,
    visits: todayLive.length,
    newClients: newClients,
    busyMinutes: busy,
    deltaPercent: delta,
    tomorrowCount: tomorrowList.length,
    tomorrowFirst: tomorrowList.isEmpty ? null : tomorrowList.first.start,
  );
});

/// Історія візитів по клієнтах за півроку — база для «ритму» клієнта.
final clientHistoryProvider = Provider<Map<String, List<Appointment>>>((ref) {
  final today = demoToday();
  final list = ref
          .watch(rangeAppointmentsProvider((
            start: today.subtract(const Duration(days: 180)),
            end: today.add(const Duration(days: 1)),
          )))
          .value ??
      const <Appointment>[];
  final byClient = <String, List<Appointment>>{};
  for (final a in list) {
    if (!a.isActive) continue;
    byClient.putIfAbsent(a.client.id, () => []).add(a);
  }
  for (final v in byClient.values) {
    v.sort((a, b) => a.start.compareTo(b.start));
  }
  return byClient;
});

/// Ритм клієнта: скільки днів між візитами зазвичай. Медіана, а не середнє —
/// один випадковий пропуск не має зсувати оцінку. null, якщо візит був один.
int? clientCadenceDays(List<Appointment> visits) {
  if (visits.length < 2) return null;
  final gaps = <int>[];
  for (var i = 1; i < visits.length; i++) {
    final d = visits[i].start.difference(visits[i - 1].start).inDays;
    if (d > 0) gaps.add(d);
  }
  if (gaps.isEmpty) return null;
  gaps.sort();
  return gaps[gaps.length ~/ 2].clamp(3, 120);
}

/// Кого запросити у вільне вікно.
@immutable
class GapCandidate {
  const GapCandidate({
    required this.client,
    required this.service,
    required this.daysSince,
    required this.cadenceDays,
    required this.overdueDays,
  });

  final Client client;
  final Service service; // улюблена послуга клієнта
  final int daysSince; // скільки днів не був
  final int? cadenceDays; // як часто зазвичай ходить
  final int overdueDays; // на скільки прострочив свій ритм
}

/// Вільні вікна сьогодні + кандидати, кого туди покликати.
///
/// Раніше цей екран показував вигадану Марію з «92% прийде». Тепер: реальні
/// вікна дня, реальні клієнти, і замість вигаданого відсотка — факти
/// («ходить кожні 3 тижні · не була 24 дні»).
final smartGapsProvider = Provider<List<(DateTime, GapCandidate)>>((ref) {
  final windows = ref.watch(dashboardProvider).freeWindows;
  if (windows.isEmpty) return const [];

  final history = ref.watch(clientHistoryProvider);
  final now = demoNow();

  final candidates = <GapCandidate>[];
  for (final entry in history.entries) {
    final visits = entry.value;
    if (visits.isEmpty) continue;
    final last = visits.last;
    final daysSince = now.difference(last.start).inDays;
    if (daysSince <= 0) continue; // сьогодні вже був

    final cadence = clientCadenceDays(visits);
    final overdue = cadence == null ? daysSince - 30 : daysSince - cadence;
    if (overdue < 0) continue; // ще рано турбувати

    // Улюблена послуга — найчастіша в історії.
    final freq = <String, int>{};
    for (final v in visits) {
      freq[v.service.id] = (freq[v.service.id] ?? 0) + 1;
    }
    final favId = (freq.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value)))
        .first
        .key;
    final fav = visits.lastWhere((v) => v.service.id == favId).service;

    candidates.add(GapCandidate(
      client: last.client,
      service: fav,
      daysSince: daysSince,
      cadenceDays: cadence,
      overdueDays: overdue,
    ));
  }

  candidates.sort((a, b) => b.overdueDays.compareTo(a.overdueDays));
  return [
    for (var i = 0; i < windows.length && i < candidates.length; i++)
      (windows[i], candidates[i]),
  ];
});

/// Пропозиція «магічного перезапису»: коли записати клієнта наступного разу.
@immutable
class RebookSuggestion {
  const RebookSuggestion({
    required this.appointment,
    required this.cadenceDays,
    required this.slot,
  });

  final Appointment appointment; // щойно завершений візит
  final int? cadenceDays; // ритм клієнта; null — це перший візит
  final DateTime? slot; // найближче вільне вікно в цьому ритмі
}

/// Останній завершений сьогодні візит — на нього спирається екран перезапису,
/// коли його відкрили з меню, а не одразу після оплати.
final lastCompletedTodayProvider = Provider<Appointment?>((ref) {
  final list =
      ref.watch(dayAppointmentsProvider).value ?? const <Appointment>[];
  final done = list
      .where((a) => a.status == AppointmentStatus.completed)
      .toList()
    ..sort((a, b) => b.start.compareTo(a.start));
  return done.isEmpty ? null : done.first;
});

/// Порахувати пропозицію для конкретного візиту: ритм клієнта + перше вільне
/// вікно приблизно через стільки ж днів, у той самий час доби.
final rebookSuggestionProvider =
    Provider.family<RebookSuggestion?, String?>((ref, appointmentId) {
  final today =
      ref.watch(dayAppointmentsProvider).value ?? const <Appointment>[];
  final base = appointmentId == null
      ? ref.watch(lastCompletedTodayProvider)
      : today.where((a) => a.id == appointmentId).firstOrNull ??
          ref.watch(lastCompletedTodayProvider);
  if (base == null) return null;

  final history = ref.watch(clientHistoryProvider)[base.client.id] ?? const [];
  final cadence = clientCadenceDays(history);
  final schedule = ref.watch(scheduleProvider).value ?? Schedule.fallback;

  // Шукаємо вікно навколо очікуваної дати: спершу в сам день, далі вперед.
  final target = base.start.add(Duration(days: cadence ?? 21));
  final from = DateTime(target.year, target.month, target.day);
  final upcoming = ref
          .watch(rangeAppointmentsProvider(
              (start: from, end: from.add(const Duration(days: 14)))))
          .value ??
      const <Appointment>[];

  DateTime? best;
  for (var d = 0; d < 14 && best == null; d++) {
    final day = from.add(Duration(days: d));
    final dayAppts = upcoming
        .where((a) =>
            a.start.year == day.year &&
            a.start.month == day.month &&
            a.start.day == day.day)
        .toList();
    final slots = freeSlotsFor(
      dayAppointments: dayAppts,
      day: day,
      durationMinutes: base.service.durationMinutes,
      schedule: schedule,
    );
    if (slots.isEmpty) continue;
    // Той самий час доби, що й зараз — клієнту звично.
    final wanted = base.start.hour * 60 + base.start.minute;
    slots.sort((a, b) {
      final da = ((a.hour * 60 + a.minute) - wanted).abs();
      final db = ((b.hour * 60 + b.minute) - wanted).abs();
      return da.compareTo(db);
    });
    best = slots.first;
  }

  return RebookSuggestion(appointment: base, cadenceDays: cadence, slot: best);
});
