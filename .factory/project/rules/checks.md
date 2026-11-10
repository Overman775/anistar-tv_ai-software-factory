# AniStar project checks


Read current project command definitions in `docs/melos_tooling.md` and
`docs/05_development_and_testing.md`. For Dart changes run sequentially:

```bash
fvm dart run melos run analyze
fvm dart run melos run dcm
fvm dart run melos run format:check
```

These are workspace-wide; package `--scope` does not narrow them. Developer may
run preflight. Slice review runs assigned applicable static checks; the final
integration Judge runs this read-only triplet after all writers.
In solo Generalist owns both passes as needed; never call it independent review.
When no Dart/Flutter changes exist, record `NOT_APPLICABLE` with evidence/reason.

Focused tests: `fvm flutter test "<test_path>" --reporter=failures-only`, or
`fvm dart run melos run test:unit`. Full project completion retains the applicable
sequence `fvm dart run melos run check` → `fvm dart run melos run test:e2e` →
`fvm dart run melos run build:android:prod:apk`. TestWriter (or Generalist) runs
slice tests; Developer (or Generalist) builds when needed to verify that slice.
For final integration, assign Judge a command-capable `verify` node with
the complete project test/build/static set, followed by its `review` node and
coordinator acceptance. This same independent reviewer may perform both stages;
it must not be a product author. A single-task run uses the same final verification
assignment when full project gates apply. No extra Generalist is required.
Do not repeat full-project gates for each slice unless project policy requires it.
Keep mandatory slice checks; assign run-wide gates explicitly to final integration.
Serialize all Flutter/Gradle/codegen and
common gates, including commands requested by reviewers. Live tests and golden
updates require explicit scope. Do not replace missing Flutter/APK with Python
fixtures. Parent checks commands against project rules before accepting evidence.


Diagnostic constraints: do not increase sleeps, timeouts or D-pad presses without evidence. A widget test cannot prove native IME behavior; fixture success cannot prove live behavior.

При расхождении golden судья запрашивает `update-golden-baselines` только если
в журнале `anistar-check` подтверждено, что требуется исключительно согласование
эталонов. Вернуть `APPROVAL_REQUIRED` по общему контракту отчёта Implement. Если проверка выявила обычную ошибку или причина неоднозначна, действует
обычная коррекция. Для каждого кандидата фиксируются путь и SHA-256 просмотренного
PNG. Согласование может добавить точные пути из каталогов `test/**/goldens/`
в область задачи. После явного согласования
координатор применяет только согласованные PNG и вызывает `resume-approved`.
Повторяются все обязательные проверки, затем независимое ревью.
