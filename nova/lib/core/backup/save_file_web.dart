import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Зберегти резервну копію файлом у браузері.
///
/// Data-URL у верхньому вікні Chrome блокує, тож робимо Blob і клікаємо
/// прихованим посиланням із `download` — це звичайне завантаження файлу.
Future<String> saveBackupFile(String fileName, String contents) async {
  final blob = web.Blob(
    [contents.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json;charset=utf-8'),
  );
  final url = web.URL.createObjectURL(blob);
  final anchor = web.document.createElement('a') as web.HTMLAnchorElement
    ..href = url
    ..download = fileName
    ..style.display = 'none';
  web.document.body!.appendChild(anchor);
  anchor.click();
  anchor.remove();
  // Посилання на Blob живе до перезавантаження сторінки — прибираємо самі.
  web.URL.revokeObjectURL(url);
  return fileName;
}
