# 🖼️ Widget-тесты и goldens | AniStar TV

Используйте widget-тесты для фокуса, жестов, геометрии и lifecycle, а полноэкранные goldens для сравнения вида экрана. [Выбор проверок и общий gate](05_development_and_testing.md).

## 1. Widget-тесты TV и телефона

Хелперы [pumpTvApp и pumpMobileApp](../test/support/test_app.dart) используют тему выбранного профиля и `ProviderScope`. Параметры viewport, DPR, масштаба текста и анимаций задаёт [TestAppViewport](../test/support/test_app_viewport.dart). Для TV доступны 960×540 по умолчанию и `wideTvSize` 1280×720. Проверяйте переходы у виджетов через события пульта и проверяйте focus после возврата.

---

<a id="общие-профили-полноэкранных-golden"></a>

## 2. Общие профили полноэкранных golden

[GoldenProfile](../test/support/golden_profile.dart) использует DPR 1. `tv` — 960×540, `phonePortrait` — 360×800, `phoneLandscape` — 800×360. По умолчанию текст масштабируется до 100%. `GoldenTextScale.large` задаёт мобильный текст 200% при том же размере окна. ТВ-текст 130%, повышенный DPR, переполнение и focus проверяйте целевыми widget-тестами.

Передайте подготовленный экран и его зависимости в [`testScreenGolden`](../test/support/test_app.dart). В примере ниже тест использует эталон `goldens/mobile_anime_ready.phonePortrait.largeText.png` рядом с собой.

```dart
await testScreenGolden(
  tester,
  'mobile_anime_ready',
  screen: animeFixture,
  profile: GoldenProfile.phonePortrait,
  textScale: GoldenTextScale.large,
  overrides: animeOverrides,
);
```

Для нескольких снимков одной сцены используйте `pumpScreenGolden` и `expectScreenGolden`. Выбирайте существующий профиль по раскладке. Полные примеры есть в [тестах каталога](../test/packages/features/catalog/presentation/screens/catalog_screen_golden_test.dart) и [мобильной карточки](../test/packages/features/anime/presentation/screens/mobile_anime_screen_test.dart).

---

## 3. Проверка и обновление эталонов

Сравнение точное, SDK и шрифты закреплены. Скройте shimmer через `MediaQuery.disableAnimations` для статичного скелетона и проверьте завершение анимаций через `pumpAndSettle`. Обновляйте только эталоны для ожидаемых изменений в рамках задачи. Для обновления выполните `fvm dart run melos run test:goldens:update -- <path>`. Просмотрите PNG и diff, затем повторите `fvm dart run melos run test:goldens`. [Селекторы и отчёты](melos_tooling.md#2-проверки-и-тесты). Визуальные состояния и CSS viewport прототипа описаны в [визуальной системе](specs/11_visual_system.md).
