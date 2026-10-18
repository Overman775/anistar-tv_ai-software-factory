# 🧪 Разработка и тестирование | AniStar TV

Команды выполняются из корня проекта через [Melos](melos_tooling.md). Низкоуровневые scripts остаются доступны для диагностики.

Unit/widget и architecture tests используют fixtures и fakes для проверки изолированной логики. Android E2E проверяет production runner с локальными HTML/HLS и настоящим Android player. Live smoke отдельно обращается к AniStar/CDN. Выбирайте минимальный уровень, который покрывает изменённый контракт. Запускайте live-проверку только явно.

## 1. Окружение и запуск

Нужны **FVM**, Flutter **3.47.7** из `.fvmrc`, Dart **3.13.5**, JDK **17**, Android SDK и устройство/эмулятор.

Для Android E2E-скриптов нужен Python **3.10 или новее**. Melos автоматически выбирает доступный совместимый interpreter. Override задайте через `ANISTAR_PYTHON`. Для прямых scripts настройте PATH. Их tooling использует аннотации `str | None`, несовместимые с системным Python 3.9.

```bash
fvm install
fvm flutter pub get --enforce-lockfile
fvm dart run melos bootstrap --enforce-lockfile
fvm dart run melos run run:dev
```

`env/dev.json` хранится в Git. Для собственного production-зеркала скопируйте `env/prod.example.json` в `env/prod.json`. Git игнорирует этот файл. Default зеркало работает без файла defines.

### Flavors

| Flavor | Entry point | Назначение |
| --- | --- | --- |
| dev | `lib/main_dev.dart` | Разработка, отдельный Android application ID |
| prod | `lib/main_prod.dart` | Основное приложение |

Debug/profile сохраняет диагностические логи и открывает viewer из каталога. Release пишет только ошибки в системный output. Файловый output и viewer отключены. Это зависит от build mode, а не имени flavor.

VS Code использует `.fvm/flutter_sdk`. Launch и tasks находятся в `.vscode/`. Dart/DCM настроены в `analysis_options.yaml`. Активный код находится в `lib/` и `infrastructure/`. Generated sources и build outputs исключены из анализа приложения.

---

## 2. Проверки и сборка

Полная локальная проверка:

```bash
fvm dart run melos run check
```

Порядок: SDK и lockfile → форматирование → analyzer → DCM → unit/widget/architecture с coverage → golden comparison → Python tooling → version check. Ошибка останавливает команду и возвращает ненулевой exit code. Форматирование и baselines при проверке не изменяются.

| Режим | Команда |
| --- | --- |
| Форматирование | `fvm dart run melos run format` |
| Только проверка формата | `fvm dart run melos run format:check` |
| Analyzer / DCM | `fvm dart run melos run analyze` / `fvm dart run melos run dcm` |
| Unit/widget и coverage | `fvm dart run melos run test:unit` |
| Golden comparison | `fvm dart run melos run test:goldens` |
| Обновить golden baseline | `fvm dart run melos run test:goldens:update` |
| Быстрые Flutter-проверки без DCM | `fvm dart run melos run check:flutter` |

DCM нужен для полной локальной проверки. Допустимая версия указана в `dcm_global.yaml`. Analyzer считает infos ошибкой. Все workspace-пакеты наследуют корневой `analysis_options.yaml`.

Проверки выполняются локально. CI/CD не настроен. Режим `ci` оставлен как короткий профиль без DCM. Он запускает format, analyzer, unit coverage и goldens. Для полного прогона используйте `check`.

Coverage сохраняется в `coverage/lcov.info`. Различия golden сохраняются рядом с тестом в `failures/`.

По умолчанию порядок тестов задаёт seed **20261010**. Чтобы задать другой seed, используйте `ANISTAR_TEST_SEED=1337 fvm dart run melos run test:unit`. При необходимости задайте путь установленного SDK через `ANISTAR_FLUTTER_SDK`. Версия всё равно сверяется с `.fvmrc`.

Запускайте Flutter-команды последовательно: они используют общий generated output. Живой Android-сценарий выполняется отдельно от детерминированных проверок.

