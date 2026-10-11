# 🧪 Разработка и тестирование | AniStar TV

Команды выполняются из корня проекта. Unit/widget-тесты используют fixtures. Emulator E2E проверяет приложение с локальными HTML/HLS и настоящим Android player; live smoke использует AniStar/CDN.

## 1. Окружение и запуск

Нужны **FVM**, Flutter **3.47.7** из `.fvmrc`, Dart **3.13.5**, JDK **17**, Android SDK и устройство/эмулятор.

```bash
fvm install
fvm flutter pub get
fvm flutter run --flavor dev -t lib/main_dev.dart \
  --dart-define-from-file=env/dev.json
```

`env/dev.json` хранится в Git. Для собственного production-зеркала скопируйте `env/prod.example.json` в `env/prod.json`; этот файл игнорируется Git. Default зеркало работает без файла defines.

### Flavors

| Flavor | Entry point | Назначение |
| --- | --- | --- |
| dev | `lib/main_dev.dart` | Разработка, отдельный Android application ID |
| prod | `lib/main_prod.dart` | Основное приложение |

Debug/profile сохраняет диагностические логи и открывает viewer из каталога. Release пишет только ошибки в системный output; файловый output и viewer отключены. Это зависит от build mode, а не имени flavor.

VS Code использует `.fvm/flutter_sdk`; launch и tasks находятся в `.vscode/`. Dart/DCM настроены в `analysis_options.yaml`. Активный код: `lib/` и `infrastructure/`; generated sources и build outputs исключены из анализа приложения.

---

## 2. Проверки и сборка

Полная локальная проверка:

```bash
bash scripts/check.sh
```

Порядок: SDK и lockfile → форматирование → analyzer → DCM → unit/widget/architecture с coverage → golden comparison. Ошибка останавливает команду и возвращает ненулевой exit code. Форматирование и baselines при проверке не изменяются.

| Режим | Команда |
| --- | --- |
| Форматирование | `bash scripts/check.sh format` |
| Только проверка формата | `bash scripts/check.sh format:check` |
| Analyzer / DCM | `bash scripts/check.sh analyze` / `bash scripts/check.sh dcm` |
| Unit/widget и coverage | `bash scripts/check.sh test:unit` |
| Golden comparison | `bash scripts/check.sh test:goldens` |
| Обновить golden baseline | `bash scripts/check.sh test:goldens:update` |
| Быстрые Flutter-проверки без DCM | `bash scripts/check.sh ci` |

DCM нужен для полной локальной проверки; допустимая версия указана в `dcm_global.yaml`. Analyzer считает infos ошибкой. Все workspace-пакеты наследуют корневой `analysis_options.yaml`.

Проверки выполняются локально; CI/CD не настроен. Режим `ci` оставлен как короткий профиль без DCM: формат, analyzer, unit coverage и goldens. Для полного прогона используйте `check`. Coverage сохраняется в `coverage/lcov.info`, различия golden — рядом с тестом в `failures/`.

По умолчанию порядок тестов задаёт seed **20261010**. Другой seed: `ANISTAR_TEST_SEED=1337 bash scripts/check.sh test:unit`. При необходимости задайте путь установленного SDK через `ANISTAR_FLUTTER_SDK`; версия всё равно сверяется с `.fvmrc`.

Запускайте Flutter-команды последовательно: они используют общий generated output. Живой Android-сценарий выполняется отдельно от детерминированных проверок.

```bash
# E2E на запущенном Android emulator
bash scripts/e2e.sh emulator-5554

# Живой AniStar/CDN smoke
bash scripts/e2e.sh emulator-5554 live

# APK приложения
fvm flutter build apk --debug --flavor dev -t lib/main_dev.dart
fvm flutter build apk --release --flavor prod -t lib/main_prod.dart
python3 tool/quality/verify_android_apk.py
```

