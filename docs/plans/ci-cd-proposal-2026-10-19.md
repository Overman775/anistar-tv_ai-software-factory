# 🛠️ Предложение CI/CD | AniStar TV

**Статус: предложение для выбора, не согласованный план внедрения.** Проверено
19.10.2026 по локальному `main`, commit `85c2a70`, и официальной документации.
Репозиторий: [Overman775/anistar_tv_ai](https://github.com/Overman775/anistar_tv_ai).
Private — исходное условие пользователя; целевая схема рассчитана на public.
Workflows, настройки GitHub, secrets, версии, tags и releases этим документом
не изменяются. Существующие Factory staging-планы относятся к другой работе
и не используются для этого предложения. По уточнению пользователя исследование
Android signing и скриптов RC Mobile App относится к следующей отдельной задаче;
ключи будут генерироваться позже при его присутствии. Здесь определены требования
и место подписи в pipeline, без выбора окончательной реализации signing.

## 1. Рекомендация и варианты

Начать с **GitHub Actions, standard Linux runners, PR в `main` и ручного
запуска релиза выбранного тега**. Каждый PR проходит быстрые проверки без
секретов; каждый merge — полный Android gate; публикация требует отдельного
решения владельца. Версия и CHANGELOG готовятся отдельным release PR.
GitHub Releases — основной канал APK. Fastlane, Play Store и автоматический
SemVer bump пока не нужны.

| Область | Минимальный старт — рекомендуется | Более полный вариант |
| --- | --- | --- |
| PR | Flutter checks, tooling, версия, generated diff, security | То же + fixture TV/mobile E2E и prod compilation на каждом готовом PR |
| DCM | Полный `check` на доверенном `main`; на fork PR без CI-ключа | DCM на всех PR при подтверждённой OSS-лицензии без секрета |
| `main` | `check` → обе fixture E2E → prod release compilation | То же; TV/mobile в отдельных jobs и расширенная Android API-матрица |
| Release | Версия/CHANGELOG через PR; владелец создаёт tag и запускает выпуск | Бот предлагает release PR и tag, владелец подтверждает выпуск |
| Публикация | Подписанный universal prod APK, checksum, metadata в GitHub Release | ABI APK, AAB, attestations/SBOM; Play только отдельным решением |
| Регулярные проверки | Еженедельный OSV на `main`; ручной дополнительный E2E | Nightly E2E с другим seed; дополнительные API/устройства |

Минимальный вариант сохраняет полный gate перед распространением и использует
имеющиеся инструменты. Более полный оправдан после измерений, если частые
Android-регрессии требуют обнаружения до merge. Внешние PR не должны ждать
secrets, а обычная правка документации — загрузки двух Android images.

---

## 2. Что подтверждено в проекте

| Факт | Источник и следствие для CI |
| --- | --- |
| GitHub workflows в отслеживаемых файлах отсутствуют; рабочее дерево при начале анализа чистое | `git ls-files .github`, `git status --short`; локальные tags также отсутствуют. Это не аудит удалённых tags/releases |
| Flutter `3.47.7`, Dart constraint `^3.13.0`, Melos `7.8.1` | `.fvmrc`, `pubspec.yaml`; устанавливать SDK из файла и зависимости по общему `pubspec.lock` |
| Версия приложения `1.2.0+5`; шесть пакетов отдельно не выпускаются | `pubspec.yaml`, [VCS](../vcs_guidelines.md); не применять workspace-wide `melos version` |
| `check` включает SDK/lockfile, format, analyzer, DCM, unit/widget/architecture coverage, golden comparison, Python tooling, version check | `pubspec.yaml`, [Melos](../melos_tooling.md); security, E2E, codegen drift и Android build в него не входят |
| `check:flutter` исключает DCM, tooling и version check | Для fork PR дополнить `test:tooling` и `version:check --include-private`; не называть этот профиль полным `check` |
| DCM допустим `>=1.35.2 <2.0.0`, точный CLI не закреплён | `dcm_global.yaml`; для CI выбрать конкретную совместимую версию и способ лицензирования |
| Unit-тесты используют общий корневой `test/`, seed `20261010`; goldens запускаются отдельно с concurrency 1 | `pubspec.yaml`; не запускать один набор семь раз через `melos exec` |
| Inter и MaterialIcons загружаются тестовым bootstrap | `test/support/test_bootstrap.dart`; Linux golden parity всё равно требует пробного запуска |
| Generated routes/assets хранятся в Git | `scripts/generate.sh`, [Melos](../melos_tooling.md); генерацию запускать один раз из корня и проверять diff |
| Security-команды используют Gitleaks, OSV-Scanner, локальные Semgrep rules | `scripts/security_*.sh`; Gitleaks history требует полный clone; OSV проверяет только workspace lockfile, не весь Gradle graph |
| TV и phone — один app с разными профилями; dev/prod — environment flavors | `AndroidManifest.xml`, `android/app/build.gradle.kts`; отдельные TV/mobile APK не требуются |
| TV 13 и mobile 8 fixture journeys используют native HLS, HTTPS loopback, secure storage и настоящее управление | [Наборы](../../integration_test/README.md), [runners](../../tool/e2e/README.md); unit/goldens не заменяют эти проверки |
| E2E runners ожидают уже созданные и запущенные подходящие AVD | TV и Pixel 6 / API 36 по текущему руководству; широкая phone image не заменяет TV system UI mode и D-pad |
| Gradle `9.1.0`, AGP `9.0.1`, Java 17, NDK `28.2.13676358` | `android/`; Android SDK packages и совместимые x86_64 system images уточнить пробным `sdkmanager --list`, не угадывать TV package ID |
| Release APK wrapper проверяет AOT/JNI freshness для всех ABI | `scripts/flutter_app.sh`, `tool/quality/verify_android_apk.py`; не заменять обычным `flutter build apk` |
| **Текущий release подписан debug-ключом** | `android/app/build.gradle.kts`; выпуск пользователям заблокировать до отдельной настройки подписи |
| Live может менять историю тестового аккаунта; golden update требует явного объёма | [Тестирование](../05_development_and_testing.md); оба исключить из автоматического CI |

Прочитаны `AGENTS.md`, продукт, архитектура/структура, VCS, Melos, правила
логирования, testing и E2E tooling; навигация начата с `graphify query`.
Релевантные локальные `factory-planning`/`factory-github` просмотрены как
источники границ процесса. Это сравнение вариантов, без утверждения Factory
execution seed, декомпозиции и изменения чужих staging-файлов.

**Границы проверки:** сборки, `check`, E2E и сканирование истории здесь не
запускались. Упоминание старых golden-регрессий в integration README не доказывает
их наличие сейчас. Текущие remote settings, тариф, лимит бюджета, secrets names,
удалённые tags/releases и branch protection не подтверждены: `gh repo view` и
GET Actions permissions остановились на отсутствии авторизации GitHub CLI.
Никакой аутентификации или создания токенов не выполнялось.

---

## 3. Проверки и события

Планируемые файлы — `ci.yml`, `android.yml`, `release.yml` и небольшой
`security-scheduled.yml` под `.github/workflows/`. Сейчас их создавать не нужно.
Общую подготовку сначала держать простой; reusable workflow нужен только при
появлении реального дублирования. Flutter/Gradle/codegen внутри одного checkout
всегда идут последовательно; независимые jobs получают разные checkout/output.

### PR: обязательные проверки без секретов

Событие `pull_request` в `main`, включая `synchronize` и `ready_for_review`;
проверяется merge ref с актуальной базой. Не дублировать CI событием `push` для
каждой feature-ветки. Для новой ревизии отменять старый PR run через concurrency.

1. Установить фиксированные FVM, Flutter из `.fvmrc`, JDK 17, Python 3.10+
   и версии используемых CLI. Проверить SDK, получить workspace:

   ```bash
   fvm flutter pub get --enforce-lockfile
   fvm dart run melos bootstrap --enforce-lockfile
   ```

2. `quality`: `fvm dart run melos run check:flutter`, затем
   `fvm dart run melos run test:tooling` и
   `fvm dart run melos run version:check --include-private`.
   Coverage — `coverage/lcov.info`; сначала отчёт, без произвольного порога.
3. `generated`: `fvm dart run melos run generate`, сравнить tracked generated
   outputs с checkout и обнаружить новые untracked generated files. Проверять
   после генерации также неожиданные изменения manifests/lockfile. Не коммитить
   результат из CI и не обновлять goldens.
4. `security`: полный clone и `fvm dart run melos run security` с закреплёнными
   Gitleaks/OSV/Semgrep. Findings и ошибка самого сканера дают failure; сетевой
   отказ OSV не превращается в «уязвимостей нет». Дополнительно проверять новые
   отслеживаемые local credentials/signing paths: staged hook не работает как
   такой gate в обычном чистом checkout CI. Исключение localhost fixture key
   брать из `.gitleaks.toml`, без расширения allowlist.
5. Проверять PR title по текущим Conventional Commits и реально разрешённым
   scope. Безопасно передавать title как данные, не подставлять в shell code.
   Добавить стабильный итоговый status `ci / ready`, который при `always()`
   проверяет реальные результаты всех обязательных jobs; cancelled/failure
   зависимость не должна стать зелёным итогом.

Для docs-only допустим явный narrow allowlist текстов документации. Workflow с
required status запускается всегда, а тяжёлые jobs пропускаются внутри него с
явным решением в итоговом status. Изменения `.agents/`, `.codex/`, scripts,
fixtures, SDK, dependencies и CI не считать docs-only: Python contract tests
проверяют в том числе Factory tooling. Не применять workflow-level `paths` так,
чтобы required check навсегда остался pending.

### DCM и внешние PR

DCM документирует CI credentials `DCM_CI_KEY`/`DCM_EMAIL`; официальный dcm-action
запрашивает дополнительные `checks`/`pull-requests` write permissions.
Для AniStar достаточно CLI через текущую Melos-команду, без PR-комментариев и
этих write permissions. [DCM CI](https://dcm.dev/docs/ci-integrations/github-actions/),
[лицензирование CI](https://dcm.dev/docs/getting-started/for-developers/teams-enterprise-plan/).

Рекомендуемый старт: fork PR получает перечисленный профиль без DCM; доверенный
`main` и выпуск обязаны пройти полный `check`. Это осознанная разница покрытия,
которую надо согласовать. Не передавать CI-ключ даже в PR из ветки этого же
репозитория: его код тоже может прочитать секрет. Если DCM необходим до merge,
предпочтительна подтверждённая OSS-лицензия без секрета. Поставщик описывает такую
лицензию с поддержкой forks, но выдача AniStar и актуальные условия не подтверждены.
[DCM OSS](https://dcm.dev/blog/2023/10/18/announcing-dcm-license-for-oss-projects/).
Отсутствие лицензии блокирует полный gate; `continue-on-error` для DCM не решение.

### `main`: полный Android gate

После merge и перед выпуском на одном точном commit:

```text
check → fixture TV + mobile E2E → build:android:prod:apk → freshness evidence
```

Основные команды: `fvm dart run melos run check`,
`fvm dart run melos run test:e2e`,
`fvm dart run melos run build:android:prod:apk`.
CI должен подготовить AVD и KVM, явно задать `ANDROID_HOME`, сохранить seed,
проверить TV UI mode/D-pad и phone profile. Не пересоздавать HLS media и branding
в каждом run: fixtures и Android resources уже в Git, branding использует macOS.

Для private runner с 8 GB RAM предпочтительно запускать один emulator за раз:
поднять TV → `test:e2e:tv --include-private` → остановить → поднять mobile →
`test:e2e:mobile --include-private` → собрать общий отчёт существующим
`tool/e2e/e2e_report.py`. Это эквивалент обеих fixture-частей `test:e2e`,
но требует CI orchestration. Выставить разные `ANISTAR_E2E_RUN_DIR` и агрегировать
обе платформы даже при ошибке первой. Порядок Flutter/Gradle сохраняется.
Сам `test:e2e` применять, когда оба готовых AVD помещаются в память.

Пилот должен подтвердить API 36 TV image с работающим H.264/HLS на Linux.
Если образ/decoder не подходит, это blocker E2E, а не основание выдавать phone
AVD за TV или считать успешную компиляцию успешным тестом. Отдельный
`navigation_motion_test.dart` не входит автоматически в основной fixture набор;
добавлять его для изменений renderer/motion или в расширенный профиль.

E2E run неуспешен при незавершённых native events/нуле выполненных tests.
Сохранять первое падение; не вводить безусловные reruns. Ориентиры timeout для
пилота: PR 25 min, Android gate 90 min, sign/publish по 10 min. После измерений
подстроить их; это не измеренная длительность. Для `main` можно отменять устаревшие
CI runs, но отмена не является успешным gate для соответствующего SHA.

До настройки production signing `main` может подтверждать только compilation
существующего debug-signed release. Затем нужен **явный unsigned CI build mode**:
сохранить Melos entry point и AOT freshness, адаптировать путь unsigned APK.
Обычный production release должен требовать production signing либо явно
обозначенную подготовку unsigned input для отдельного signing job. Автоматического
fallback на debug key после этой настройки быть не должно. Это будущая небольшая
доработка Gradle/wrapper с regression tests, не существующая возможность.
Unsigned handoff — предлагаемый способ изоляции ключа, который следующая signing
задача должна сравнить с подходом RC Mobile App и подтвердить либо заменить
равноценной защищённой схемой.

---

## 4. Ветки, версия и теги

Сохранить `main` и существующие `feature/`, `fix/`, `chore/`, `codex/`.
`develop` не добавлять. `release/vX.Y.Z`/`hotfix/vX.Y.Z` нужны только при настоящей
параллельной стабилизации; для первого этапа все распространяемые версии идут
из `main`. Squash merge с корректным Conventional Commit title подходит обычным PR;
правило несжатого merge стека из [VCS](../vcs_guidelines.md) сохраняется.

Предложить protection/ruleset для `main`: PR, required `ci / ready`, актуальная
база, разрешённые conversations, запрет deletion/force push. Проверку Android
до merge включить в полном варианте; в минимальном она идёт после merge и
блокирует выпуск, но не предотвращает временно красный `main`.
CODEOWNERS для CI, signing, scripts, SDK/lockfile — когда есть второй reviewer.
Для solo-владельца не требовать невозможный self-approval; обязательный чужой
review вводить после появления второго человека. Возможности branch protection
для public доступны на Free; private требуют Pro/Team/Enterprise.
[Branch protection](https://docs.github.com/en/repositories/configuring-branches-and-merges-in-your-repository/managing-protected-branches/about-protected-branches).

Источник версии — только корневой `pubspec.yaml`: `X.Y.Z+N`. Release PR меняет его
и CHANGELOG. Существующий `version:plan` делает preview; `version:set --write`
применяется только в явно порученной подготовке версии. Не вычислять production
`N` из `github.run_number`, timestamp или номера PR: они не являются единым
постоянным счётчиком приложения. Не переопределять checked-in версию build-флагами.

Tag стабильного релиза — `vX.Y.Z`, без `+N`; он точно соответствует `X.Y.Z`
корневого pubspec и конкретному SHA. Предложить tag ruleset `v*`: создавать только
владельцу/выделенному release actor, запретить update/delete. Наличие и настройку
конкретного ruleset проверить в GitHub перед внедрением. Annotated tag полезен;
подпись tag добавить, когда определён ключ владельца.

Новый распространяемый production артефакт требует растущего `N` относительно
последних распространённых выпусков, включая старые внешние APK/Play, если они
были. Форматный `version:check` этого межрелизного условия сейчас не проверяет:
понадобится отдельный CI comparator. Проверять также неуменьшение SemVer и
Android versionCode range; Play допускает максимум `2100000000`.
[Android versioning](https://developer.android.com/studio/publish/versioning).

Для простой схемы каждый **новый стабильный выпуск** получает новый `X.Y.Z`
и новый `N`: так tag однозначен. Текущие правила допускают build-only bump при
том же `X.Y.Z`, но второй GitHub Release с тем же tag так публиковать нельзя.
Если понадобятся build-only production releases или `-rc.1`, сначала отдельно
согласовать tag convention и расширить version tooling; сейчас prerelease
суффиксы отвергаются. Повторная локальная сборка не требует bump. CI preview —
debug `dev` с отдельным applicationId, SHA/run в имени; не production update.

---

## 5. Релиз и распространение

### Рекомендуемый первый процесс

1. Владелец выбирает выпуск; release PR содержит версию и проверенный CHANGELOG.
   После merge SHA обязан пройти полный gate и security.
2. Владелец создаёт `vX.Y.Z` на этом SHA и запускает `release.yml` через
   `workflow_dispatch` **из защищённого `main`**, передавая существующий tag.
   Произвольную branch/ref как источник workflow не разрешать. Validate input,
   разрешить только stable tag, разрешить tag в SHA один раз и проверить его
   принадлежность `main`. Не полагаться на зелёный статус другого commit.
3. Release workflow повторяет полный gate на tag SHA в свежем checkout без
   production secrets. При редких выпусках это проще проверки происхождения
   старых CI artifacts. Сохраняет unsigned production APK, проверенный AOT
   freshness, SHA256 и metadata текущего run. Codegen drift тоже обязателен.
4. Отдельный signing job получает только ожидаемый APK данного run и digest;
   проверяет run/SHA/имя/размер и не исполняет код из артефакта. Production key
   доступен через environment `android-release` после решения владельца.
   Заранее установленные доверенные Android tools выполняют zipalign при
   необходимости, затем apksigner, затем проверку сертификата и подписи.
   Expected certificate fingerprint — публичная фиксированная metadata.
5. Отдельный publisher job без signing key получает проверенные подписанные
   файлы текущего run и создаёт **draft GitHub Release** с explicit tag/SHA.
   Только ему нужен `contents: write`; build/sign jobs не получают право
   изменять репозиторий. Не использовать `--clobber` и не заменять assets
   опубликованного выпуска.
6. Владелец проверяет draft, делает smoke на физическом TV и телефоне именно
   этого подписанного APK, затем вручную публикует Release. Это второе решение
   о распространении, а не автоматический эффект создания tag. Впоследствии
   publish можно автоматизировать отдельным подтверждённым действием.

Release concurrency — одна общая production group без отмены активного выпуска.
Перед записью повторно проверить tag/SHA, отсутствие опубликованного release и
монотонность версии. Не рассчитывать на FIFO по нескольким dispatch: новый
кандидат не должен вытеснить или обойти более новый уже выпущенный build.
При сбое разрешать восстановление того же draft только с совпадающими SHA,
версией и digest; существующий опубликованный asset никогда не перезаписывать.
Если распространяемые bytes изменились — новая версия/build/tag. Откат продукта
выпускать следующим исправлением с большим `N`, а не двигать старый tag.

### Состав выпуска

- `anistar-tv-X.Y.Z+N-universal.apk` — один prod APK для TV и phone; universal
  избавляет пользователя от выбора ABI. Состав ABI сверить с manifest APK.
- `SHA256SUMS` для окончательных подписанных bytes, `build-info.json` с version,
  N, source SHA, run URL, Flutter/toolchain versions, certificate fingerprint.
- Release notes из проверенного CHANGELOG: изменения, известные ограничения,
  установка, необходимость переустановки при смене debug на production signer.
  Неофициальный статус приложения сохранить согласно `PRODUCT.md`.

Не публиковать integration APK, keystore, local defines, fixture request logs,
raw HTML, cookies или signed URLs. AAB нужен для Play, а не sideload. Split ABI
APK потребуют изменения freshness verifier, который сейчас ожидает в APK весь
набор скомпилированных ABI; не добавлять `--split-per-abi` вслепую.

GitHub Release assets подходят для постоянной загрузки: до 1000 assets на release,
каждый файл **меньше 2 GiB**; документация не устанавливает общий размер release
и лимит bandwidth. Это отдельный механизм от временных Actions artifacts.
[GitHub Releases](https://docs.github.com/en/repositories/releasing-projects-on-github/about-releases).
Для скачивания Actions artifacts нужен GitHub login/read access, поэтому это
не основной пользовательский канал. [Artifacts download](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/download-workflow-artifacts).

### Подпись Android: требования к следующей задаче

Описание build/sign/publisher выше — архитектурный эскиз границ доверия.
Точные Gradle properties, скрипты, перенос подхода RC Mobile App и способ выдачи
ключа выберет следующая signing задача. Сейчас ключи и secrets не создаются.

До первого публичного APK выбрать постоянный app signing key, сделать защищённую
резервную копию вне GitHub и сохранить публичный fingerprint. Base64 keystore
не является шифрованием. Keystore и его пароли хранить отдельными environment
secrets, восстанавливать только во временный файл signing job с ограниченными
правами и удалять при завершении. Не кэшировать signing workspace и не запускать
там source scripts, Gradle или произвольные third-party actions после выдачи ключа.

APK с новым signer обычно не обновит уже установленную debug-signed сборку;
перед первым выпуском выяснить, распространялись ли такие APK. Для Play отдельно
решить Play App Signing/app key/upload key: APK, подписанный только upload key,
может быть несовместим с обновлением установленной Play-версии. Не обещать
единую цепочку sideload/Play до выбора ключевой схемы.
[Android signing](https://developer.android.com/studio/publish/app-signing).

Environment protection/reviewers доступны для public на текущих GitHub plans.
В private Free environments отсутствуют; на Pro/Team private есть environments,
но required reviewers/wait timers ограничены public. Поэтому первый private
signed выпуск при отсутствии подходящей защиты лучше делать локально по явному
поручению владельца; не подменять environment review обычным repository secret.
Для solo-review не включать запрет self-review, пока нет второго release reviewer.
[Environments](https://docs.github.com/en/actions/how-tos/deploy/configure-and-manage-deployments/manage-environments).

---

## 6. Безопасность публичного CI

Предлагаемые права: workflow default `contents: read`; `persist-credentials: false`
при checkout. PR не получает signing/DCM/account secrets, write permissions или
OIDC. Только publisher — `contents: write`; только будущий attestation job —
`id-token: write`/`attestations: write`. Обычному CI не нужны PAT и GitHub App.

Внешний PR выполняет недоверенный код: только GitHub-hosted одноразовые runners,
никаких self-hosted TV/домашних машин с ключами. Для новых внешних участников
настроить approval запуска после просмотра изменений workflow/scripts; approval
не даёт права выдавать secrets. Dependabot PR обрабатывать как fork PR.
GitHub по умолчанию ограничивает fork token и не передаёт обычные secrets.
[Fork events](https://docs.github.com/en/actions/reference/workflows-and-actions/events-that-trigger-workflows).

Не применять `pull_request_target` для build/test и не строить цепочку
`workflow_run` → исполнение PR scripts или подпись PR artifacts. В privileged
контексте и artifacts, и PR title/body считаются недоверенными данными.
Минимизировать действия со secrets и источник workflow проверять независимо
от пользовательского input. Pin actions на проверенные полные commit SHA;
рассмотреть поддерживаемый GitHub workflow dependency lockfile, когда будет
выбран набор actions. Обновлять их отдельными reviewable PR. Автоматическая
маскировка логов не гарантирует сохранность преобразованных секретов.
[Secure use](https://docs.github.com/en/actions/reference/security/secure-use).

Не загружать целиком `build/e2e/`: там есть requests, logcat и Flutter errors.
Даже JUnit содержит текст исключений. Для public uploads сначала отдельный
allowlist/redaction шаг: summary metadata и очищенный JUnit; golden diffs только
для синтетических fixtures. Ограничивать размер, экранировать текст при summary,
не исполнять содержимое отчётов и не комментировать PR привилегированным ботом.
Live credentials не заводить в CI; nightly тоже использует только fixtures.

### Перед переводом в public

1. В полном clone проверить все branches/tags и историю Gitleaks; отдельно
   просмотреть tracked configs, AI/session материалы, персональные сведения,
   лицензии и ресурсы. `.gitignore` не удаляет уже записанное из истории.
   Публичный localhost fixture key — документированное узкое исключение.
2. Если обнаружены реальные credentials — отозвать/заменить их до открытия.
   Переписывание истории и удаление GitHub данных требуют отдельного решения;
   один зелёный secrets scanner не доказывает отсутствие всех чувствительных данных.
3. Просмотреть прежние Actions logs/artifacts, release assets, issues/PR attachments
   и отчёты. До открытия удалить чувствительные данные и отозвать утекшие secrets.
   После смены видимости Actions history/logs становятся публичными; GitHub также
   предупреждает об отключении push rulesets. [Visibility](https://docs.github.com/en/repositories/managing-your-repositorys-settings-and-features/managing-repository-settings/setting-repository-visibility).
4. Проверить token defaults, allowed actions, внешние PR approvals, branch/tag
   rulesets, environments и бюджет. После открытия повторно проверить их действие.
   Это действия будущего внедрения; сейчас видимость и настройки не меняются.

---

## 7. Лимиты, расходы, кэш и хранение

### Проверенные условия GitHub на 19.10.2026

| Условие | Значение |
| --- | --- |
| Public + standard GitHub-hosted runners | Бесплатное время выполнения; larger runners оплачиваются даже для public |
| Private Free / Pro / Team | Включено соответственно 2000 / 3000 / 3000 min в месяц; квота владельца аккаунта общая для его использования |
| Actions artifacts Free / Pro / Team | 500 MB / 1 GB / 2 GB включённого storage; shared pool с GitHub Packages |
| Cache | Отдельно 10 GB на репозиторий; повышение configured limit может включить платный overage |
| Private overage baseline | Linux x64 $0.006/min; Windows $0.010/min; macOS $0.062/min; jobs округляются вверх до целой минуты |
| Storage overage | Artifacts $0.25/GB-month, cache $0.07/GB-month; расчёт по времени хранения |
| Без payment method после квоты | Использование блокируется; при payment method проверить budget с остановкой, а не только alerts |

Источники: [Actions billing](https://docs.github.com/en/billing/concepts/product-billing/github-actions),
[runner pricing](https://docs.github.com/en/billing/reference/actions-runner-pricing).
Бесплатное время public не трактовать как обещание бесконечного хранилища:
GitHub отдельно документирует storage limits/allowances. В расчётах ниже public
compute равен нулю, storage и фактические настройки Billing проверяются отдельно.

Standard `ubuntu-24.04`: public 4 CPU/16 GB RAM, private 2 CPU/8 GB RAM,
14 GB SSD в обоих случаях. Linux поддерживает Android hardware acceleration.
`ubuntu-slim` имеет 1 CPU, контейнерные ограничения и 15-min timeout — не выбирать
его для Flutter/эмуляторов. Не нужны macOS/Windows CI jobs только потому, что
разработчики работают на этих ОС. [Runner specifications](https://docs.github.com/en/actions/reference/runners/github-hosted-runners).

Hosted job ограничен 6 часами; стандартная concurrency Free 20, Pro 40, Team 60
с отдельным максимумом 5 macOS jobs. Это ограничения аккаунта, а не обещание
мгновенного старта jobs. [Actions limits](https://docs.github.com/en/actions/reference/limits).
Retention по умолчанию 90 дней; допустимо public 1–90, private 1–400 дней,
с ограничениями владельца/организации. С 01.10.2026 GitHub распространяет эти
policies также на checks/workflow runs/commit statuses, поэтому длительное
release evidence хранить рядом с release metadata.
[Retention](https://docs.github.com/en/organizations/managing-organization-settings/configuring-the-retention-period-for-github-actions-artifacts-and-logs-in-your-organization).

### Оценка, а не измерение

Для сравнения условно: 60 PR runs, 20 merges, 2 releases в месяц. PR fast —
12 runner-min, полный main gate — 45, release — 55. Полный PR с Android —
47 runner-min; nightly — 40. Это сумма времени всех jobs, включая setup, а не
только время ожидания человека. Участившиеся synchronize/reruns увеличат расход.

| Схема | Условный расход/месяц | Private Free при полностью свободной квоте | Public standard compute |
| --- | --- | --- | --- |
| Минимум | `60×12 + 20×45 + 2×55 = 1730 min` | $0 за compute в этом примере | $0 |
| Полная + 30 nightly | `60×47 + 20×45 + 2×55 + 30×40 = 5030 min` | `(5030−2000)×$0.006 = $18.18` | $0 |

Не включены storage, DCM, налоги и остальное использование аккаунта. Приватный
runner слабее публичного; первый cold build/image download может быть намного
дольше. Провести 5–10 пробных runs, измерить median/p95, runner-min, cache hit и
disk peak. Задать budget stop до включения расписаний. Временная параллелизация
TV/mobile ускоряет ответ, но дублирует setup и не обязательно экономит минуты.

### Политика хранения

PR: coverage и очищенные summaries 7 дней; golden diffs/очищенная диагностика
падения 7 дней. Private Free начать с 3 дней и размерного лимита. Preview dev APK
делать только вручную, хранить 3 дня; не загружать APK на каждый PR/merge.
Временные release handoff artifacts — 1 день после передачи; public Release
assets и их metadata — постоянно. Не удалять опубликованные APK плановой чисткой.

Например, 100 MB на 20 ежедневных runs × 7 дней = примерно 14 GB текущих artifacts;
они превысят private Free 500 MB. Upload только нужных небольших файлов, short
retention и ограничения объёма важнее числа workflow files. Удаление прекращает
дальнейшее начисление storage, но не отменяет уже накопленное за месяц.

### Кэширование

Раздельные keys для OS/arch, Flutter SDK revision из `.fvmrc`, lockfile,
Gradle wrapper/AGP/JDK. Сначала SDK downloads, pub cache и Gradle dependency
downloads; не кэшировать `build/`, `.dart_tool/`, Android intermediates,
`local.properties`, keystores, credentials, integration APK или release outputs.
Не давать двум механизмам одновременно сохранять один Gradle cache.

PR — restore-only, публикация cache — доверенный `push main`; даже такой cache
не содержит secrets, поскольку fork может читать cache базовой ветки. Signing
job вообще без cache. Release build получает зависимости из доверенных
downloads или exact-key dependency cache, а не произвольные outputs PR.
GitHub изолирует PR merge-ref caches от base branch, но эта изоляция не делает
безопасным выполнение PR artifacts в privileged job.
[Cache access](https://docs.github.com/en/actions/reference/workflows-and-actions/dependency-caching).

AVD cache сначала не включать: два images + SDK/Gradle легко создадут eviction
и disk pressure. После измерений допустим отдельный ключ system image revision,
emulator version/CPU/profile и sanitized snapshot без пользовательских данных.
Наличие cache никогда не заменяет SDK/profile/version проверки. Сохранять
возможность успешного cold run. Локальный `graphify-out/` в CI не восстанавливать;
его optional regression suite вынести в отдельный tooling-maintenance job при
необходимости, не делать скрытой сетевой установкой в каждом PR.

---

## 8. Автоматизация и этапы внедрения

1. **Решения и пилот среды.** Выбрать вариант, DCM и канал доставки; проверить
   реальные remote settings/billing. Подтвердить Linux golden parity, TV/mobile
   API 36 images, KVM/HLS, SDK/Gradle packages, свободный диск. Golden mismatch
   расследовать; baseline не обновлять без отдельного запроса. Если нужен macOS
   golden job, оценить его отдельно, сохранив Android на Linux.
2. **PR CI без секретов.** Добавить только read-only checks из раздела 3,
   проверить safe fork PR, docs-only, codegen drift, deliberate failure/cancel,
   lockfile mismatch, scanner outage и отсутствие утечки в artifacts. После
   успешного пилота сделать `ci / ready` обязательным через settings.
3. **Полный main Android gate.** Включить DCM, TV/mobile и обычную prod compilation;
   зафиксировать измерения времени/storage. E2E/renderer regressions должны
   реально останавливать выпуск. Настроить weekly OSV на доверенном main.
4. **Подпись и первый draft.** После отдельного исследования RC Mobile App
   согласовать реализацию signing. Ключ генерировать позже при присутствии
   пользователя по его поручению; сделать backup, убрать debug fallback,
   добавить согласованный handoff и signer,
   fail-closed проверки fingerprint/version/tag. Пройти весь цикл до draft,
   протестировать установку и обновление на TV/phone; только затем публикация.
5. **Расширение по данным.** Если нужно, перенести E2E на каждый PR в отдельных
   jobs, добавить motion/API profiles, attestation для public, затем release PR
   automation. Live и Play остаются отдельными явными решениями.

Первый этап automation версий — ручной release PR поверх имеющегося Python
tooling. Второй — бот, который предлагает bump и CHANGELOG, без auto-merge и
самостоятельного выпуска. Release Please допустим только после проверки его
работы с корневым `X.Y.Z+N`: conventional SemVer сам по себе не ведёт Android N.
Semantic Release на каждом merge сейчас усложнит подпись, версию и ручной smoke.
Fastlane имеет смысл при реальном Play track/promotions, не для одного GitHub APK.

Не строить будущую автоматику на предположении «tag, созданный `GITHUB_TOKEN`,
запустит push workflow»: GitHub подавляет такие повторные события; explicit
dispatch/reusable workflow или одна цепочка надёжнее. Для выбранного ручного
старта пользовательский tag и dispatch не требуют дополнительного bot token.
[Workflow triggers](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow).

### Решения владельца перед внедрением

| Решение | Рекомендуемое значение |
| --- | --- |
| Где E2E обязательны | На `main` и при release; до merge — после пилота при необходимости |
| DCM | Подтвердить OSS-лицензию; пока отдельный полный gate на trusted main без передачи ключа в PR |
| Канал публикации | GitHub Releases, universal prod APK; Play/AAB отложить |
| Подпись и существующие установки | Постоянный ключ + внешняя backup; уточнить наличие APK с debug/другой подписью |
| Управление версиями | Release PR + root `X.Y.Z+N`, tag `vX.Y.Z`, без автоматического bump на каждый merge |
| Кто принимает выпуск | Владелец; draft → physical smoke → publish; второй reviewer только при наличии человека |
| Тариф и budget | Проверить текущий plan и общий остаток; standard Linux, stop budget до расписаний |
| Открытие репозитория | Отдельное действие владельца после аудита истории/logs/assets и проверки правил |

Для анализа блокирующих решений нет. Для внедрения пока не подтверждены remote
settings/billing, DCM entitlement, Linux/AVD пилот и production key strategy.
Это будущие входные условия, а не утверждение о неуспешных тестах проекта.
