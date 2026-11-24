---
id: restore-emulator-hardware-dpad
scope: project
title: Восстановите стрелки пульта в Android TV AVD
applies_when: На эмуляторе Android TV не работают стрелки пульта в Extended Controls
  → Directional Pad, хотя через adb фокус двигается.
observed: В `anistar_e2e` при `hw.dPad=yes` и `hw.keyboard=no` команда `getevent -pl`
  показывала только устройства питания и касания. После включения клавиатуры и Cold
  Boot появилось устройство `qwerty2` со стрелками. Владелец подтвердил работу кнопок
  в панели.
roles:
- implementer
- tester
- judge
tags:
- android-tv
- emulator
- avd
- d-pad
- directional-pad
- extended-controls
- adb
- getevent
- cold-boot
- эмулятор
- стрелки
- пульт
- фокус
allowed_case: '`adb shell input keyevent` подходит для отдельной проверки реакции
  приложения на Android keyevent и обходит аппаратный ввод панели.'
implementation: '[Настройка Directional Pad](../../../../docs/05_development_and_testing.md#directional-pad-эмулятора)
  · [Тесты проверки устройств ввода](../../../../tool/e2e/emulator_input_test.py)'
sources:
  git:03eb64909448dbb60ccfc1ce0d17248420378090/docs/06_verification.md#directional-pad:
  - user:chat/01a20dcb-388f-7aa2-9132-d03716db86b7/2026-11-24/да-давай-добавь#1b8a5fb9c634b429d5a3d989c6d28465ea19310b33c4c4d9f2f9b9343f933b56
---
В `~/.android/avd/<name>.avd/config.ini` задайте `hw.dPad=yes` и `hw.keyboard=yes`. Выполните Cold Boot с сохранением данных AVD. Запустите `tool/e2e/emulator_input.py` по инструкции или проверьте через `adb shell getevent -pl`, что все четыре стрелки присутствуют на одном устройстве ввода. Нажмите стрелки и OK в самой панели и проверьте перемещение фокуса и выбор.
