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
  ['splash', '/splash?hold=1'],
  ['onboarding', '/onboarding'],
  ['home', '/?s=1'],
  ['rebook', '/rebook'],
  ['recap', '/recap'],
  ['calendar', '/calendar'],
  ['calendar-week', '/calendar?view=week'],
  ['calendar-month', '/calendar?view=month'],
  // Листи — теж екрани: знімаємо їх окремими маршрутами (?sheet=).
  ['appointment-sheet', '/calendar?sheet=appointment'],
  ['appointment-move', '/calendar?sheet=move'],
  ['appointment-edit', '/calendar?sheet=edit'],
  ['appointment-create', '/calendar?sheet=create'],
  ['create-client', '/clients?sheet=client'],
  ['create-service', '/services?sheet=service'],
  ['analytics', '/analytics'],
  ['clients', '/clients'],
  ['client', '/clients/cl_olena'],
  ['services', '/services'],
  ['subscription', '/subscription'],
  ['booking', '/online-booking'],
  ['book', '/book'],
  ['book-time', '/book?step=time'],
  ['book-confirm', '/book?step=confirm'],
  ['book-done', '/book?step=done'],
  ['smart-gaps', '/smart-gaps'],
  ['menu', '/menu'],
  ['settings', '/settings'],
  // Скелетони: локальна БД віддає дані миттєво, тож стан завантаження
  // знімається примусово через ?skeleton=1.
  ['skeleton-home', '/?s=1&skeleton=1'],
  ['skeleton-calendar', '/calendar?skeleton=1'],
  ['skeleton-clients', '/clients?skeleton=1'],
  ['skeleton-services', '/services?skeleton=1'],
  ['skeleton-client', '/clients/cl_olena?skeleton=1'],
  // Локалізація EN/RU — перевірка ключових екранів.
  ['home-en', '/?s=1&lang=en'],
  ['menu-en', '/menu?lang=en'],
  ['analytics-en', '/analytics?lang=en'],
  ['calendar-en', '/calendar?lang=en'],
  ['settings-en', '/settings?lang=en'],
  ['home-ru', '/?s=1&lang=ru'],
  ['menu-ru', '/menu?lang=ru'],
  ['analytics-ru', '/analytics?lang=ru'],
  ['clients-en', '/clients?lang=en'],
  ['client-en', '/clients/cl_olena?lang=en'],
  ['services-en', '/services?lang=en'],
  ['subscription-en', '/subscription?lang=en'],
  ['book-en', '/book?step=confirm&lang=en'],
  ['book-ru', '/book?step=confirm&lang=ru'],
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
