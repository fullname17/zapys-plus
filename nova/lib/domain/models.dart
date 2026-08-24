import 'package:flutter/foundation.dart';

/// Доменные модели Kavio. Иммутабельные, с copyWith.
/// Appointment — центральный узел (клиент + мастер + услуга + время + статус).

enum AppointmentStatus {
  online,
  confirmed,
  pending,
  inProgress,
  completed,
  noShow,
  cancelled
}

extension AppointmentStatusX on AppointmentStatus {
  String get label => switch (this) {
        AppointmentStatus.online => 'онлайн',
        AppointmentStatus.confirmed => 'підтв.',
        AppointmentStatus.pending => 'чекаємо',
        AppointmentStatus.inProgress => 'триває',
        AppointmentStatus.completed => 'завершено',
        AppointmentStatus.noShow => 'не прийшов',
        AppointmentStatus.cancelled => 'скасовано',
      };
}

@immutable
class Client {
  const Client({
    required this.id,
    required this.name,
    required this.phone,
    this.visitsCount = 0,
    this.totalSpent = 0,
    this.note,
    this.tags = const [],
  });

  final String id;
  final String name;
  final String phone;
  final int visitsCount;
  final int totalSpent; // в минимальных единицах валюты
  final String? note;
  final List<String> tags;

  String get initials {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts[0].substring(0, 1) + parts[1].substring(0, 1)).toUpperCase();
  }

  Client copyWith(
          {int? visitsCount,
          int? totalSpent,
          String? note,
          List<String>? tags}) =>
      Client(
        id: id,
        name: name,
        phone: phone,
        visitsCount: visitsCount ?? this.visitsCount,
        totalSpent: totalSpent ?? this.totalSpent,
        note: note ?? this.note,
        tags: tags ?? this.tags,
      );
}

@immutable
class Service {
  const Service({
    required this.id,
    required this.name,
    required this.durationMinutes,
    required this.price,
    this.category,
  });

  final String id;
  final String name;
  final int durationMinutes;
  final int price;
  final String? category;
}

@immutable
class Staff {
  const Staff({required this.id, required this.name, this.role = 'Мастер'});
  final String id;
  final String name;
  final String role;
}

/// Универсальный ресурс: кабинет, кресло, авто, студия, печь, оборудование,
/// переговорная и т.д. Одна модель на все вертикали — запись может быть привязана
/// не только к сотруднику, но и к ресурсу.
@immutable
class Resource {
  const Resource({required this.id, required this.name, this.type = 'room'});
  final String id;
  final String name;
  final String type;
}

@immutable
class Appointment {
  const Appointment({
    required this.id,
    required this.client,
    required this.service,
    required this.start,
    required this.status,
    this.staff,
    this.resource,
  });

  final String id;
  final Client client;
  final Service service;
  final DateTime start;
  final AppointmentStatus status;
  final Staff? staff;
  final Resource? resource;

  DateTime get end => start.add(Duration(minutes: service.durationMinutes));

  Appointment copyWith({
    Client? client,
    Service? service,
    AppointmentStatus? status,
    DateTime? start,
    Staff? staff,
    Resource? resource,
  }) =>
      Appointment(
        id: id,
        client: client ?? this.client,
        service: service ?? this.service,
        start: start ?? this.start,
        status: status ?? this.status,
        staff: staff ?? this.staff,
        resource: resource ?? this.resource,
      );

  /// Запис «живий» — займає час у розкладі. Скасовані та неявки місце не
  /// тримають: вікно звільняється, підбір слотів їх не враховує.
  bool get isActive =>
      status != AppointmentStatus.cancelled &&
      status != AppointmentStatus.noShow;
}

/// Робочий день майстра. Час — у хвилинах від опівночі (600 = 10:00), щоб не
/// тягати DateTime там, де дата не має значення.
@immutable
class WorkingDay {
  const WorkingDay({
    required this.weekday,
    required this.isOpen,
    required this.openMinutes,
    required this.closeMinutes,
    this.breakStartMinutes,
    this.breakEndMinutes,
  });

  /// 1 = понеділок … 7 = неділя (як у DateTime.weekday).
  final int weekday;
  final bool isOpen;
  final int openMinutes;
  final int closeMinutes;
  final int? breakStartMinutes;
  final int? breakEndMinutes;

  bool get hasBreak =>
      breakStartMinutes != null &&
      breakEndMinutes != null &&
      breakEndMinutes! > breakStartMinutes!;

  WorkingDay copyWith({
    bool? isOpen,
    int? openMinutes,
    int? closeMinutes,
    int? breakStartMinutes,
    int? breakEndMinutes,
    bool clearBreak = false,
  }) =>
      WorkingDay(
        weekday: weekday,
        isOpen: isOpen ?? this.isOpen,
        openMinutes: openMinutes ?? this.openMinutes,
        closeMinutes: closeMinutes ?? this.closeMinutes,
        breakStartMinutes:
            clearBreak ? null : (breakStartMinutes ?? this.breakStartMinutes),
        breakEndMinutes:
            clearBreak ? null : (breakEndMinutes ?? this.breakEndMinutes),
      );
}

/// Тиждень майстра + крок сітки запису.
@immutable
class Schedule {
  const Schedule({required this.days, required this.slotStepMinutes});

  /// Рівно 7 днів, у порядку понеділок → неділя.
  final List<WorkingDay> days;
  final int slotStepMinutes;

  WorkingDay forDate(DateTime d) => days[d.weekday - 1];

  /// Типовий тиждень для першого запуску: пн–сб 10:00–20:00, неділя вихідна.
  static Schedule get fallback => Schedule(
        slotStepMinutes: 30,
        days: [
          for (var d = 1; d <= 7; d++)
            WorkingDay(
                weekday: d,
                isOpen: d != 7,
                openMinutes: 600,
                closeMinutes: 1200),
        ],
      );

  Schedule copyWith({List<WorkingDay>? days, int? slotStepMinutes}) => Schedule(
        days: days ?? this.days,
        slotStepMinutes: slotStepMinutes ?? this.slotStepMinutes,
      );
}
