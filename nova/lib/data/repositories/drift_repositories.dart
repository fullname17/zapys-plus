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

  @override
  Future<void> setDeposit(String id, int minor) =>
      _db.setAppointmentDeposit(id, minor);

  @override
  Future<void> setDetails(
          String id, String? note, Map<String, String> params) =>
      _db.setAppointmentDetails(id, note, params);
}

class DriftPhotosRepository implements PhotosRepository {
  DriftPhotosRepository(this._db);
  final AppDatabase _db;

  @override
  Stream<List<VisitPhoto>> watchForAppointment(String appointmentId) =>
      _db.watchAppointmentPhotos(appointmentId);

  @override
  Stream<List<VisitPhoto>> watchForClient(String clientId) =>
      _db.watchClientPhotos(clientId);

  @override
  Future<void> add(VisitPhoto photo) => _db.addPhoto(photo);

  @override
  Future<void> delete(String id) => _db.deletePhoto(id);
}

class DriftBackupRepository implements BackupRepository {
  DriftBackupRepository(this._db);
  final AppDatabase _db;

  @override
  Future<Map<String, dynamic>> exportAll() => _db.exportAll();
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
    List<(String, String, int, int, int?)> services,
  ) =>
      _db.applyIndustryTemplate(industryId, services);
}
