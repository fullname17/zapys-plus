/// Фрагмент URL, зафіксований у main() до старту роутера (go_router нормалізує
/// адресу й може прибрати query). Використовується для вибору режиму на знімках
/// екранів у CI (?view=week|month).
String bootFragment = '';

/// Параметр із зафіксованого фрагмента (`/calendar?view=week` → `view`).
/// Один вхід для всіх оверрайдів знімків, щоб екрани не парсили URL самі.
String? bootParam(String name) {
  final qi = bootFragment.indexOf('?');
  if (qi < 0) return null;
  return Uri.splitQueryString(bootFragment.substring(qi + 1))[name];
}
