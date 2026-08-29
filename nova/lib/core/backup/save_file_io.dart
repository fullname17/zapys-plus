import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Зберегти резервну копію файлом на пристрої.
///
/// Повертає шлях, за яким лежить файл, — його показуємо майстру, щоб він знав,
/// що саме передавати чи куди дивитися.
Future<String> saveBackupFile(String fileName, String contents) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$fileName');
  await file.writeAsString(contents, encoding: utf8, flush: true);
  return file.path;
}
