# 🧪 Разработка и тестирование | AniStar TV

Команды запускайте из корня проекта. Сначала выберите проверку по изменённому контракту, затем выполните применимый gate.

| Что проверить | Как проверить |
| :--- | :--- |
| Протокол, восстановление после отказа и native runtime на Android TV и телефоне | [Fixture E2E](#5-интеграционные-тесты-android-tv-телефона-и-ios-simulator) на локальном HTTPS/HLS. |
| <a id="tv-layout"></a> Фокус, события пульта, жесты и раскладку | [Widget-тесты TV и телефона](05_01_widget_and_golden_tests.md#1-widget-тесты-tv-и-телефона). |
| <a id="общие-профили-полноэкранных-golden"></a> Вид экрана | [Goldens с общим профилем TV или телефона](05_01_widget_and_golden_tests.md). Обновляйте только ожидаемые изменения, проверяйте PNG и diff, повторяйте сравнение. |
| <a id="9-проверка-с-живым-аккаунтом"></a> Реальный сайт или CDN | Live требует явного поручения и отдельного тестового аккаунта. <a id="проверка-только-сети-и-входа"></a>[Smoke](05_02_live_testing.md#2-проверка-только-сети-и-входа) проверяет сеть и вход. <a id="полный-live-сценарий"></a>[Полный Android-сценарий](05_02_live_testing.md#3-полный-live-сценарий) также проверяет native HLS, меняет избранное с восстановлением статуса при успехе и оставляет отметки в серверной истории. |

<a id="flavors"></a>

## 1. Окружение и запуск

Установка FVM, подготовка workspace и варианты сборки описаны в [справочнике Melos](melos_tooling.md#1-подготовка-и-быстрый-запуск). Debug/profile включает файловые логи и просмотрщик из каталога. Release пишет только ошибки в системный output.

<a id="7-обновление-flutter"></a>

Используйте [anistar-flutter-update](../.agents/skills/anistar-flutter-update/SKILL.md). Точный SDK закреплён в [.fvmrc](../.fvmrc), зависимости — в [pubspec.lock](../pubspec.lock). При конфликте проверяйте ограничения SDK и resolver до изменения зависимостей.

<a id="8-иконка-и-android-tv-баннер"></a>
<a id="8-иконка-android-tv-баннер-и-заставки-androidios"></a>

Запускайте общий [экспорт ресурсов Melos](melos_tooling.md#5-генерация-и-ресурсы) на macOS. Он сохраняет TV launcher/banner и safe splash Android, создаёт iOS AppIcon и LaunchScreen. Исходные PNG и их назначение описаны в [UI Kit](../lib/packages/ui_kit/README.md#4-ресурсы), точные размеры и параметры экспорта — в [wrapper](../scripts/generate_branding.sh).

---

## 2. Проверки и сборка

Завершайте изменения кода последовательным прогоном трёх команд.

```bash
fvm dart run melos run check
fvm dart run melos run test:e2e
fvm dart run melos run build:android:prod:apk
```

Flutter, Gradle и генерация используют общий output. Дождитесь завершения каждой команды перед следующей. После integration test собирайте обычной APK-командой с pub lifecycle, чтобы обновить plugin registrar для нужного build mode и entry point. Для production APK нужна [локальная подпись](android_signing.md).

Точечный тест можно выполнить через `fvm flutter test <path> --reporter=failures-only`. Состав `check`, селекторы, отчёты и команды генерации есть в [Melos](melos_tooling.md#2-проверки-и-тесты). При изменениях iOS отдельно соберите оба Simulator debug flavor по [справочнику сборки](melos_tooling.md#4-запуск-приложения-и-сборка).

<a id="проверки-безопасности"></a>

Отдельные команды и условия запуска перечислены в [руководстве по Git hooks и проверкам безопасности](git_hooks_and_security.md#3-проверки-безопасности).

---

## 3. Структура тестов

<a id="пример-bloc-теста-с-fake-repository"></a>

Корневой [test/](../test/) повторяет пути исходников. Для pub workspace-пакетов опускайте `lib/src`. Например, `infrastructure/networking/lib/src/base_repository.dart` соответствует `test/infrastructure/networking/base_repository_test.dart`. Пример проверок переходов с fake repository есть в [тестах CatalogBloc](../test/packages/features/catalog/presentation/bloc/catalog_bloc_test.dart).

[Bootstrap каждого test isolate](../test/support/test_bootstrap.dart) настраивает logger, загружает локальные Manrope, MaterialIcons и SVG app icons, запрещает внешний HTTP. Используйте [fixtures и fakes](../test/mocks/) для HTTP, репозиториев и native video. Для проверки логирования передавайте capturing logger. Освобождайте подписки, таймеры, BLoC и контроллеры в teardown.

<a id="4-что-тестируем"></a>

Unit-тесты покрывают преобразование данных, переходы состояний и обработку ошибок. Architecture/DI проверяют границы зависимостей и runtime bindings.

---

<a id="5-e2e-и-smoke-на-android-tv"></a>
<a id="5-интеграционные-тесты-android-tv-и-телефона"></a>

## 5. Интеграционные тесты Android TV, телефона и iOS Simulator

Android `test:e2e` выполняет полные fixture suites на двух разных AVD, TV затем mobile. Он запускает mobile и после отказа TV. Заранее запустите `anistar_tv_e2e` (Android TV API 36) и `anistar_mobile_e2e` (Pixel 6 API 36) либо укажите существующие AVD по [инструкции runners](../tool/e2e/README.md#запуск-runners). TV требует TV hardware profile и TV system image. Оба набора используют dev flavor, определяют профиль нативно и работают с реальным viewport.

<a id="tv-сценарии"></a>
<a id="мобильные-сценарии"></a>

[Интеграционные наборы](../integration_test/README.md) описывают entry points, покрытие TV/mobile и отдельный тест нативного TV renderer. [E2E tooling](../tool/e2e/README.md) описывает селекторы, HTTPS/HLS fixtures, очистку окружения и отчёты. Успешный выборочный Android E2E имеет `scope=filtered` и `PARTIAL PASS`.

[iOS fixture E2E](../tool/e2e/README.md#ios-fixture-e2e) опционален и запускается отдельно на запущенном Simulator. Runner добавляет локальный fixture CA в выбранный Simulator и оставляет его там. Профиль `tv` предназначен для диагностики раскладки на iPad Simulator.

<a id="directional-pad-эмулятора"></a>

Аппаратный ввод проверяйте в панели Directional Pad. [Настройка AVD и preflight](../tool/e2e/README.md#directional-pad-эмулятора).

### Ручной smoke

На устройстве проверьте TV launcher, читаемость и плавность, ввод с пульта, focus и возврат из панелей, а также native HLS, seek, паузу, смену качества/серии и выход из плеера. Для ошибок входа используйте локальный HTTPS fixture. Проверьте фоновый переход и ручную блокировку, сохранив системные настройки защиты и timeout. Контракты по шагам есть в [TV-взаимодействии](specs/06_tv_interaction.md), [воспроизведении](specs/04_playback.md) и [мобильном взаимодействии](specs/10_mobile_interaction.md).

---

## 6. Диагностика

| Симптом | Проверка |
| :--- | :--- |
| Каталог не загружается, HLS не стартует | Зеркало, HTTP/Referer, формат и refresh по [сетевому руководству](04_network_and_playback.md) |
| Приложения нет в TV launcher | `LEANBACK_LAUNCHER` в manifest APK |
| После device test не собирается release | Повторите обычную build-команду без `--no-pub` |

---

## 10. Результаты и границы проверки

Указывайте в отчёте проверенный diff или revision, команды, exit codes, выполненные сценарии и пропуски. Укажите SDK, устройство и seed, если они влияют на результат. Для передаваемого APK добавьте путь и SHA-256. Историю прогонов храните в отчётах задачи и build-артефактах.

- Fixture покрывает заданный протокол и отказы. Live подтверждает работу AniStar/CDN для конкретного зеркала, IP и момента проверки.
- Эмулятор подтверждает native runtime. Аппаратный декодер, физический пульт, читаемость и плавность требуют проверки на устройстве.
- Подтверждение iOS Keychain restore и native HLS требует отдельного iOS fixture E2E. Поддержка физических Apple-устройств, iPad и tvOS не заявлена.
- Fixture отказ и refresh проверяют восстановление. Естественное истечение подписанной ссылки проверяйте отдельно.
- Restore после перезапуска и миграция с предыдущей версии Secure Storage требуют отдельных проверок.
- Прогон относится к проверенным исходникам и конфигурации. После изменений укажите уровни, выполненные заново.