```bash
# E2E на запущенном Android emulator
fvm dart run melos run test:e2e:tv -- emulator-5554

# Постер Hero покадрово на Android, без сети и аккаунта
fvm flutter test integration_test/navigation_motion_test.dart -d emulator-5554 --flavor dev

# Живой AniStar/CDN smoke
fvm dart run melos run test:e2e:live -- emulator-5554

# APK приложения
fvm dart run melos run build:android:dev:apk:debug
fvm dart run melos run build:android:prod:apk
```

APK находятся в `build/app/outputs/flutter-apk/`. Release использует существующую тестовую подпись. Перед публикацией настройте собственный signing config.

После integration test запускайте обычную APK-команду с pub lifecycle, чтобы plugin registrar соответствовал build mode и entry point.

Перед завершением изменения кода обязателен последовательный gate: `check` → fixture `test:e2e` → production APK build. Запускайте все три команды из корня и дожидайтесь завершения каждой перед следующей:

```bash
fvm dart run melos run check
fvm dart run melos run test:e2e
fvm dart run melos run build:android:prod:apk
```

Этот gate не запускает live аккаунт и не обновляет golden baselines. Live и golden update требуют отдельного явного объёма работ.

В прежнем Flutter 3.44 / AGP 9 наблюдался устаревший JNI merge после изменения
Dart-кода. Защита в app Gradle сохранена: up-to-date для этой стадии копирования отключён. Проверка
APK сравнивает текущие AOT libraries с отдельным JNI staging Flutter 3.47, JNI merge и содержимым архива после stripping. Набор ABI также должен совпадать.
Её регрессии запускаются через `python3 -m unittest discover -s tool/quality -p '*_test.py'`.
Запускайте эту проверку локально после release-сборки.

Изменение typed routes, ассетов или списка шрифтов UI Kit требует генерации из корня workspace:

```bash
fvm dart run melos run generate
```

FlutterGen настроен в `lib/packages/ui_kit/pubspec.yaml`. Он создаёт `lib/src/generate/assets.gen.dart` и `fonts.gen.dart`. Публичный импорт: `package:ui_kit/assets.dart`. Этот файл также экспортируется через `ui_kit.dart`.

Используйте `Assets.images.anistarLauncher.image(...)` и `FontFamily.inter`. При ручном создании Image/AssetImage передавайте `package: Assets.package`. FontFamily.inter уже содержит пакетный префикс. TvTypography использует его напрямую. Generated-файлы сохраняются в Git. Не редактируйте их вручную.

---

## 3. Структура тестов

Тесты повторяют структуру исходников. Для workspace-пакетов сегменты lib/src опускаются:

| Исходник | Тест |
| --- | --- |
| `infrastructure/networking/lib/src/base_repository.dart` | `test/infrastructure/networking/base_repository_test.dart` |
| `lib/packages/features/catalog/presentation/screens/catalog_screen.dart` | `test/packages/features/catalog/presentation/screens/catalog_screen_test.dart` |
| `lib/packages/ui_kit/lib/src/widgets/tv_focusable.dart` | `test/packages/ui_kit/widgets/tv_focusable_test.dart` |

Fixtures и fakes находятся в `test/mocks/`. HTTP заменяется adapter, репозитории fake-реализациями, native player fake platform. Unit/widget-тесты не обращаются к сайту.

`test/flutter_test_config.dart` вызывает общий bootstrap из `test/support/`: тестовый logger, локальные Inter/Material Icons и запрет создания настоящего HttpClient. Проверки HTTP используют fixture adapter. Проверки логирования передают capturing logger явно.

`pumpTvApp` задаёт production theme, ProviderScope и TV viewport. Свойства view сбрасываются после теста. Fake video platform восстанавливает прежний platform instance. Тесты также покрывают bootstrap, разбор Dart directives и остановку quality gate.

Регрессионные тесты проверяют поздние ответы и refresh логов, смену параметров
маршрута, выход во время native initialization, ошибки команд плеера, ручной
retry пагинации, redaction подписанного URL и закрытие файлового logger.
Ошибка startup возвращается из runApplication. Runtime errors остаются в guarded zone.

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

