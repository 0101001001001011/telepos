#!/usr/bin/env bash
# Сборка Linux-выпуска TelePOS: приложение + страница терминала рядом с ним.
#
# Запускается В WSL, файлом, а не строкой из PowerShell: через два слоя кавычек
# это уже ломалось.
#
# # Три вещи, которые здесь не случайны
#
# 1. **Flutter зовётся полным путём.** В WSL `which flutter` даёт
#    `/mnt/d/Flutter/flutter/bin/flutter` — виндовую установку, и она соберёт
#    не то. Линуксовый лежит в `~/flutter`.
# 2. **Каталог `web` кладётся рядом с исполняемым файлом.** Его ищет
#    `lib/backend/web_bundle.dart`; без него касса поднимется, а браузерный
#    терминал получит пустую страницу — отказ, который выглядит как поломка
#    сети.
# 3. **Rust из `~/.cargo/bin`** — нативная часть пакетов `rk_*` собирается им.
set -euo pipefail

FLUTTER="${TELEPOS_LINUX_FLUTTER:-$HOME/flutter/bin/flutter}"
export PATH="$HOME/.cargo/bin:$PATH"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

# # Дерево общее с Windows, и `.dart_tool` в нём один
#
# `flutter build` делает неявный `pub get`, а тот переписывает
# `.dart_tool/package_config.json` АБСОЛЮТНЫМИ путями своей стороны:
# `/home/kimboo/.pub-cache` вместо виндового каталога Pub\Cache. После
# линуксовой сборки виндовый анализатор перестаёт находить пакеты и выдаёт
# 51 224 ошибки на неизменном коде — «Target of URI does not exist:
# package:flutter/foundation.dart» в каждом файле.
#
# Выглядит катастрофой, ею не является и лечится одним `flutter pub get` на
# Windows. Но лечить должен тот, кто сломал: запоминаем чужую настройку до
# сборки и возвращаем после — `trap` на EXIT, то есть и при отказе тоже.
#
# Каталог `build/` при этом общий намеренно: `build/web` собирают обе
# стороны и обе кладут туда же, а страница терминала от платформы не зависит.
DART_TOOL="$ROOT/.dart_tool"
SAVED="$(mktemp -d)"
restore_package_config() {
  for f in package_config.json package_config_subset version; do
    [ -f "$SAVED/$f" ] && cp -f "$SAVED/$f" "$DART_TOOL/$f"
  done
  rm -rf "$SAVED"
  echo ">> настройка пакетов возвращена стороне, которая её завела"
}
if [ -d "$DART_TOOL" ]; then
  for f in package_config.json package_config_subset version; do
    [ -f "$DART_TOOL/$f" ] && cp -f "$DART_TOOL/$f" "$SAVED/$f"
  done
  trap restore_package_config EXIT
fi

[ -x "$FLUTTER" ] || { echo "нет линуксового Flutter: $FLUTTER"; exit 1; }
command -v cargo >/dev/null || { echo "нет cargo в PATH"; exit 1; }

VERSION="$(grep -m1 '^version:' pubspec.yaml | sed 's/version: *//; s/+.*//')"
BUILD="$(grep -m1 '^version:' pubspec.yaml | sed 's/.*+//')"
echo ">> версия $VERSION+$BUILD, Flutter: $("$FLUTTER" --version | head -1)"

echo ">> касса"
"$FLUTTER" build linux --release

echo ">> страница терминала"
"$FLUTTER" build web -t lib/web/main_web.dart --release --pwa-strategy=none

BUNDLE="build/linux/x64/release/bundle"
[ -d "$BUNDLE" ] || { echo "нет бандла: $BUNDLE"; exit 1; }

# Страница терминала — рядом с исполняемым файлом, а не в data/: там её ищет
# `WebBundle.locate`.
rm -rf "$BUNDLE/web"
cp -r build/web "$BUNDLE/web"

OUT="build/installer/telepos-linux-x64-$VERSION+$BUILD.tar.gz"
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
tar -czf "$OUT" -C "$(dirname "$BUNDLE")" "$(basename "$BUNDLE")"

echo ">> готово: $OUT ($(du -h "$OUT" | cut -f1))"
echo ">> состав (первые 12 записей):"
tar -tzf "$OUT" | head -12
echo ">> страница терминала в архиве:"
tar -tzf "$OUT" | grep -c '/web/' || echo "0 — ЭТО ОШИБКА, архив без терминала"
