---
id: verify-release-apk-dart-freshness
scope: project
title: Проверьте свежесть Dart-кода в release APK
applies_when: Приложение после установки свежего release APK ведёт себя как старая
  версия, и изменения Dart-кода не видны.
observed: На Flutter 3.44 / AGP 9 Gradle повторно использовал прежний JNI merge после
  компиляции нового Dart AOT. В APK попадал старый libapp.so. В проекте для задачи
  merge…JniLibFolders отключили up-to-date.
roles:
- generalist
- developer
- judge
tags:
- apk
- release
- dart
- aot
- jni
- staging
- merge
- stripping
- старый
- код
- изменения
- установка
- сборка
allowed_case: Stripping может менять байты libapp.so относительно исходного AOT. Инкрементальная
  сборка подходит, если проверка проходит для всех ABI.
implementation: '[Команда Melos](../../../../docs/melos_tooling.md) · [Настройка Gradle](../../../../android/app/build.gradle.kts)
  · [Проверка APK](../../../../tool/quality/verify_android_apk.py) · [Регрессии](../../../../tool/quality/verify_android_apk_test.py)'
sources:
  git:f1f84dc481b9d590826cc2daa9c22d50eebaeda0/android-jni-merge:
  - user:chat/01a20dcb-388f-7aa2-9132-d03716db86b7/2026-11-24/да-давай-добавь#6b6685e5b82fc8e1793873a03bb562fec4c03c331b58b8c59ff1ba40d7484f10
---
Для готового prodRelease APK из корня проекта запустите `fvm dart run melos run check:apk --include-private`. По каждому ABI проверка сопоставляет текущий AOT с JNI staging, если он отдельный, и JNI merge, а библиотеку внутри APK сверяет с выходом стадии stripping. При ошибке проверьте указанную стадию для этого ABI. При устаревшем merge проверьте действующую настройку Gradle, пересоберите APK и повторите проверку.