Тесты защищают ветвления, контракт и исправленные баги. Coverage включает приложение и workspace-пакеты. Цель 100% не установлена.

Golden PNG хранятся рядом с тестами в `goldens/`. Обновляйте их только после просмотра изменений UI. Проверяются каталог и вкладки, ошибки/пустые состояния, вход, loading каталога и карточки, длинные названия и описание.

Скелетоны в снимках статичны через `MediaQuery.disableAnimations`. `pumpAndSettle` проверяет отсутствие продолжающегося shimmer в этом режиме. Сравнение точное. Шрифты и SDK закреплены.

### TV layout

Используйте общий helper из `test/support/test_app.dart`:

```dart
await pumpTvApp(tester, const TvFocusableExample(), size: wideTvSize);
await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
await tester.sendKeyEvent(LogicalKeyboardKey.select);
expect(tester.takeException(), isNull);
```

Размер по умолчанию: **960×540**, `wideTvSize`: **1280×720**, DPR: **1**. ProviderContainer освобождается в tearDown/addTearDown. Подписки, timers и controllers не должны переживать тест.

### Пример BLoC-теста с fake repository

Для изолированной логики используйте fake вместо HTTP и native player. Такой шаблон применяется в `test/packages/features/catalog/presentation/bloc/catalog_bloc_test.dart`:

```dart
final repository = FakeCatalogRepository();
final bloc = CatalogBloc(repository: repository, logger: Logger());
final stream = bloc.stream;
addTearDown(bloc.close);

bloc.add(const CatalogStarted());
await expectLater(stream, emitsInOrder([isA<CatalogLoading>(), isA<CatalogReady>()]));
```

Этот тест проверяет переходы BLoC, не сетевую совместимость. Adapter contract и Android playback требуют своих отдельных уровней из таблицы выше.

---

<a id="5-e2e-и-smoke-на-android-tv"></a>

## 5. Интеграционные тесты Android TV и телефона

Используются два отдельных существующих AVD. Запустите их через Device Manager или `fvm flutter emulators --launch <avd>`. Команды находят запущенный экземпляр по имени AVD и проверяют его системный профиль. Команды используют dev flavor с закреплённым SDK/lockfile. Они не выбирают первый попавшийся эмулятор. Широкое окно телефона не считается TV.

| Платформа | AVD по умолчанию | Набор | Запуск |
| --- | --- | --- | --- |
| TV | `anistar_tv_e2e`: Android TV API 36 | `integration_test/app_e2e_test.dart` | `bash scripts/e2e-tv.sh` |
| Телефон | `anistar_mobile_e2e`: Pixel 6, Android API 36 | `integration_test/mobile_e2e_test.dart` | `bash scripts/e2e-mobile.sh` |
| Обе платформы | Два разных устройства | TV, затем mobile, с отдельным результатом каждого | `bash scripts/e2e-all.sh` |

Если нужны другие существующие AVD, задайте `ANISTAR_TV_AVD` / `ANISTAR_MOBILE_AVD`. Для конкретного запущенного экземпляра передайте `emulator-<port>` аргументом соответствующему скрипту. Скрипты не создают и не стирают AVD. Если нужное устройство отсутствует, скрипт показывает доступные экземпляры и команду запуска. В VS Code есть отдельные задачи **Flutter: TV E2E**, **Flutter: Mobile E2E**, **Flutter: TV and Mobile E2E**.

Оба набора запускают настоящий runner с нативным определением профиля и реальным viewport эмулятора. Тесты не принуждают UI к TV/mobile-профилю или условному размеру. Так тест обнаруживает ошибку выбора интерфейса или системного поворота. TV-набор проверяет D-pad/focus и правые панели. Телефонный набор использует touch, нижние панели и фактический поворот Android. Unit/widget/golden проверки искусственных размеров и текста 200% остаются отдельным уровнем.

### TV-сценарии

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

Fixtures в `tool/e2e/` обслуживает loopback HTTPS server. `adb reverse` соединяет server с эмулятором. Server проверяет Referer на master, nested playlist и TS. Он также поддерживает Range. Синтетическое H.264/AAC видео длится 24 секунды и имеет варианты 360p/720p.

