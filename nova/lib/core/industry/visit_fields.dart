/// Параметри роботи, які майстер записує після візиту.
///
/// Це те, чого немає в жодній «загальній» CRM і через що майстри досі тримають
/// зошит: наступного разу треба згадати вигин і товщину вій, формулу кольору,
/// номер лаку, насадку машинки. Набір полів залежить від сфери — той самий
/// каталог, що дає послуги на онбордингу, дає й ці підказки.
///
/// Пресети — не обмеження: будь-яке поле можна заповнити своїм текстом.
library;

class VisitField {
  const VisitField(this.label, {this.presets = const []});

  /// Назва поля українською — вона ж ключ у збереженому JSON.
  final String label;

  /// Найчастіші значення в один дотик.
  final List<String> presets;
}

abstract final class VisitFields {
  /// Універсальний набір для сфер, де своїх параметрів немає.
  static const generic = [
    VisitField('Що робили'),
    VisitField('Матеріали'),
  ];

  static const _byIndustry = <String, List<VisitField>>{
    'lashes': [
      VisitField('Вигин', presets: ['C', 'CC', 'D', 'L', 'M']),
      VisitField('Товщина', presets: ['0.05', '0.07', '0.10', '0.15', '0.20']),
      VisitField('Довжина', presets: ['8–10', '9–11', '10–12', '11–13']),
      VisitField('Ефект',
          presets: ['Класика', '2D', '3D', 'Об’єм', 'Лисячий', 'Лялечка']),
    ],
    'brows': [
      VisitField('Форма', presets: ['Пряма', 'З вигином', 'Домком']),
      VisitField('Барвник', presets: ['Хна', 'Фарба']),
      VisitField('Витримка', presets: ['10 хв', '15 хв', '20 хв']),
      VisitField('Відтінок'),
    ],
    'nails': [
      VisitField('Форма',
          presets: ['Мигдаль', 'Квадрат', 'Овал', 'Балерина', 'Софт-сквер']),
      VisitField('Довжина', presets: ['Коротка', 'Середня', 'Довга']),
      VisitField('Колір'),
      VisitField('Дизайн'),
    ],
    'hair': [
      VisitField('Формула кольору'),
      VisitField('Окисник', presets: ['1.5%', '3%', '6%', '9%', '12%']),
      VisitField('Витримка', presets: ['20 хв', '30 хв', '40 хв', '50 хв']),
      VisitField('Догляд'),
    ],
    'barber': [
      VisitField('Насадка', presets: ['0.5', '1', '2', '3', '4', '6']),
      VisitField('Проділ', presets: ['Лівий', 'Правий', 'Без проділу']),
      VisitField('Борода'),
    ],
    'makeup': [
      VisitField('Тип', presets: ['Денний', 'Вечірній', 'Весільний', 'Зйомка']),
      VisitField('Тон'),
      VisitField('Акцент', presets: ['Очі', 'Губи', 'Скульптура']),
    ],
    'cosmetology': [
      VisitField('Тип шкіри',
          presets: ['Суха', 'Жирна', 'Комбінована', 'Чутлива']),
      VisitField('Препарат'),
      VisitField('Процедура за курсом', presets: ['1', '2', '3', '4', '5']),
      VisitField('Реакція', presets: ['Спокійна', 'Почервоніння', 'Набряк']),
    ],
    'depilation': [
      VisitField('Зона'),
      VisitField('Матеріал', presets: ['Віск', 'Шугаринг', 'Плівковий віск']),
      VisitField('Чутливість', presets: ['Низька', 'Середня', 'Висока']),
    ],
    'permanent': [
      VisitField('Техніка',
          presets: ['Пудрові', 'Волоскові', 'Змішана', 'Акварель']),
      VisitField('Пігмент'),
      VisitField('Сеанс', presets: ['Перший', 'Корекція', 'Оновлення']),
      VisitField('Загоєння'),
    ],
    'tattoo': [
      VisitField('Зона'),
      VisitField('Сеанс', presets: ['1', '2', '3', '4']),
      VisitField('Фарби'),
      VisitField('Голки'),
    ],
    'massage': [
      VisitField('Зона', presets: ['Спина', 'Шия', 'Ноги', 'Усе тіло']),
      VisitField('Тиск', presets: ['Легкий', 'Середній', 'Глибокий']),
      VisitField('Олія'),
      VisitField('Скарги'),
    ],
    'trainer': [
      VisitField('Програма'),
      VisitField('Навантаження', presets: ['Легке', 'Середнє', 'Високе']),
      VisitField('Вага'),
      VisitField('Наступне заняття'),
    ],
    'tutor': [
      VisitField('Тема'),
      VisitField('Домашнє завдання'),
      VisitField('Як засвоїв',
          presets: ['Легко', 'Нормально', 'Треба повторити']),
    ],
    'psy': [
      VisitField('Запит'),
      VisitField('Техніка'),
      VisitField('Наступний крок'),
    ],
    'grooming': [
      VisitField('Стрижка'),
      VisitField('Насадка', presets: ['3', '6', '9', '12']),
      VisitField('Поведінка',
          presets: ['Спокійна', 'Хвилюється', 'Потрібен намордник']),
    ],
    'photo': [
      VisitField('Локація'),
      VisitField('Образи', presets: ['1', '2', '3']),
      VisitField('Обробка', presets: ['10 кадрів', '20 кадрів', '30 кадрів']),
    ],
    'auto': [
      VisitField('Пробіг'),
      VisitField('Роботи'),
      VisitField('Наступне ТО'),
    ],
  };

  /// Поля для сфери майстра. Невідома сфера — універсальний набір.
  static List<VisitField> forIndustry(String? industryId) =>
      _byIndustry[industryId] ?? generic;
}
