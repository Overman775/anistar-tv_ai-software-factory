---
id: render-labeled-detail-loading-skeleton
scope: project
title: Покажите подпись «Подробнее» на скелетоне карточки
applies_when: Во время загрузки карточки аниме «Подробнее» выглядит как приглушённая
  кнопка, а спецификация задаёт скелетон с читаемой подписью.
observed: REV-1 отклонил полупрозрачный AppButton после уточнения требования владельцем.
  Judge подтвердил заглушку, исключение ввода и стабильную геометрию на TV и телефоне.
roles:
- generalist
- developer
- test-writer
tags:
- loading
- skeleton
- details
- focus
- загрузка
- Подробнее
- приглушённая
- кнопка
- скелетон
- заглушка
- карточка
allowed_case: Отключённый AppButton подходит, когда спецификация оставляет вид кнопки
  и отключает её действие.
implementation: '[Спецификация карточки](../../../../docs/specs/12_anime_details.md)
  · [TV-регрессия](../../../../test/packages/features/anime/presentation/screens/episode_list_regression_test.dart)
  · [Mobile-регрессия](../../../../test/packages/features/anime/presentation/screens/mobile_anime_screen_test.dart)'
sources:
  run-8540f30348a7/accept:
  - accept:.factory/memory/workflow.sqlite3#d67a83dec8b8f97fd756b1b4b05535d1fd74058c65cae575e0620edbf1884568
---
Измерьте слот по готовой кнопке с текущим масштабом текста. Заполните его TvSkeletonBox и отрисуйте читаемую подпись отдельным слоем. Исключите ввод указателем, фокус и семантическое действие нажатия. В тестах проверьте поверхность, подпись, ввод и одинаковый размер слота в обоих состояниях. Проверьте затронутые TV и mobile goldens.
