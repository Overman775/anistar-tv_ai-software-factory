# AniStar project checks

Use `docs/melos_tooling.md` and `docs/05_development_and_testing.md` for
commands, selector syntax and coverage. The coordinator assigns every
verification command to Tester. Serialize shared Flutter, Gradle and generator
resources. A writer can run an explicitly assigned generation step for its
owned outputs. Judge reads check evidence and requests additional execution
through the coordinator.

For a slice, select the regression and existing tests covering affected
consumers. Use a supported test path or name. Record the actual selection and
completed count. For example, a change to shared catalog/favorites state also
needs the navigation, tab switching and pull-to-refresh widget tests. A widget
test does not establish native IME behavior, and fixture results do not establish
live behavior. Live tests require their authorized scope.

For applicable application changes Tester runs the following registered Melos
commands in order after all writers finish on the integrated tree:

1. `fvm dart run melos run check`
2. `fvm dart run melos run test:e2e`
3. `fvm dart run melos run build:android:prod:apk`

The full `check` includes format checking, analyzer, DCM and tests. Schedule
standalone workspace-wide `analyze`, `dcm`, `format:check` when Dart/Flutter
changes require these checks outside that aggregate, or when an earlier check
is explicitly required. Package `--scope` does not narrow these three commands.
Record why each project gate applies. Focused results do not discharge a full
gate. Single-task runs use one final Tester assignment when it can cover all
requirements. Diagnose a failure with the smallest relevant scenario before a
full rerun on corrected bytes.

Владелец AniStar TV разрешил обновлять затронутые golden-эталоны, если изменение
соответствует ожидаемому результату задачи. Tester запускает сравнение и
возвращает диагностические PNG. Implementer проверяет наблюдаемое поведение,
diff и точные пути и применяет разрешённое изображение в своей области записи.
После этого Tester повторяет сравнение. Для полупрозрачного элемента проверить
видимость контура и фона на стабильном изображении во всех затронутых профилях
TV и mobile. Увеличение задержек и числа нажатий требует установленной причины.

Если для единственного расхождения `anistar-check` требуется расширить область
на новые эталоны, Tester возвращает `APPROVAL_REQUIRED` с действием
`update-golden-baselines`, точными путями и SHA-256 просмотренных кандидатов.
Координатор после согласования применяет одобренные PNG, вызывает
`resume-approved` и назначает новую проверку и требуемое ревью. Ошибка приложения
или теста возвращается Implementer.
