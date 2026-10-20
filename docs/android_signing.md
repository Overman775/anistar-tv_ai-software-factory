# 🔐 Android-подпись | AniStar TV

Production APK собирается локально с постоянным ключом AniStar TV. Команда сборки
проверяет сертификат, идентификатор приложения и версию перед успешным завершением.
Общие Android-команды описаны в
[руководстве Melos](melos_tooling.md#4-запуск-приложения-и-сборка-android).

## 1. Локальная production-сборка

Сборка production APK по умолчанию использует локальную конфигурацию Gradle.
Запускайте команду из корня проекта:

```bash
fvm dart run melos run build:android:prod:apk
```

Gradle по умолчанию читает приватный файл
`.private/signing/key.properties` внутри корня проекта. Разместите keystore
`release.jks` рядом с ним. Относительный `storeFile` разрешается от каталога
properties-файла, поэтому эту конфигурацию можно переносить вместе с проектом.
Файл использует четыре стандартных поля:

```properties
storeFile=release.jks
storePassword=<store-password>
keyAlias=<key-alias>
keyPassword=<key-password>
```

`ANISTAR_ANDROID_SIGNING_PROPERTIES` может указать другой абсолютный путь к
properties-файлу за пределами checkout. Внешний `storeFile` может быть абсолютным
или относительным к каталогу этого properties-файла. Локальная конфигурация
внутри проекта разрешена только в `.private/`; весь каталог `.private/` исключён
из Git. Установите права `0700` для `.private/` и `.private/signing/`, а права
`0600` — для `key.properties` и keystore. Владелец ключа создаёт и заполняет эти
файлы локально.

Gradle загружает credentials только для явного production release build. Режим
`unsigned` отключает production signing config; Android по-прежнему подписывает
debug builds SDK debug key, а dev release остаётся unsigned. Debug и dev-команды
не читают production credentials. Отсутствующий или неверный local signing input
завершает production APK сборку ошибкой. Production release не использует debug key.

## 2. Проверка APK и сборка без production credentials

Production APK-команда проверяет свежесть AOT/JNI, затем запускает
`tool/signing/android_signing.py`. Проверка сверяет единственный SHA-256 сертификат
подписанта с доверенным публичным pin в `android/signing-certificate.json`, а также
проверяет `applicationId`, версию из корневого `pubspec.yaml` и release-флаги
`debuggable`/`testOnly`.

Для локальной проверки compilation без production credentials используйте отдельную команду:

```bash
fvm dart run melos run build:android:prod:apk:unsigned
```

Она сохраняет AOT/JNI freshness check и проверяет APK metadata и отсутствие
production-подписи. Результат этой команды не является готовым production-релизом.

Сборка App Bundle использует тот же Gradle signing contract, когда выбран
production release mode. Текущая проверка pin использует `apksigner` и применяется
к APK; wrapper не запускает её для AAB. Отдельная проверка или выпуск AAB здесь
не описаны.

## 3. Ключ, резервная копия и обновление приложения

Локальная сборка использует постоянный production key. Существующая зашифрованная
резервная копия остаётся без изменений. Отдельно сохраняйте данные, нужные для
восстановления доступа. После восстановления разместите keystore и
`key.properties` в `.private/signing/`. Если восстановленный properties-файл
содержит старый абсолютный `storeFile`, замените его на `release.jks`. Установите
права `0700` для `.private/` и `.private/signing/`, а `0600` для файлов. До
использования проверьте, что восстановленный ключ соответствует публичному pin.
Запись восстановления храните в `.private/signing/RECOVERY-PRIVATE.txt`.

Production APK и `prod` debug APK имеют одинаковый `applicationId`, но используют
разные сертификаты. Android отклонит production APK как обновление такой
debug-сборки. APK можно собрать и проверить до решения о переустановке. Если
владелец выберет переустановку, удаление приложения сотрёт его локальные данные.
Dev flavor имеет отдельный `applicationId` с суффиксом `.dev`.
