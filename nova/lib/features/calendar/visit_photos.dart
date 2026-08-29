import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/localization/app_text.dart';
import '../../data/providers.dart';
import '../../design/theme.dart';
import '../../domain/models.dart';
import '../../ui/format.dart';
import '../../ui/kavio_sheet.dart';
import '../../ui/z.dart';

/// Фото робіт.
///
/// «До / після» — головний доказ роботи майстра: його показують клієнту,
/// викладають у соцмережі й звіряються з ним наступного разу. Досі знімки
/// губилися в галереї телефона серед тисяч інших.
///
/// Знімок стискається при виборі й лягає в базу як data-URI: застосунок
/// офлайн-first, хмарного сховища ще немає.
const int _kMaxSide = 1400;
const int _kQuality = 75;

/// Скільки байтів займе знімок після base64 — щоб попередити, коли база
/// починає розпухати.
int photoBytes(String dataUri) {
  final comma = dataUri.indexOf(',');
  if (comma < 0) return 0;
  return ((dataUri.length - comma - 1) * 3) ~/ 4;
}

/// Стрічка фото візиту з кнопкою «додати».
class VisitPhotoStrip extends ConsumerWidget {
  const VisitPhotoStrip({super.key, required this.appointment});
  final Appointment appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final k = context.kavio;
    final photos = ref.watch(appointmentPhotosProvider(appointment.id)).value ??
        const <VisitPhoto>[];

    return SizedBox(
      height: 84,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        children: [
          Semantics(
            button: true,
            label: t('Додати фото роботи'),
            child: GestureDetector(
              onTap: () => addVisitPhoto(context, ref, appointment),
              child: Container(
                width: 84,
                decoration: BoxDecoration(
                  color: k.surface2,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: k.line),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_a_photo_outlined, size: 20, color: k.accent),
                    const SizedBox(height: 5),
                    Text(t('Фото'),
                        style:
                            AppTypography.label(k.ink3).copyWith(fontSize: 11)),
                  ],
                ),
              ),
            ),
          ),
          for (final p in photos) ...[
            const SizedBox(width: 8),
            _PhotoTile(photo: p),
          ],
        ],
      ),
    );
  }
}

class _PhotoTile extends StatelessWidget {
  const _PhotoTile({required this.photo});
  final VisitPhoto photo;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      image: true,
      label:
          tp('Фото роботи від {date}', {'date': Fmt.dayMonth(photo.createdAt)}),
      child: GestureDetector(
        onTap: () {
          zTap();
          showPhotoViewer(context, photo);
        },
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 84,
            height: 84,
            child: photoImage(photo, fit: BoxFit.cover),
          ),
        ),
      ),
    );
  }
}

/// Картинка з data-URI. Виносимо в одне місце: декодування base64 однакове
/// скрізь, а зіпсований рядок не має ронити екран.
Widget photoImage(VisitPhoto photo, {BoxFit fit = BoxFit.cover}) {
  final comma = photo.dataUri.indexOf(',');
  if (comma < 0) return const SizedBox.shrink();
  try {
    final bytes = base64Decode(photo.dataUri.substring(comma + 1));
    return Image.memory(bytes, fit: fit, gaplessPlayback: true);
  } on FormatException {
    return const SizedBox.shrink();
  }
}

/// Повноекранний перегляд із можливістю видалити.
Future<void> showPhotoViewer(BuildContext context, VisitPhoto photo) {
  return showDialog<void>(
    context: context,
    barrierColor: Colors.black87,
    builder: (dialogContext) => Consumer(
      builder: (context, ref, _) {
        final k = context.kavio;
        return Stack(
          children: [
            GestureDetector(
              onTap: () => Navigator.of(dialogContext).pop(),
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: photoImage(photo, fit: BoxFit.contain),
                  ),
                ),
              ),
            ),
            Positioned(
              right: 20,
              bottom: 36,
              child: Semantics(
                button: true,
                label: t('Видалити фото'),
                child: GestureDetector(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    final toast = zToaster(context);
                    final navigator = Navigator.of(dialogContext);
                    final repo = ref.read(photosRepositoryProvider);
                    await repo.delete(photo.id);
                    navigator.pop();
                    toast(
                      t('Фото видалено'),
                      actionLabel: t('Повернути'),
                      onAction: () => repo.add(photo),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: k.surface2,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: k.line),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.delete_outline, size: 17, color: k.danger),
                        const SizedBox(width: 8),
                        Text(t('Видалити'),
                            style: AppTypography.label(k.danger).copyWith(
                                fontSize: 13, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// Обрати джерело й додати знімок до візиту.
Future<void> addVisitPhoto(
    BuildContext context, WidgetRef ref, Appointment a) async {
  zTap();
  // На вебі «камера» відкриває той самий діалог вибору файлу, тож питати про
  // джерело там нема сенсу.
  final source = kIsWeb
      ? ImageSource.gallery
      : await showKavioSheet<ImageSource>(context, builder: (sheetContext) {
          return KavioSheet(
            title: t('Фото роботи'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ZButton(
                  label: t('Зробити знімок'),
                  icon: Icons.photo_camera_outlined,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.camera),
                ),
                const SizedBox(height: 10),
                ZButtonSecondary(
                  label: t('Обрати з галереї'),
                  expand: true,
                  onTap: () =>
                      Navigator.of(sheetContext).pop(ImageSource.gallery),
                ),
                const SizedBox(height: 4),
              ],
            ),
          );
        });
  if (source == null) return;
  if (!context.mounted) return;

  final toast = zToaster(context);
  try {
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: _kMaxSide.toDouble(),
      maxHeight: _kMaxSide.toDouble(),
      imageQuality: _kQuality,
    );
    if (file == null) return;

    final bytes = await file.readAsBytes();
    final mime = file.mimeType ?? _mimeFor(file.name);
    final photo = VisitPhoto(
      id: 'ph_${DateTime.now().microsecondsSinceEpoch}',
      appointmentId: a.id,
      clientId: a.client.id,
      dataUri: 'data:$mime;base64,${base64Encode(bytes)}',
      createdAt: DateTime.now(),
    );
    await ref.read(photosRepositoryProvider).add(photo);
    HapticFeedback.lightImpact();
  } on PlatformException {
    // Немає доступу до камери чи галереї — це не помилка застосунку.
    toast(t('Немає доступу до фото'));
  }
}

String _mimeFor(String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.heic')) return 'image/heic';
  return 'image/jpeg';
}
