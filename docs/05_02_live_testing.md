# 🌐 Live-проверки AniStar | AniStar TV

Live-проверка обращается к сайту AniStar и CDN. Запускайте её по явному поручению с отдельным тестовым аккаунтом. Для fixture E2E используйте [локальные runners](../tool/e2e/README.md).

## 1. Подготовка тестового аккаунта

Возьмите credentials у владельца и заполните `ANISTAR_TEST_USERNAME` и `ANISTAR_TEST_PASSWORD` в локальном JSON.

```bash
mkdir -p .private/credentials
chmod 700 .private .private/credentials
cp -n env/live-test.example.json .private/credentials/live-test.json
chmod 600 .private/credentials/live-test.json
```

По умолчанию используется `.private/credentials/live-test.json`. Git игнорирует `.private/` и старые `env/*.local.json`. Runner использует путь в `.private/credentials/`. Android runner передаёт JSON через Dart define, а live harness заполняет форму входа. Передавайте этот файл только live-тесту. Обычные и release-сборки используют flavor JSON. После Android integration test соберите и установите обычный dev APK с `main_dev.dart` взамен тестового.

---

## 2. Проверка только сети и входа

```bash
fvm dart run melos run test:network:live --include-private
fvm flutter test integration_test/network_smoke_test.dart -d emulator-5554 --flavor dev \
  --dart-define-from-file=.private/credentials/live-test.json
```

Запустите нужную проверку. Host использует Dio и in-memory preferences/cookies. Для другого файла при прямом запуске host-теста передайте `--dart-define=ANISTAR_LIVE_CREDENTIALS_FILE=/absolute/path/credentials.json`. Android smoke очищает локальную сессию зеркала, входит, читает каталог, проверяет encrypted restore без второго POST и выходит. Обе проверки оставляют избранное и историю сайта в прежнем состоянии.

Если host проходит, а Android сообщает об ошибке зеркала, проверьте DNS эмулятора командой `adb -s emulator-5554 shell ping -c 1 <host>` для зеркала и `google.com`. `unknown host` для обоих указывает на DNS окружения. Если имя разрешилось в IP, потеря ICMP-пакетов сама по себе не свидетельствует об отказе HTTPS. При необходимости перезапустите AVD с доступным DNS через `emulator -avd anistar_tv_e2e -dns-server 8.8.4.4 -no-snapshot-load`. [Пример настройки DNS](https://developer.android.com/studio/run/emulator-networking-dns).

---

## 3. Полный live-сценарий

Запускайте по явному поручению с отдельным тестовым аккаунтом.

Перед прогоном тест очищает локальную сессию зеркала и локальные отметки аниме `10938` для тестового аккаунта. Он проверяет вход, restore, избранное, native HLS и серверные отметки просмотра. В штатном прогоне он восстанавливает статус избранного и выходит из аккаунта. При сбое тест также пытается восстановить статус. Начатые серии остаются отмеченными в серверной истории. На время прогона исключите параллельные изменения избранного этого аккаунта.

```bash
fvm dart run melos run test:e2e:live --include-private -- emulator-5556
```

Для другого файла задайте `ANISTAR_LIVE_CREDENTIALS_FILE=/absolute/path/live-test.json`. Задача VS Code **Flutter: Live Android E2E** вызывает тот же runner для запущенного TV AVD. При подготовленном окружении возможен прямой [запуск integration test](../integration_test/direct_android_test.dart) по образцу Android smoke с тем же flavor и credentials JSON.

При отказе сохраните шаг, тип сбоя, HTTP status, наличие challenge и результат восстановления. Пароли, Cookie/Set-Cookie, POST body и подписанные media URL исключайте из логов и отчётов. При интерактивной CAPTCHA сообщите владельцу. Для подтверждения работы клиента нужна проверка Dart/Android.
