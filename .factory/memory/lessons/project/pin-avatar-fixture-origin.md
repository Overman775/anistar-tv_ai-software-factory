---
id: pin-avatar-fixture-origin
scope: project
title: Задайте origin в фикстуре теста аватара
applies_when: После смены зеркала по умолчанию падает widget-тест аватара. Для профиля
  и активного зеркала ожидается один origin, но вместо изображения появляются инициалы.
observed: После перехода с .bz на .pw три проверки аватара упали в полном check. Фикстура
  оставляла mirror manager пустым, поэтому anistarActiveMirrorProvider брал адрес
  по умолчанию, а метаданные профиля задавали прежний origin. С явным origin в фикстуре
  прошли все 6 тестов аватара и полный набор из 922 тестов.
roles:
- implementer
- tester
- judge
tags:
- avatar
- widget
- fixture
- origin
- default-mirror
- fallback
- same-origin
- appnetworkimage
- аватара
- тест
- падает
- после
- смены
- зеркала
- по-умолчанию
- инициалы
- фикстура
allowed_case: Тест выбора зеркала по умолчанию может намеренно использовать AnistarMirrorConfig.baseUri
  через штатное поведение провайдера.
implementation: '[Widget-тесты аватара](../../../../test/app/avatar_context_test.dart)'
sources:
  run-e3f7b0bc5b8d/accept-mirrors:
  - accept:.factory/memory/workflow.sqlite3#2bd7f10010b92848a711e9434342e0fa84715838431173702a37baa2ead7402d
---
В тесте явно переопределите anistarActiveMirrorProvider нейтральным origin, например https://avatar.example/. Используйте тот же origin для метаданных совпадающего профиля и выводите из него точный URL ожидаемого изображения. Для проверки отказа задайте другой origin, например https://other.example/. Сохраните отдельные проверки несовпадения аккаунта и поколения контекста. Запустите test/app/avatar_context_test.dart и полный check.