APK находятся в `build/app/outputs/flutter-apk/`. Release использует существующую тестовую подпись; перед публикацией настройте собственный signing config.

После integration test запускайте обычную APK-команду с pub lifecycle, чтобы plugin registrar соответствовал build mode и entry point.

В прежнем Flutter 3.44 / AGP 9 наблюдался устаревший JNI merge после изменения
Dart-кода. Защита в app Gradle сохранена: up-to-date для этой стадии копирования отключён. Проверка
APK сравнивает текущие AOT libraries с отдельным JNI staging Flutter 3.47, JNI merge и содержимым архива после stripping; набор ABI также должен совпадать.
Её регрессии запускаются через `python3 -m unittest discover -s tool/quality -p '*_test.py'`.
Запускайте эту проверку локально после release-сборки.

Изменение typed routes требует генерации:

```bash
fvm dart run build_runner build
```

---

## 3. Структура тестов

Тесты повторяют структуру исходников; для workspace-пакетов сегменты lib/src опускаются:

| Исходник | Тест |
| --- | --- |
| `infrastructure/networking/lib/src/base_repository.dart` | `test/infrastructure/networking/base_repository_test.dart` |
| `lib/packages/features/catalog/presentation/screens/catalog_screen.dart` | `test/packages/features/catalog/presentation/screens/catalog_screen_test.dart` |
| `lib/packages/ui_kit/lib/src/widgets/tv_focusable.dart` | `test/packages/ui_kit/widgets/tv_focusable_test.dart` |

Fixtures и fakes находятся в `test/mocks/`. HTTP заменяется adapter, репозитории fake-реализациями, native player fake platform. Unit/widget-тесты не обращаются к сайту.

`test/flutter_test_config.dart` вызывает общий bootstrap из `test/support/`: тестовый logger, локальные Inter/Material Icons и запрет создания настоящего HttpClient. Проверки HTTP используют fixture adapter. Проверки логирования передают capturing logger явно.

`pumpTvApp` задаёт production theme, ProviderScope и TV viewport; свойства view сбрасываются после теста. Fake video platform восстанавливает прежний platform instance. Сам bootstrap, разбор Dart directives и остановка quality gate тоже покрыты тестами.

Регрессионные тесты проверяют поздние ответы и refresh логов, смену параметров
маршрута, выход во время native initialization, ошибки команд плеера, ручной
retry пагинации, redaction подписанного URL и закрытие файлового logger.
Ошибка startup возвращается из runApplication; runtime errors остаются в guarded zone.

---

## 4. Что тестируем

| Уровень | Контракт |
| --- | --- |
| Unit | Charset, HTML/JSON5, DTO mapping, пагинация, Failure и retry |
| BLoC | Переходы состояний, загрузка, ошибка и повтор |
| Widget / TV layout | Focus, OK, overflow, смена серии/качества и dispose |
| Golden | Каталог и экран ошибки в 960×540 и 1280×720 |
| Architecture | Нейтральность Core, публичные API и направление зависимостей |
| App DI | Repository bindings, общие сервисы и закрытие HTTP |
| Emulator E2E | Production runner/DI, HTTP/HTML, native HLS, login/Secure Storage, каталог, retry и Back |
| Live Android smoke | Настоящий AniStar/CDN: запуск, seek, пауза, 360p/720p и серии |

Тесты защищают ветвления, контракт и исправленные баги. Coverage включает приложение и workspace-пакеты; цель 100% не установлена. Golden PNG хранятся рядом с тестами в `goldens/`; обновляйте их только после просмотра изменений UI. Проверяются каталог и вкладки, ошибки/пустые состояния, вход, loading каталога и карточки, длинные названия и описание. Скелетоны в снимках статичны через `MediaQuery.disableAnimations`; `pumpAndSettle` проверяет отсутствие продолжающегося shimmer в этом режиме. Сравнение точное, шрифты и SDK закреплены.

### TV layout

Используйте общий helper из `test/support/test_app.dart`:

