import 'models.dart';

/// Абстракции доступа к данным. UI зависит только от них; реализация — Drift.
/// Потоки (`watch*`) отражают offline-first реактивность: изменение в БД
/// мгновенно обновляет все экраны.

abstract interface class ClientsRepository {
  Stream<List<Client>> watchAll();
  Future<void> add(Client client);
  Future<void> update(Client client);

  /// Видалення разом з історією візитів — картка зникає назавжди.
  Future<void> delete(String id);
}

abstract interface class ServicesRepository {
  Stream<List<Service>> watchAll();
  Future<void> add(Service service);
  Future<void> update(Service service);

  /// Приховати послугу з каталогу. М'яко: минулі записи на неї лишаються
  /// цілими, інакше з історії клієнта зникли б візити.
  Future<void> archive(String id);
}

/// Розклад майстра: години по днях тижня, вихідні, перерва, крок сітки.
abstract interface class ScheduleRepository {
  Stream<Schedule> watch();
  Future<void> save(Schedule schedule);
}

abstract interface class AppointmentsRepository {
  Stream<List<Appointment>> watchDay(DateTime day);

  /// Записи в полуоткрытом диапазоне [start, end) — для Недели/Месяца.
  Stream<List<Appointment>> watchRange(DateTime start, DateTime end);

  /// Все записи клиента (история карточки).
  Stream<List<Appointment>> watchForClient(String clientId);
  Future<void> add(Appointment appointment);

  /// Редагування: клієнт / послуга / час / статус одним записом.
  /// Ідентифікатор незмінний — запис лишається тим самим для історії й нагадувань.
  Future<void> update(Appointment appointment);

  Future<void> updateStatus(String id, AppointmentStatus status);

  /// Перенос (Drag & Drop): меняет время начала.
  Future<void> move(String id, DateTime newStart);
  Future<void> delete(String id);

  /// Позначити передоплату. Це не платіж: застосунок лише запам'ятовує суму,
  /// яку майстер уже отримав.
  Future<void> setDeposit(String id, int minor);

  /// Нотатка й параметри роботи (вигин, товщина, формула кольору тощо).
  Future<void> setDetails(String id, String? note, Map<String, String> params);
}

/// Фото робіт: галерея візиту й галерея клієнта.
abstract interface class PhotosRepository {
  Stream<List<VisitPhoto>> watchForAppointment(String appointmentId);
  Stream<List<VisitPhoto>> watchForClient(String clientId);
  Future<void> add(VisitPhoto photo);
  Future<void> delete(String id);
}

/// Резервна копія: уся база одним знімком для збереження у файл.
abstract interface class BackupRepository {
  Future<Map<String, dynamic>> exportAll();
}

/// Настройка рабочего пространства (онбординг): применение отраслевого шаблона.
abstract interface class WorkspaceRepository {
  /// [services]: (категорія, назва, тривалість_хв, ціна_мінор, повтор_днів).
  /// Повтор — через скільки днів послугу зазвичай роблять знову; null —
  /// послуга разова.
  Future<void> applyIndustry(
    String industryId,
    List<(String, String, int, int, int?)> services,
  );
}