Repository, parser, router, storage и video platform не подменяются. Test bootstrap задаёт только logger и доверие Dart transport к localhost certificate.

Native Android доверяет этому certificate через debug resources только для `localhost`. Тестовый private key публичный и используется лишь fixture server. В release этого доверия нет. Media fixtures не включены в assets приложения.

Порядок E2E задаёт seed 20261010. Для другого порядка используйте `ANISTAR_TEST_SEED=1337 bash scripts/e2e-all.sh`. Каждое ожидание имеет deadline. Каждый запуск получает собственный fixture server, HTTP/state, reverse-соединение и каталог отчётов. Команда завершает server, снимает своё reverse-соединение и восстанавливает immersive confirmation setting.

Общий запуск выполняет наборы последовательно. Это исключает конфликты Flutter/Gradle и общего APK output. Сбой TV не скрывает результат mobile.

Логи и отчёты сохраняются в `build/e2e/<platform>-<mode>-seed-<seed>-<avd>.<suffix>/`. Общий запуск сохраняет их в `all-seed-…/tv/` и `mobile/`. `summary.json` содержит устройство, AVD, seed, этап и exit code. `junit.xml` содержит отдельные native cases. Отказ preflight тоже даёт ошибку в отчёте.

Flutter JSON events сохраняются рядом для диагностики. Общий запуск объединяет summary и JUnit обеих платформ.

Для TV-прогона нужны **TV hardware profile и TV system image** (`android-tv` или `google-tv`). На Apple Silicon требуется ARM64. Профиль `tv_1080p` и широкое разрешение не превращают обычный Google Play image в Android TV. Приложение определяет роль через Android UiModeManager. `scripts/e2e.sh` проверяет текущий системный режим до сборки. TV fixture дополнительно проверяет нативный resolver.

Live smoke запускается явно и зависит от сети. Физический пульт и аппаратный декодер TV проверяются отдельно.

Локальный TV AVD: `anistar_tv_e2e`, API 36 `android-tv/arm64-v8a`. Телефонный AVD: существующий `anistar_mobile_e2e`, Pixel 6, `google_apis_playstore/arm64-v8a`. Ранее созданный `anistar_e2e` имеет обычный phone image. Поэтому он сообщает mobile, несмотря на TV hardware skin. Его данные сохранены. D-pad для mobile не требуется.

Пример запуска TV AVD:

```bash
"$ANDROID_HOME/emulator/emulator" -avd anistar_tv_e2e -no-snapshot-load
bash scripts/e2e.sh <emulator-id> fixtures
```

### Мобильные сценарии

Отдельные тесты покрывают сенсорный вход, зашифрованное восстановление сессии и её истечение. Они проверяют прокрутку и скрытие шапки, нижние вкладки и Back, пагинацию и обновление свайпом. Также проверяются жанры и сортировка, панели избранного и пустой список, ошибки и ручной повтор, native HLS, качество и паузы, поворот и освобождение плеера. Набор использует реальные размеры выбранного phone AVD. Изменение ориентации не должно переводить телефон в TV-профиль.

Низкоуровневые команды сохранены для совместимости: `bash scripts/e2e.sh <tv-emulator> fixtures` и `bash scripts/e2e.sh <phone-emulator> fixtures-mobile`. Live-прогон с реальным аккаунтом остаётся отдельным TV-запуском: `bash scripts/e2e-tv.sh live`. Общий offline-прогон его не включает.

### Directional Pad эмулятора

Для `Extended Controls → Directional Pad` в профиле AVD нужны оба параметра:

```ini
hw.dPad=yes
hw.keyboard=yes
```

В Emulator 36.4.10 / API 36 при `hw.keyboard=no` отсутствовал kernel keyboard device: крестовина не передавала стрелки, хотя `adb shell input keyevent` и Flutter `sendKeyEvent` работали. После изменения `~/.android/avd/<name>.avd/config.ini` выполните **Cold Boot** через Device Manager или запустите `emulator -avd <name> -no-snapshot-load`. Данные приложения сохраняются; Wipe Data не нужен.