```dart
await pumpTvApp(tester, const TvFocusableExample(), size: wideTvSize);
await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
await tester.sendKeyEvent(LogicalKeyboardKey.select);
expect(tester.takeException(), isNull);
```

Размер по умолчанию: **960×540**, `wideTvSize`: **1280×720**, DPR: **1**. ProviderContainer освобождается в tearDown/addTearDown; подписки, timers и controllers не должны переживать тест.

---

## 5. E2E и smoke на Android TV

Запустите Android emulator через Device Manager или `fvm flutter emulators --launch <avd>`. Узнайте ID через `fvm flutter devices`, затем выполните `bash scripts/e2e.sh <emulator-id>`. Команда принимает только emulator, проверяет SDK/lockfile и запускает dev flavor.

| Сценарий | Проверка |
| --- | --- |
| Вход и сессия | Неверный пароль → вход → новый runner → Secure Storage restore → expiry → выход → новый запуск |
| Избранное сайта | Долгое OK → добавление → звезда → новый runner → вкладка → удаление из карточки → пустой список → изменение с другого клиента |
| Отказ избранного | HTTP 200 с error, видимая ошибка без звезды, свежий статус и успешный ручной повтор |
| Основной путь | Каталог → карточка → native 720p → seek/pause → 360p → серия 2 → Back |
| Удержание / idle player | Native rewind до границы, короткий seek после отпускания, pause → focus Play → resume → автоскрытие, Back focus → обновление idle → автоскрытие, выход во время удержания |
| Пагинация | Стрелки пульта, следующая HTTP-страница и её карточка на экране |
| Ошибка каталога | HTTP 403, видимый экран ошибки, успешный ручной повтор |
| Просроченный HLS | HTTP 403 → повторное получение player HTML → новый поток |
| Постоянный отказ HLS | Две попытки открытия, остановка retry, успешный ручной повтор |

Fixtures в `tool/e2e/` обслуживает loopback HTTPS server. `adb reverse` соединяет его с эмулятором; server проверяет Referer на master, nested playlist и TS, поддерживает Range. Синтетическое H.264/AAC видео длится 24 секунды и имеет варианты 360p/720p. Repository, parser, router, storage и video platform не подменяются. Test bootstrap задаёт только logger и доверие Dart transport к localhost certificate.

Native Android доверяет этому certificate через debug resources только для `localhost`. Тестовый private key публичный и используется лишь fixture server. В release этого доверия нет; media fixtures не включены в assets приложения.

Порядок E2E задаёт seed 20261010; для другого порядка используйте `ANISTAR_TEST_SEED=1337 bash scripts/e2e.sh <emulator-id>`. Каждое ожидание имеет deadline. Команда завершает fixture server, снимает своё reverse-соединение и восстанавливает immersive confirmation setting. Логи Flutter, Android и HTTP находятся в `build/e2e/run.*/`.

Для воспроизводимого прогона используйте API 36 emulator с TV hardware profile; на Apple Silicon — ARM64. Live smoke запускается явно и зависит от сети. Физический пульт и аппаратный декодер TV проверяются отдельно.

### Directional Pad эмулятора

Для `Extended Controls → Directional Pad` в профиле AVD нужны оба параметра:

```ini
hw.dPad=yes
hw.keyboard=yes
```

В Emulator 36.4.10 / API 36 при `hw.keyboard=no` отсутствовал kernel keyboard device: крестовина не передавала стрелки, хотя `adb shell input keyevent` и Flutter `sendKeyEvent` работали. После изменения `~/.android/avd/<name>.avd/config.ini` выполните **Cold Boot** через Device Manager или запустите `emulator -avd <name> -no-snapshot-load`. Данные приложения сохраняются; Wipe Data не нужен.

`scripts/e2e.sh` до запуска Flutter проверяет наличие четырёх стрелок на одном hardware input device через `getevent -pl`. Отдельный запуск проверки:

