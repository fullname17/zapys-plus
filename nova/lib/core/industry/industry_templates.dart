import 'package:flutter/material.dart';

/// Система отраслевых шаблонов. Каждая индустрия — готовое рабочее пространство:
/// категории, типовые услуги (рекомендованная длительность и цена, редактируемые),
/// цвет календаря, иконка, дефолты уведомлений. Пользователь выбирает сферу и за
/// ~30 секунд получает настроенный продукт (Time to First Value).
///
/// Платформа универсальна: сущности нейтральны (Business/Service/Client/
/// Appointment/Resource), а специфику даёт ДАННЫЙ каталог, а не код.

class ServiceTemplate {
  const ServiceTemplate(this.name, this.durationMinutes, this.price);
  final String name;
  final int durationMinutes;

  /// Рекомендованная цена в минорных единицах (×100), редактируется.
  final int price;
}

class ServiceCategoryTemplate {
  const ServiceCategoryTemplate(this.name, this.services);
  final String name;
  final List<ServiceTemplate> services;
}

class IndustryNotificationDefaults {
  const IndustryNotificationDefaults({
    this.remind24h = true,
    this.remind2h = true,
    this.thanks = true,
  });
  final bool remind24h;
  final bool remind2h;
  final bool thanks;
}

class IndustryTemplate {
  const IndustryTemplate({
    required this.id,
    required this.title,
    required this.icon,
    required this.color,
    required this.categories,
    this.notifications = const IndustryNotificationDefaults(),
    this.repeatAfterDays,
  });

  final String id;
  final String title;
  final IconData icon;

  /// Цвет календаря/акцента для этой сферы.
  final Color color;
  final List<ServiceCategoryTemplate> categories;
  final IndustryNotificationDefaults notifications;

  /// Через скільки днів у цій сфері зазвичай повертаються: корекція вій,
  /// оновлення кольору, наступна чистка. Застосунок підставляє це число всім
  /// послугам шаблону — майстер потім міняє кожну під себе. null — сфера
  /// разових візитів (фотограф, тату), нагадувати нема про що.
  final int? repeatAfterDays;

  /// Плоский список услуг (для сидирования).
  List<({String category, ServiceTemplate service})> get flatServices => [
        for (final c in categories)
          for (final s in c.services) (category: c.name, service: s),
      ];
}