`scripts/e2e.sh` до запуска Flutter проверяет наличие четырёх стрелок на одном hardware input device через `getevent -pl`. Отдельный запуск проверки:

```bash
python3 tool/e2e/emulator_input.py --adb "$ANDROID_HOME/platform-tools/adb" --device emulator-5556
```

Проверка устройства не заменяет ручное нажатие стрелок и OK в самой панели. Синтетические Flutter-события проверяют focus приложения, но обходят эту часть эмулятора. [Документация Extended Controls](https://developer.android.com/studio/run/emulator-extended-controls).

### Ручной smoke

1. Приложение видно в TV launcher. Focus понятен и перемещается стрелками.
2. Каталог открывает карточку и серии. Короткое OK срабатывает один раз. Первый системный KeyRepeat удерживаемого OK открывает действие до отпускания. Оставшиеся repeat/release не активируют панель повторно.
3. 720p и 360p запускаются. Seek и пауза работают.
4. Смена качества сохраняет позицию. Смена серии начинает с нуля.
5. Back закрывает player без Flutter exceptions и оставшихся системных панелей.
6. Добавление и удаление видны на сайте под тем же аккаунтом. Вкладка и звезда обновляются после подтверждения.
7. Повторите несколько переходов Главная/Избранное. Меню не исчезает и не перезапускает раскрытие. Во время загрузки содержимого меню сохраняет фокус на выбранном пункте. Откройте жанры, нажмите Back и проверьте прежний пункт. В пустом избранном фокус остаётся на пункте левого меню. Up + OK возвращают главную. Right ведёт к карточкам или действию пустого экрана. Back из detail возвращает к той же карточке.
8. Правая панель длинного списка сразу показывает текущую серию. Стрелки прокручивают строки. Back отменяет выбор. Следующее OK управляет плеером.
9. После двух отказов входа подряд focus возвращается в очищенный пароль. Up возвращает в логин для редактирования. Down ведёт через пароль к «Войти». Up с кнопки ведёт обратно через оба поля. Проверьте удержание Up/Down и Left/Right для курсора. Проверьте «Далее» и «Готово» экранной клавиатуры, а также дополнительную кнопку проверки сессии. Используйте локальный HTTPS fixture без реального аккаунта.
10. Нажмите Left с первой карточки любого ряда. Левое меню должно открыться и показать главную, избранное, жанры, выход из аккаунта и логи (debug/profile). Up/Down перемещают фокус. Right и Back сворачивают меню и возвращают прежнюю карточку. Без фокуса видны только иконки. Раскрытие не меняет число колонок. Учитывается системное уменьшение анимаций. Долгое OK открывает панель действий при первом системном KeyRepeat до отпускания. Back закрывает её без изменения избранного и возвращает фокус на карточку.
11. В плеере Up фокусирует стрелку возврата к сериям. OK возвращает список. Down ведёт к шкале времени, затем к нижнему ряду: воспроизведение, −10 секунд, +10 секунд, предыдущая/следующая серия, выбор серии и качества. На шкале Left/Right перематывают. В ряду кнопок Left/Right перемещают фокус. Up с кнопок возвращает на шкалу. Down ведёт к видео. Во время воспроизведения управление скрывается после 4 секунд бездействия даже при фокусе на кнопках или шкале. Системный Back отменяет диалог. Следующий Back закрывает плеер.
12. Проверьте экран при play → pause → resume, завершении серии, отказе потока, смене качества/серии и нескольких возвратах в каталог. `FLAG_KEEP_SCREEN_ON` удерживается только у играющего foreground player, без буферизации. При Back флаг снимается до конца анимации. Home/возврат возобновляет игравшее видео. Ранее поставленное на паузу видео остаётся на паузе. Ручная блокировка устройства должна работать. Не меняйте системный timeout/защиту ради проверки. Widget-тесты проверяют lifecycle и команды. Android E2E читает фактический флаг окна.

Device test зависит от сети и зеркала. Проверка эмулятора не заменяет аппаратный декодер физического TV. Границы выводов: [результаты и ограничения проверки](#10-результаты-и-границы-проверки).

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

Login E2E использует вымышленные кириллические credentials локального fixture. Реальный Android Secure Storage сохраняет cookies между пересозданием ProviderScope/runner; повторного POST при восстановлении нет. Проверяются неверный пароль, истечение сессии и выход. Live-проверка использует отдельный тестовый аккаунт и локальный JSON; настройка и автоматический вход описаны в разделе 9. Credentials в исходники и команды не добавляются.


Favorites E2E хранит список в локальном HTTPS fixture, выполняет настоящий AJAX-запрос с session cookie и пересоздаёт приложение без локального списка. Проверяется изменение на другом клиенте и отказ сервера. Golden baselines фиксируют вкладки и звезду при 960×540 и 1280×720. Реальная запись избранного проверяется отдельным live-прогоном из раздела 9; результат fixture не заменяет эту проверку.

---

## 7. Обновление Flutter

Локальный [anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md) обновляет stable SDK через FVM и пакеты pub workspace, затем запускает проверки и Android-сборку. Melos служит общей точкой запуска проверок и генерации; iOS и CI/CD в этот workflow не входят. Точная версия Flutter закреплена в `.fvmrc`, разрешённые версии пакетов указаны в корневом `pubspec.lock`.

При обновлении учитывайте зависимости, закреплённые SDK: `flutter_test` ограничивает совместимые версии тестового стека, а вместе с ним и analyzer с codegen. Новая версия на pub.dev не всегда совместима с текущим workspace; проверяйте `pub outdated` и конкретный конфликт resolver. Не добавляйте overrides только ради перехода на latest. Итог обновления сообщайте в отчёте задачи; руководства меняйте при изменении правил работы.

---

<a id="8-иконка-и-android-tv-баннер"></a>

## 8. Иконка, Android TV баннер и заставка

Назначение исходных PNG, прозрачность UI-знака и safe area splash описаны в [ресурсах UI Kit](../lib/packages/ui_kit/README.md#4-ресурсы). Экспорт на macOS: `fvm dart run melos run generate:branding`. Скрипт создаёт adaptive icon с inset 18%, legacy icons 80–320 px и TV banners 160×90–640×360; размеры для xhdpi: 160×160 и 320×180 соответственно. Manifest использует `android:icon`, `android:banner` и название `AniStar TV`. Размеры и текст в баннере соответствуют [Android TV guidelines](https://developer.android.com/design/ui/tv/guides/system/tv-app-icon-guidelines).

Этот же скрипт обновляет заставку по `flutter_native_splash.yaml` и восстанавливает safe drawable в обеих темах. Используйте общий wrapper, чтобы повторная генерация сохранила размеры TV-ресурсов и безопасные отступы заставки. Все команды: [Melos tooling](melos_tooling.md#генерация-и-обслуживание).

---

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

Если host-проверка проходит, а Android сообщает недоступность зеркала, сначала проверьте DNS эмулятора: `adb -s emulator-5554 shell ping -c 1 v30.astar.bz` и аналогично `google.com`. `unknown host` для обоих означает сбой DNS окружения; потеря ICMP-пакетов после строки `PING host (IP)` сама по себе не означает недоступность HTTPS. Перезапустите используемый AVD с доступным DNS, например `emulator -avd anistar_tv_e2e -dns-server 8.8.4.4 -no-snapshot-load`. Это настройка эмулятора, не клиента; данные AVD не стираются. [Настройка DNS Android Emulator](https://developer.android.com/studio/run/emulator-networking-dns).

После Android integration test соберите и установите обычный dev APK с `main_dev.dart`, чтобы заменить тестовый entry point.

### Полный live-сценарий

Для полного сценария нужен локальный `env/live-test.local.json` с правами `0600`; файл исключён из Git. Поля: `ANISTAR_TEST_USERNAME` и `ANISTAR_TEST_PASSWORD`. Пароль не копировать в исходники, fixtures, вывод тестов или CHANGELOG. Создайте файл из [шаблона](../env/live-test.example.json), получите логин и пароль отдельного тестового аккаунта у владельца и заполните оба строковых поля локально. Все `env/*.local.json` исключены из Git.

```bash
# Однократная настройка на новом компьютере; существующий файл не перезаписывать:
cp -n env/live-test.example.json env/live-test.local.json
chmod 600 env/live-test.local.json
# Заполните ANISTAR_TEST_USERNAME и ANISTAR_TEST_PASSWORD в локальном JSON.

# Последующие запуски автоматически подставляют credentials:
bash scripts/e2e-tv.sh live
# Или credentials в отдельном локальном файле:
ANISTAR_LIVE_CREDENTIALS_FILE=/absolute/path/live-test.json bash scripts/e2e-tv.sh live
```

В VS Code: **Terminal → Run Task → Flutter: Live Android E2E**; выбирается запущенный `ANISTAR_TV_AVD` / `anistar_tv_e2e`. Задача вызывает тот же скрипт и автоматически использует локальный JSON. Дополнительный `.env`-загрузчик не нужен: Flutter передаёт JSON через `--dart-define-from-file`, а live harness читает `String.fromEnvironment` и заполняет форму входа.

Прямой запуск без скрипта, если окружение уже подготовлено:

```bash
fvm flutter test integration_test/direct_android_test.dart -d emulator-5556 --flavor dev \
  --dart-define-from-file=env/live-test.local.json
```

Перед прогоном очищаются локальная сессия выбранного зеркала и локальные отметки аниме `10938` для тестового аккаунта; в конце выполняется logout. Используйте dev flavor и отдельный тестовый аккаунт.

Live-прогон отделён от детерминированных fixtures: он зависит от сайта/CDN и требует сеть. Он проверяет реальный вход, восстановление encrypted session без повторного POST, карточку и серии, загрузку вкладки избранного, добавление/удаление и звёздочки, native HLS и серверные галочки после перезапуска. Для просмотра выбирается ещё не отмеченная серия, если она есть; отметка подтверждается свежим player HTML. Избранное тестового аниме возвращается в исходное состояние после проверки. Начатые серии остаются отмеченными в истории тестового аккаунта: протокол снятия отметки не исследован. Не запускать параллельно другим клиентам, меняющим избранное этого аккаунта.

Credentials передаются только в integration test через `--dart-define-from-file`; не использовать этот файл при обычной/release-сборке. Integration APK содержит тестовый entry point и не предназначен для распространения. После теста соберите обычный APK командой выше.

При отказе сохранить тип сбоя и шаг, HTTP status, наличие challenge и результат восстановления; не сохранять пароль, Cookie/Set-Cookie, POST body или подписанные media URL в отчёт. Успешный Python-запрос не заменяет проверку Dart/Android. При интерактивной CAPTCHA сообщить владельцу: автоматический browser fallback не является частью клиента.

---

## 10. Результаты и границы проверки

Результаты конкретного запуска сообщайте в итоговом отчёте задачи: проверенный diff или revision, команды и exit codes, выполненные сценарии и пропуски, SDK, устройство и seed, если они влияют на результат. Логи, JUnit/JSON и APK остаются build-артефактами; для передаваемого APK укажите путь и SHA-256 в отчёте. В руководствах сохраняйте правила и команды, а в CHANGELOG записывайте существенные изменения проекта. Не накапливайте в документации историю прогонов, счётчики тестов и хеши сборок.

- Fixture проверяет заданный протокол и отказы. Live smoke отдельно подтверждает работу сайта/CDN для конкретного зеркала, IP и момента проверки.
- Эмулятор с native player не подтверждает аппаратный декодер, физический пульт, читаемость и плавность на реальном TV или телефоне. Для этих выводов нужна отдельная проверка на устройстве.
- Воспроизведённый fixture отказ и refresh не подтверждают естественное суточное истечение подписанной ссылки. Эти сценарии различайте в отчёте.
- Restore Secure Storage после перезапуска не подтверждает миграцию с предыдущей версии storage/backend. При обновлении хранилища проверяйте установленную старую версию отдельно от чистой установки.
- Пройденная проверка относится к проверенным исходникам и конфигурации. После изменений указывайте, какие уровни выполнены заново; прежний прогон не становится свежим автоматически.