```bash
python3 tool/e2e/emulator_input.py --adb "$ANDROID_HOME/platform-tools/adb" --device emulator-5554
```

Проверка устройства не заменяет ручное нажатие стрелок и OK в самой панели. Синтетические Flutter-события проверяют focus приложения, но обходят эту часть эмулятора. [Документация Extended Controls](https://developer.android.com/studio/run/emulator-extended-controls).

### Ручной smoke

1. Приложение видно в TV launcher; focus понятен и перемещается стрелками.
2. Каталог открывает карточку и серии; короткое OK срабатывает один раз. Удержание OK открывает избранное после отпускания.
3. 720p и 360p запускаются; seek и пауза работают.
4. Смена качества сохраняет позицию; смена серии начинает с нуля.
5. Back закрывает player без Flutter exceptions и оставшихся системных панелей.
6. Добавление и удаление видны на сайте под тем же аккаунтом; вкладка и звезда обновляются после подтверждения.
7. Повторить несколько переходов Главная/Избранное: меню не исчезает, не перезапускает раскрытие и сохраняет фокус на выбранном пункте, пока содержимое загружается. Открыть жанры, вернуть Back и проверить прежний пункт. В пустом избранном фокус остаётся на пункте левого меню. Up + OK возвращают главную; Right ведёт к карточкам или действию пустого экрана. Back из detail возвращает к той же карточке.
8. Правая панель длинного списка сразу показывает текущую серию. Стрелки прокручивают строки; Back отменяет выбор, следующее OK управляет плеером.
9. После двух отказов входа подряд focus возвращается в очищенный пароль. Up возвращает в логин для редактирования; Down ведёт через пароль к «Войти», Up с кнопки — обратно через оба поля. Проверить удержание Up/Down, Left/Right для курсора, «Далее» и «Готово» экранной клавиатуры, а также дополнительную кнопку проверки сессии. Использовать локальный HTTPS fixture, без реального аккаунта.
10. Left с первой карточки любого ряда раскрывает левое меню: главная, избранное, выход из аккаунта, обновление, логи (только debug). Up/Down перемещают фокус; Right и Back сворачивают меню и возвращают прежнюю карточку. Без фокуса видны только иконки. Раскрытие не меняет число колонок; системное уменьшение анимаций учитывается. Долгое OK открывает панель действий справа после отпускания, Back закрывает её без изменения избранного и возвращает фокус на карточку.
11. В плеере Up фокусирует стрелку возврата к сериям; OK возвращает список. Down ведёт к шкале времени, затем к нижнему ряду: воспроизведение, −10 секунд, +10 секунд, серии, качество. На шкале Left/Right перематывают на 10 секунд; в ряду кнопок они перемещают фокус. Up с кнопок возвращает на шкалу, Down — к видео. Меню не скрывается под фокусом. Системный Back отменяет диалог, следующий Back закрывает плеер.
12. Проверить экран при play → pause → resume, завершении серии, отказе потока, смене качества/серии и нескольких возвратах в каталог. Удержание `FLAG_KEEP_SCREEN_ON` есть только у играющего foreground player, без буферизации; при Back флаг снимается до конца анимации. Home/возврат возобновляет игравшее видео; ранее поставленное на паузу остаётся на паузе. Ручная блокировка устройства должна работать. Не менять системный timeout/защиту ради проверки. Widget-тесты проверяют lifecycle и команды, Android E2E читает фактический флаг окна.

Device test зависит от сети и зеркала. Проверка эмулятора не заменяет аппаратный декодер физического TV. Результаты и ограничения: [Состояние проверок](06_verification.md).

---

## 6. Диагностика

| Симптом | Проверка |
| --- | --- |
| Каталог не загружается | ANISTAR_MIRROR_URL, доступность зеркала, 403/challenge или новая разметка |
| Видео не запускается | Referer, HLS formatHint, свежий player HTML и предел retry |
| 720p URL заканчивается на .mp4 | Передать VideoFormat.hls; не фильтровать ссылку по расширению |
| Приложения нет в TV launcher | Наличие LEANBACK_LAUNCHER в manifest APK |
| После device test не собирается release | Обычная build-команда без --no-pub для обновления plugin registrar |

Обновляйте соответствующее руководство при изменении пакетов, DI, HTTP/HLS, команд или управления пультом. Системное изменение фиксируйте в [ADR](adr/README.md).

Login E2E использует вымышленные кириллические credentials локального fixture. Реальный Android Secure Storage сохраняет cookies между пересозданием ProviderScope/runner; повторного POST при восстановлении нет. Проверяются неверный пароль, истечение сессии и выход. Live-проверка использует отдельный тестовый аккаунт и локальный JSON; настройка и автоматический вход описаны в разделе 9. Credentials в исходники и команды не добавляются. Результаты: [Состояние проверок](06_verification.md).


Favorites E2E хранит список в локальном HTTPS fixture, выполняет настоящий AJAX-запрос с session cookie и пересоздаёт приложение без локального списка. Проверяется изменение на другом клиенте и отказ сервера. Golden baselines фиксируют вкладки и звезду при 960×540 и 1280×720. Реальная запись избранного проверяется отдельным live-прогоном из раздела 9; результат fixture не заменяет эту проверку. Результаты: [Состояние проверок](06_verification.md).

## 7. Обновление Flutter

Локальный [anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md) обновляет stable SDK через FVM и пакеты pub workspace, затем запускает проверки и Android-сборку. Melos, iOS и CI/CD в этот workflow не входят. Текущие версии, результаты и ограничения: [Состояние проверок](06_verification.md).

## 8. Иконка и Android TV баннер

Исходники: `resources/anistar_launcher.png` (1024×1024) и `resources/anistar_tv_banner.png` (1280×720). Экспорт на macOS: `bash scripts/generate_branding.sh`. Скрипт создаёт adaptive icon с inset 18%, legacy icons 80–320 px и TV banners 160×90–640×360; xhdpi — 160×160 и 320×180 соответственно. Manifest использует `android:icon`, `android:banner` и название `AniStar TV`. Размеры и текст в баннере соответствуют [Android TV guidelines](https://developer.android.com/design/ui/tv/guides/system/tv-app-icon-guidelines).

Изображения созданы встроенным imagegen. Промпт иконки: фиолетовая падающая звезда с голубым знаком play на тёмном фоне, без текста. Промпт баннера: та же эмблема слева, белая надпись `AniStar TV` справа, формат 16:9, цвета интерфейса, без персонажей и посторонних надписей. Старые splash-ресурсы не участвуют в экспорте launcher.

## 9. Проверка с живым аккаунтом

### Проверка только сети и входа

Для диагностики проверки зеркала без изменения избранного и истории:

```bash
# Реальный Dio на компьютере; отдельные in-memory preferences/cookies:
fvm flutter test tool/diagnostics/anistar_network_test.dart --reporter=expanded
# Android: реальный runner, Riverpod, Dio и encrypted session storage:
fvm flutter test integration_test/network_smoke_test.dart -d emulator-5554 --flavor dev \
  --dart-define-from-file=env/live-test.local.json
```

Host-проверка читает локальный JSON без вывода credentials и проверяет зеркало, каталог, вход и restore. Другой путь передаётся через `--dart-define=ANISTAR_LIVE_CREDENTIALS_FILE=/absolute/path/credentials.json`. Она расположена вне offline unit suite и запускается только явно. Android smoke очищает локальную сессию выбранного зеркала, входит тестовым аккаунтом, читает каталог, пересоздаёт приложение и подтверждает restore без второго POST, затем выходит. Избранное и история на сайте не меняются.

Если host-проверка проходит, а Android сообщает недоступность зеркала, сначала проверьте DNS эмулятора: `adb -s emulator-5554 shell ping -c 1 v30.astar.bz` и аналогично `google.com`. `unknown host` для обоих означает сбой DNS окружения; потеря ICMP-пакетов после строки `PING host (IP)` сама по себе не означает недоступность HTTPS. Перезапустите AVD с доступным DNS, например `emulator -avd anistar_e2e -dns-server 8.8.4.4 -no-snapshot-load`. Это настройка эмулятора, не клиента; данные AVD не стираются. [Настройка DNS Android Emulator](https://developer.android.com/studio/run/emulator-networking-dns).

После Android integration test соберите и установите обычный dev APK с `main_dev.dart`, чтобы заменить тестовый entry point.

### Полный live-сценарий

Credentials тестового аккаунта на этом рабочем месте находятся в `env/live-test.local.json` (права `0600`, файл исключён из Git). Поля — `ANISTAR_TEST_USERNAME` и `ANISTAR_TEST_PASSWORD`. Пароль не копировать в исходники, fixtures, вывод тестов или CHANGELOG. На другом компьютере скопируйте [шаблон](../env/live-test.example.json), получите логин и пароль у владельца и заполните оба строковых поля локально. Все `env/*.local.json` исключены из Git.

```bash
# Однократная настройка на новом компьютере; существующий файл не перезаписывать:
cp -n env/live-test.example.json env/live-test.local.json
chmod 600 env/live-test.local.json
# Заполните ANISTAR_TEST_USERNAME и ANISTAR_TEST_PASSWORD в локальном JSON.

# Последующие запуски автоматически подставляют credentials:
bash scripts/e2e.sh emulator-5554 live
# Или credentials в отдельном локальном файле:
ANISTAR_LIVE_CREDENTIALS_FILE=/absolute/path/live-test.json bash scripts/e2e.sh emulator-5554 live
```

В VS Code: **Terminal → Run Task → Flutter: Live Android E2E**; укажите ID запущенного эмулятора. Задача вызывает тот же скрипт и автоматически использует локальный JSON. Дополнительный `.env`-загрузчик не нужен: как в RC Mobile, Flutter передаёт JSON через `--dart-define-from-file`, а live harness читает `String.fromEnvironment` и заполняет форму входа.

Прямой запуск без скрипта, если окружение уже подготовлено:

```bash
fvm flutter test integration_test/direct_android_test.dart -d emulator-5554 --flavor dev \
  --dart-define-from-file=env/live-test.local.json
```

Перед прогоном очищаются локальная сессия выбранного зеркала и локальные отметки аниме `10938` для тестового аккаунта; в конце выполняется logout. Используйте dev flavor и отдельный тестовый аккаунт.

Live-прогон отделён от детерминированных fixtures: он зависит от сайта/CDN и требует сеть. Он проверяет реальный вход, восстановление encrypted session без повторного POST, карточку и серии, загрузку вкладки избранного, добавление/удаление и звёздочки, native HLS и серверные галочки после перезапуска. Для просмотра выбирается ещё не отмеченная серия, если она есть; отметка подтверждается свежим player HTML. Избранное тестового аниме возвращается в исходное состояние после проверки. Начатые серии остаются отмеченными в истории тестового аккаунта: протокол снятия отметки не исследован. Не запускать параллельно другим клиентам, меняющим избранное этого аккаунта.

Credentials передаются только в integration test через `--dart-define-from-file`; не использовать этот файл при обычной/release-сборке. Integration APK содержит тестовый entry point и не предназначен для распространения. После теста соберите обычный APK командой выше.

При отказе сохранить тип сбоя и шаг, HTTP status, наличие challenge и результат восстановления; не сохранять пароль, Cookie/Set-Cookie, POST body или подписанные media URL в отчёт. Успешный Python-запрос не заменяет проверку Dart/Android. При интерактивной CAPTCHA сообщить владельцу: автоматический browser fallback не является частью клиента.