/// Каталог сфер. Розширюється даними, а не кодом: щоб додати нову професію,
/// достатньо дописати сюди шаблон — екрани не змінюються.
///
/// Ціни — у мінорних одиницях (×100) і в гривні: 50000 = ₴500. Це орієнтири
/// українського ринку, майстер міняє їх під себе за пів хвилини.
/// Порядок важливий: ядро аудиторії (б'юті) — зверху.
abstract final class IndustryCatalog {
  static const List<IndustryTemplate> all = [
    // — Ядро: вії, брови, нігті —
    IndustryTemplate(
      id: 'lashes',
      repeatAfterDays: 21,
      title: 'Вії',
      icon: Icons.remove_red_eye_outlined,
      color: Color(0xFF9A9AF6),
      categories: [
        ServiceCategoryTemplate('Нарощування', [
          ServiceTemplate('Класика', 120, 60000),
          ServiceTemplate('2D–3D об\'єм', 150, 75000),
          ServiceTemplate('Корекція', 90, 50000),
          ServiceTemplate('Зняття', 30, 15000),
        ]),
        ServiceCategoryTemplate('Догляд', [
          ServiceTemplate('Ламінування вій', 60, 55000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'brows',
      repeatAfterDays: 30,
      title: 'Брови',
      icon: Icons.brush_outlined,
      color: Color(0xFFB07CE8),
      categories: [
        ServiceCategoryTemplate('Брови', [
          ServiceTemplate('Корекція', 30, 25000),
          ServiceTemplate('Корекція + фарбування', 60, 40000),
          ServiceTemplate('Ламінування брів', 60, 55000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'nails',
      repeatAfterDays: 21,
      title: 'Нігті',
      icon: Icons.back_hand_outlined,
      color: Color(0xFFE86FA6),
      categories: [
        ServiceCategoryTemplate('Манікюр', [
          ServiceTemplate('Класичний манікюр', 30, 35000),
          ServiceTemplate('Гель-лак', 45, 50000),
          ServiceTemplate('Нейл-арт', 60, 75000),
        ]),
        ServiceCategoryTemplate('Педикюр', [
          ServiceTemplate('Spa-педикюр', 60, 65000),
          ServiceTemplate('Експрес-педикюр', 35, 45000),
        ]),
      ],
    ),
    // — Волосся й обличчя —
    IndustryTemplate(
      id: 'hair',
      repeatAfterDays: 45,
      title: 'Перукар / колорист',
      icon: Icons.content_cut_outlined,
      color: Color(0xFF5B8DEF),
      categories: [
        ServiceCategoryTemplate('Стрижка', [
          ServiceTemplate('Жіноча стрижка', 60, 45000),
          ServiceTemplate('Укладка', 45, 35000),
        ]),
        ServiceCategoryTemplate('Колір', [
          ServiceTemplate('Фарбування коренів', 90, 80000),
          ServiceTemplate('Складне фарбування', 180, 200000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'barber',
      repeatAfterDays: 21,
      title: 'Барбершоп',
      icon: Icons.content_cut,
      color: Color(0xFF5B5BD6),
      categories: [
        ServiceCategoryTemplate('Стрижка', [
          ServiceTemplate('Чоловіча стрижка', 45, 40000),
          ServiceTemplate('Стрижка + борода', 60, 55000),
          ServiceTemplate('Оформлення бороди', 30, 25000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'makeup',
      title: 'Візажист',
      icon: Icons.auto_awesome_outlined,
      color: Color(0xFFE86FA6),
      categories: [
        ServiceCategoryTemplate('Макіяж', [
          ServiceTemplate('Денний макіяж', 60, 70000),
          ServiceTemplate('Вечірній макіяж', 90, 100000),
          ServiceTemplate('Весільний образ', 150, 250000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'cosmetology',
      repeatAfterDays: 30,
      title: 'Косметолог',
      icon: Icons.spa_outlined,
      color: Color(0xFF46D08A),
      categories: [
        ServiceCategoryTemplate('Догляд', [
          ServiceTemplate('Чистка обличчя', 90, 90000),
          ServiceTemplate('Пілінг', 60, 80000),
          ServiceTemplate('Масаж обличчя', 45, 60000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'depilation',
      repeatAfterDays: 30,
      title: 'Депіляція',
      icon: Icons.waves_outlined,
      color: Color(0xFF46C2D0),
      categories: [
        ServiceCategoryTemplate('Цукрова / віск', [
          ServiceTemplate('Гомілки', 40, 35000),
          ServiceTemplate('Бікіні', 45, 50000),
          ServiceTemplate('Пахви', 20, 20000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'permanent',
      repeatAfterDays: 365,
      title: 'Перманентний макіяж',
      icon: Icons.colorize_outlined,
      color: Color(0xFFB07CE8),
      categories: [
        ServiceCategoryTemplate('Перманент', [
          ServiceTemplate('Брови', 180, 350000),
          ServiceTemplate('Губи', 180, 400000),
          ServiceTemplate('Корекція', 90, 150000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'tattoo',
      title: 'Тату й пірсинг',
      icon: Icons.gesture_outlined,
      color: Color(0xFF8B8BF0),
      categories: [
        ServiceCategoryTemplate('Сеанси', [
          ServiceTemplate('Ескіз і консультація', 45, 0),
          ServiceTemplate('Сеанс тату', 180, 300000),
          ServiceTemplate('Пірсинг', 30, 80000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'massage',
      repeatAfterDays: 14,
      title: 'Масаж і СПА',
      icon: Icons.self_improvement_outlined,
      color: Color(0xFF46D08A),
      categories: [
        ServiceCategoryTemplate('Масаж', [
          ServiceTemplate('Класичний масаж', 60, 70000),
          ServiceTemplate('Спина й шия', 30, 45000),
          ServiceTemplate('Спа-ритуал', 90, 120000),
        ]),
      ],
    ),
    // — Поруч: ті самі болі —
    IndustryTemplate(
      id: 'trainer',
      repeatAfterDays: 7,
      title: 'Тренер / йога',
      icon: Icons.fitness_center_outlined,
      color: Color(0xFFE6B24E),
      categories: [
        ServiceCategoryTemplate('Заняття', [
          ServiceTemplate('Персональне тренування', 60, 50000),
          ServiceTemplate('Парне тренування', 60, 80000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'tutor',
      repeatAfterDays: 7,
      title: 'Репетитор / логопед',
      icon: Icons.menu_book_outlined,
      color: Color(0xFF5B8DEF),
      categories: [
        ServiceCategoryTemplate('Заняття', [
          ServiceTemplate('Індивідуальне заняття', 60, 40000),
          ServiceTemplate('Пробне заняття', 30, 0),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'psy',
      repeatAfterDays: 14,
      title: 'Психолог / коуч',
      icon: Icons.record_voice_over_outlined,
      color: Color(0xFF6E56CF),
      categories: [
        ServiceCategoryTemplate('Сесії', [
          ServiceTemplate('Консультація', 60, 100000),
          ServiceTemplate('Знайомство', 20, 0),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'grooming',
      repeatAfterDays: 60,
      title: 'Грумінг',
      icon: Icons.pets_outlined,
      color: Color(0xFFD98324),
      categories: [
        ServiceCategoryTemplate('Догляд', [
          ServiceTemplate('Комплекс', 120, 90000),
          ServiceTemplate('Гігієнічна стрижка', 60, 50000),
          ServiceTemplate('Купання', 45, 35000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'photo',
      title: 'Фотограф',
      icon: Icons.photo_camera_outlined,
      color: Color(0xFFB5179E),
      categories: [
        ServiceCategoryTemplate('Зйомки', [
          ServiceTemplate('Індивідуальна зйомка', 90, 250000),
          ServiceTemplate('Сімейна зйомка', 120, 350000),
        ]),
      ],
    ),
    IndustryTemplate(
      id: 'auto',
      repeatAfterDays: 180,
      title: 'Автосервіс / детейлінг',
      icon: Icons.directions_car_outlined,
      color: Color(0xFF3E7BFA),
      categories: [
        ServiceCategoryTemplate('Роботи', [
          ServiceTemplate('Діагностика', 60, 50000),
          ServiceTemplate('Заміна оливи', 45, 40000),
          ServiceTemplate('Комплексне миття', 90, 80000),
        ]),
      ],
    ),
    // — Універсальне —
    IndustryTemplate(
      id: 'other',
      title: 'Інше',
      icon: Icons.more_horiz,
      color: Color(0xFF6A6A76),
      categories: [
        ServiceCategoryTemplate('Послуги', [
          ServiceTemplate('Послуга', 60, 50000),
          ServiceTemplate('Консультація', 30, 0),
        ]),
      ],
    ),
  ];

  static IndustryTemplate byId(String id) {
    for (final i in all) {
      if (i.id == id) return i;
    }
    return all.last; // 'other'
  }
}
