# 🔐 Android-подпись | AniStar TV

Production APK подписывается постоянным ключом AniStar TV. Android application ID — `com.anistar.tv`, dev — `com.anistar.tv.dev`. Namespace `com.anistar.anistar_tv` и MethodChannel сохраняются. Установка прежнего приложения с другим ID хранит данные отдельно. [Сборки Melos](melos_tooling.md#4-запуск-приложения-и-сборка).

## 1. Локальная production-сборка

Владелец ключа размещает `release.jks` рядом с `.private/signing/key.properties` и локально заполняет четыре поля по образцу.

```properties
storeFile=release.jks
storePassword=<store-password>
keyAlias=<key-alias>
keyPassword=<key-password>
```

Gradle разрешает относительный `storeFile` от каталога properties-файла. Для внешнего properties-файла задайте абсолютный путь через `ANISTAR_ANDROID_SIGNING_PROPERTIES`. Внутри checkout оба файла разрешены только в `.private/`, который исключён из Git. Задайте права `0700` для каталогов `.private/` и `.private/signing/`, `0600` для properties и keystore.

```bash
fvm dart run melos run build:android:prod:apk
```

Запускайте из корня. Для подписанного prod release оставьте `ANISTAR_ANDROID_SIGNING_MODE` незаданным или задайте `local`. При неверной или отсутствующей конфигурации сборка завершается ошибкой. Debug использует SDK debug key. Dev release и прямой Gradle запуск по умолчанию остаются unsigned.

---

## 2. Проверка APK и сборка без production credentials

После сборки wrapper проверяет свежесть AOT/JNI и запускает [проверку подписи](../tool/signing/android_signing.py). Она сверяет SHA-256 единственного сертификата подписанта с доверенным публичным [pin](../android/signing-certificate.json), а также проверяет application ID, версию из корневого pubspec и флаги `debuggable` и `testOnly`.

Для локальной проверки compilation без ключа запустите unsigned сборку.

```bash
fvm dart run melos run build:android:prod:apk:unsigned
```

Команда проверяет свежесть AOT/JNI, metadata и отсутствие подписи. Готовый production-релиз требует подписанного APK. Production App Bundle использует тот же Gradle signing contract. Wrapper с `apksigner` проверяет pin только для APK.

---

## 3. Ключ, резервная копия и обновление приложения

Доступ к зашифрованной резервной копии ключа храните отдельно. После восстановления поместите keystore и `key.properties` в `.private/signing/`. Замените старый абсолютный `storeFile` на `release.jks`, восстановите права из раздела 1 и проверьте соответствие публичному pin. Запись восстановления храните в `.private/signing/RECOVERY-PRIVATE.txt`.

Prod debug и production APK имеют одинаковый application ID и разные сертификаты. Android отклонит такое обновление. Соберите и проверьте APK до решения о переустановке. Удаление прежней установки сотрёт её локальные данные.
