// Знімки реального Flutter-web застосунку для звірки pixel-perfect із макетами.
// Запускається в CI (там є інтернет для CanvasKit/шрифтів), рендерить кожен
// маршрут у телефонному вьюпорті й зберігає PNG у screens/.
import { chromium } from 'playwright';
import { mkdirSync } from 'fs';

const base = process.env.PW_BASE || 'http://localhost:8080';

// Локальний прогін (без CI): вказати системний Chromium і проксі середовища.
// У CI ці змінні не задані — поведінка лишається один-в-один як була.
const exe = process.env.PW_CHROMIUM || undefined;
const proxy = process.env.PW_PROXY || undefined;
// PW_ONLY=home,calendar — зняти лише частину маршрутів (швидка ітерація).
const only = (process.env.PW_ONLY || '').split(',').map((s) => s.trim()).filter(Boolean);

const routes = [
  ['splash', '/splash?hold=1&demo=1'],
  ['onboarding', '/onboarding?demo=1'],
  ['industry', '/onboarding?step=industry&demo=1'],
  ['home', '/?s=1&demo=1'],
  ['rebook', '/rebook?demo=1'],
  ['recap', '/recap?demo=1'],
  ['calendar', '/calendar?demo=1'],
  ['calendar-week', '/calendar?view=week&demo=1'],
  ['calendar-month', '/calendar?view=month&demo=1'],
  // Листи — теж екрани: знімаємо їх окремими маршрутами (?sheet=).
  ['appointment-sheet', '/calendar?sheet=appointment&demo=1'],
  ['appointment-move', '/calendar?sheet=move&demo=1'],
  ['appointment-edit', '/calendar?sheet=edit&demo=1'],
  ['appointment-create', '/calendar?sheet=create&demo=1'],
  ['appointment-deposit', '/calendar?sheet=deposit&demo=1'],
  ['appointment-work', '/calendar?sheet=work&demo=1'],
  ['create-client', '/clients?sheet=client&demo=1'],
  ['create-service', '/services?sheet=service&demo=1'],
  ['analytics', '/analytics?demo=1'],
  ['clients', '/clients?demo=1'],
  ['client', '/clients/cl_olena?demo=1'],
  ['services', '/services?demo=1'],
  ['schedule', '/schedule?demo=1'],
  ['subscription', '/subscription?demo=1'],
  ['booking', '/online-booking?demo=1'],
  ['book', '/book?demo=1'],
  ['book-time', '/book?step=time&demo=1'],
  ['book-confirm', '/book?step=confirm&demo=1'],
  ['book-done', '/book?step=done&demo=1'],
  ['smart-gaps', '/smart-gaps?demo=1'],
  ['repeat-due', '/repeat?demo=1'],
  ['backup', '/backup?demo=1'],
  ['menu', '/menu?demo=1'],
  ['settings', '/settings?demo=1'],
  // Скелетони: локальна БД віддає дані миттєво, тож стан завантаження
  // знімається примусово через ?skeleton=1.
  ['skeleton-home', '/?s=1&skeleton=1&demo=1'],
  ['skeleton-calendar', '/calendar?skeleton=1&demo=1'],
  ['skeleton-clients', '/clients?skeleton=1&demo=1'],
  ['skeleton-services', '/services?skeleton=1&demo=1'],
  ['skeleton-client', '/clients/cl_olena?skeleton=1&demo=1'],
  // Локалізація EN/RU — перевірка ключових екранів.
  ['home-en', '/?s=1&lang=en&demo=1'],
  ['menu-en', '/menu?lang=en&demo=1'],
  ['analytics-en', '/analytics?lang=en&demo=1'],
  ['calendar-en', '/calendar?lang=en&demo=1'],
  ['settings-en', '/settings?lang=en&demo=1'],
  ['home-ru', '/?s=1&lang=ru&demo=1'],
  ['menu-ru', '/menu?lang=ru&demo=1'],
  ['analytics-ru', '/analytics?lang=ru&demo=1'],
  ['clients-en', '/clients?lang=en&demo=1'],
  ['client-en', '/clients/cl_olena?lang=en&demo=1'],
  ['services-en', '/services?lang=en&demo=1'],
  ['subscription-en', '/subscription?lang=en&demo=1'],
  ['book-en', '/book?step=confirm&lang=en&demo=1'],
  ['book-ru', '/book?step=confirm&lang=ru&demo=1'],
];

mkdirSync('shots', { recursive: true });

const browser = await chromium.launch({
  args: ['--no-sandbox'],
  ...(exe ? { executablePath: exe } : {}),
  ...(proxy
    ? { proxy: { server: proxy, bypass: 'localhost,127.0.0.1' } }
    : {}),
});

for (const [name, route] of routes) {
  if (only.length && !only.includes(name)) continue;
  const url = `${base}/#${route}`;
  // Свіжий контекст на кожен маршрут — гарантує повне завантаження документа
  // (інакше зміна лише хеша/query не перезапускає main() і ?view= не діє).
  const ctx = await browser.newContext({
    viewport: { width: 402, height: 874 },
    deviceScaleFactor: 3,
    ignoreHTTPSErrors: Boolean(proxy),
  });
  if (proxy) {
    // Локально резервні шрифти CanvasKit (Roboto, емодзі) з gstatic недоступні
    // й підвішують старт на десятки секунд. Обриваємо одразу — Inter усе одно
    // забандлений в ассетах, тож текст рендериться однаково.
    await ctx.route('https://fonts.gstatic.com/**', (r) => r.abort());
  }
  const page = await ctx.newPage();
  try {
    await page.goto(url, { waitUntil: 'load', timeout: 60000 });
    await page
      .waitForFunction(
        () =>
          document.querySelector('flutter-view') ||
          document.querySelector('flt-glass-pane') ||
          document.querySelector('flt-scene-host'),
        { timeout: 45000 }
      )
      .catch(() => {});
    // Даємо час на шрифти (google_fonts) і stagger-анімації.
    await page.waitForTimeout(Number(process.env.PW_WAIT || 4500));
    await page.screenshot({ path: `shots/${name}.png` });
    console.log('shot', name, 'ok');
  } catch (e) {
    console.log('shot', name, 'FAILED', e.message);
  }
  await ctx.close();
}

await browser.close();
