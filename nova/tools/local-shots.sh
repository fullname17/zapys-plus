#!/usr/bin/env bash
# Локальний рендер екранів — той самий tools/shoot.mjs, що й у CI, але без
# GitHub Actions: збірка → локальний сервер → Playwright із системним Chromium.
# Дає цикл «правка → знімок» за ~2 хв замість ~10 хв очікування CI.
#
#   tools/local-shots.sh            — усі маршрути
#   tools/local-shots.sh home,menu  — лише вказані
#   SKIP_BUILD=1 tools/local-shots.sh home   — без перезбірки
set -euo pipefail
cd "$(dirname "$0")/.."

CHROMIUM="${PW_CHROMIUM:-/opt/pw-browsers/chromium}"
PROXY="${PW_PROXY:-${HTTPS_PROXY:-}}"
PORT="${PORT:-8080}"

if [ "${SKIP_BUILD:-0}" != "1" ]; then
  flutter build web --release --base-href /
fi

# CanvasKit тягнеться з gstatic.com, який у пісочниці недоступний. Локальна
# копія вже лежить у build/web/canvaskit — просто вказуємо на неї лоадеру.
python3 - <<'PY'
p = 'build/web/flutter_bootstrap.js'
s = open(p, encoding='utf-8').read()
s = s.replace('  config: { canvasKitBaseUrl: "/canvaskit/" },\n', '')
# Прив'язуємось до реального (багаторядкового) виклику в кінці файлу, а не
# до збігу всередині мініфікованого flutter.js на початку.
old = '_flutter.loader.load({\n'
assert old in s, 'loader.load call not found'
new = '_flutter.loader.load({\n  config: { canvasKitBaseUrl: "/canvaskit/" },\n'
s = s.replace(old, new, 1)
open(p, 'w', encoding='utf-8').write(s)
print('local canvaskit wired')
PY

# Сервер: піднімаємо, якщо порт вільний.
if ! curl -sf -o /dev/null "http://localhost:$PORT/index.html"; then
  python3 -m http.server "$PORT" --directory build/web >/tmp/zapys-serve.log 2>&1 &
  sleep 2
fi

PW_BASE="http://localhost:$PORT" \
PW_CHROMIUM="$CHROMIUM" \
PW_PROXY="$PROXY" \
PW_ONLY="${1:-}" \
  node tools/shoot.mjs

ls -la shots
