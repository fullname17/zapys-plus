import '../../domain/models.dart';
import '../../domain/repositories.dart';
import '../db/database.dart';

/// Реализация репозиториев поверх Drift. Тонкие обёртки: вся работа с БД —
/// в AppDatabase, здесь только контракт для UI.

class DriftClientsRepository implements ClientsRepository {
  DriftClientsRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Client>> watchAll() => _db.watchClients();

  @override
  Future<void> add(Client client) => _db.addClient(client);

  @override
  Future<void> update(Client client) => _db.updateClient(client);

  @override
  Future<void> delete(String id) => _db.deleteClient(id);
}

class DriftServicesRepository implements ServicesRepository {
  DriftServicesRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Service>> watchAll() => _db.watchServices();

  @override
  Future<void> add(Service service) => _db.addService(service);

  @override
  Future<void> update(Service service) => _db.updateService(service);

  @override
  Future<void> archive(String id) => _db.archiveService(id);
}

class DriftAppointmentsRepository implements AppointmentsRepository {
  DriftAppointmentsRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<Appointment>> watchDay(DateTime day) => _db.watchDay(day);

  @override
  Stream<List<Appointment>> watchRange(DateTime start, DateTime end) =>
      _db.watchRange(start, end);

  @override
  Stream<List<Appointment>> watchForClient(String clientId) =>
      _db.watchClientAppointments(clientId);

  @override
  Future<void> add(Appointment appointment) => _db.addAppointment(appointment);

  @override
  Future<void> update(Appointment appointment) =>
      _db.updateAppointment(appointment);

  @override
  Future<void> updateStatus(String id, AppointmentStatus status) =>
      _db.setAppointmentStatus(id, status);

  @override
  Future<void> move(String id, DateTime newStart) =>
      _db.moveAppointment(id, newStart);

  @override
  Future<void> delete(String id) => _db.deleteAppointment(id);
}

class DriftScheduleRepository implements ScheduleRepository {
  DriftScheduleRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<Schedule> watch() => _db.watchSchedule();

  @override
  Future<void> save(Schedule schedule) => _db.saveSchedule(schedule);
}

class DriftWorkspaceRepository implements WorkspaceRepository {
  DriftWorkspaceRepository(this._db);
  final AppDatabase _db;

  @override
  Future<void> applyIndustry(
    String industryId,
    List<(String, String, int, int)> services,
  ) =>
      _db.applyIndustryTemplate(industryId, services);
}
