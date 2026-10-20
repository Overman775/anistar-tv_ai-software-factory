# Skills, MCP, Git hooks и Graphify

Сначала проверь существующие файлы, metadata и настройки без installers,
bootstrap или загрузки engine. Установку/обновление skills, hooks, MCP и построение
графа выполняй только после отчёта и согласия по
[SKILL.md](../SKILL.md#3-отчёт-и-обязательное-согласие), в подтверждённом составе.
Обновления описаны в [updates.md](updates.md).

## 1. Factory skills и host

Factory skills, роли и контракты входят в Git checkout. Не скачивай заново
`factory-*` из сторонних источников. Проверь `.agents/skills/*/SKILL.md`,
`.agents/agents/`, `.agents/contracts/`, `.agents/adapters/`, `.codex/agents/`
и `.claude/agents/`. В этом проекте `.claude/skills` — ссылка на `.agents/skills`.
При её восстановлении сохраняй существующие файлы и другие skills.

Для Codex проверь `.codex/config.toml`, для Claude Code — `.mcp.json`.
Текущие MCP: `fvm dart mcp-server`, `dcm start-mcp-server --client=<host>` и
Context7 по HTTPS. Они не требуют случайных глобальных npm MCP-пакетов.
Используй адаптер текущей среды. Проверь запуск/handshake и доступные tools
через штатную диагностику host. Наличие записи в config недостаточно.
Сохрани остальные MCP и настройки. Доверие проекту пользователь подтверждает
в интерфейсе host, когда оно требуется.

Внешние skill bundles игнорируются Git и отсутствуют в свежем clone.
Установи Graphify и Impeccable ниже. В полный комплект входит также `asd-ste100`:
возьми [исходный bundle](https://github.com/danyuchn/asd-ste100-skill) во временный
каталог, проверь `SKILL.md`, скопируй его вместе с `references/`, `scripts/`
и лицензией в отсутствующий `.agents/skills/asd-ste100`. Не создавай вложенный Git
репозиторий и не перезаписывай существующую изменённую копию.

После установки проверь обнаружение `$factory-install`, остальных Factory skills,
`$graphify`, `$impeccable` и `$asd-ste100` через host. Если нужен reload,
сообщи об этом; наличие файлов само по себе не доказывает discovery.

## 2. Impeccable

Сохрани рабочую установленную копию. Для новой установки прочитай текущую
[официальную инструкцию](https://github.com/pbakaus/impeccable#installation)
и `npx impeccable --help`, затем запусти installer для текущего host и project scope:

```bash
npx impeccable install --providers=codex --scope=project
```

Для Claude Code выбери `claude`; оба provider нужны, только если оба используются.
Installer может добавить design hooks. Сохрани имеющиеся manifests и проверь diff.
Не запускай UI redesign, `init`, `document` или drift repairs при установке.
Существующие `PRODUCT.md` и `DESIGN.md` принадлежат проекту.

Проверь launcher в установленной `.agents/skills/impeccable/scripts/`:

```bash
.agents/skills/impeccable/scripts/impeccable engine-probe
```

На Windows из PowerShell используй `impeccable.cmd engine-probe` с полным путём.
Launcher скачивает отсутствующий engine под ОС/CPU и проверяет SHA-256 sidecar.
В Unix проверь executable bit, `curl`/`wget` и `shasum`/`sha256sum`.
Не переноси один macOS-бинарник на Windows/Linux. Сам engine не требует Node.
При trust prompt hooks используй штатный интерфейс host; не помечай его
подтверждённым автоматически. Проверь, что engine вернул свой handshake.

## 3. Graphify: изолированная установка и producer patch

Сначала прочитай `tool/graphify/README.md` и `tool/graphify/patch-manifest.json`.
Текущая совместимая версия — `graphifyy 0.9.92`. Источник pin — manifest,
а не эта строка. Пакет называется **graphifyy**, команда — **graphify**.

На свежем компьютере:

```bash
uv python install 3.12
uv tool install --python 3.12 "graphifyy==<version-из-manifest>"
uv tool update-shell
graphify --version
```

Подставь прочитанную версию до выполнения. Проверь зависимости import и CLI
в том же окружении. Не используй `uvx graphify`: это другое имя PyPI package.
Не используй `uv tool run --from graphifyy python` для поиска установленного
interpreter: transient env может оказаться другой версии и без патча.

Обычно interpreter uv tool находится в `<uv tool dir>/graphifyy/bin/python`
на macOS/Linux, в `<uv tool dir>\graphifyy\Scripts\python.exe` на Windows.
Проверь этот путь и `import graphify; importlib.metadata.version('graphifyy')`.
При pipx/другой существующей установке найди interpreter её реального venv.
Если установлен другой Graphify, который нужен другим проектам, создай отдельный
пользовательский venv через `uv venv --python 3.12 <путь>` и установи pin через
`uv pip install --python <venv-python> graphifyy==<version>`.
Для текущего проекта используй CLI этого venv. Не делай глобальный downgrade.

Если patch ещё не применён, используй interpreter Graphify, разрешённый по
инструкциям выше, и примени его из корня проекта:

```bash
<graphify-python> tool/graphify/patch_graphify.py
```

Затем проверь инструмент и подготовь локальные sidecar и scan root:

```bash
python3 tool/graphify/prepare.py
```

Команда находит Python совместимой существующей установки и записывает
машинный путь только в ignored `graphify-out/.graphify_python`. Не копируй этот
путь между компьютерами. Новые checkout и worktree используют тот же механизм.
Если Graphify отсутствует и он не входит в подтверждённый состав, используй
`python3 tool/graphify/prepare.py --optional`: команда пропустит только отсутствие
установки. Если установленный Graphify или его конфигурация неисправны, команда
завершится ошибкой.

Из корня checkout проверь patch и regression tests:

```text
python3 tool/graphify/prepare.py --check
```

Installer требует CLI `patch` в PATH Python subprocess. Он проверяет distribution
version и SHA-256 исходников, поддерживает повторный запуск и rollback.
Не применяй patch к другой версии и не обходи проверку хешей.
При неисправной/частично patched установке восстанови только выделенный tool venv
и повтори patch. Не меняй системный Python или приложение.

## 4. Первый граф и последующие обновления

Проверь `graphify install --help`. Установи skill в текущий проект для активной среды:

```bash
graphify install --project --platform codex
```

Для Claude Code выбери поддерживаемую платформу `claude`/`windows` по host.
Installer может дополнить инструкции и hooks. Сохрани исходные правила `AGENTS.md`
и конфигурацию. Не оставляй дублирующиеся копии skill разных версий.
Прочитай установленный `SKILL.md` Graphify перед построением.

Проверь tracked `.graphifyignore` и фактический список найденных файлов. Правила
общие для clone и worktree; машинные пути хранятся только в ignored sidecar.
Исключи `.git`, FVM SDK links, `.dart_tool`, вложенные build/cache/vendor outputs,
iOS Pods/ephemeral/DerivedData, coverage, generated sources, graphify outputs,
binary assets, HLS media fixtures, private credentials и runtime artifacts.
Не исключай maintained `lib/`, `infrastructure/`, scripts, tests, docs и Factory
instructions целиком. Проверь, что traversal не следует по symlink `.fvm` во
внешний Flutter SDK.

Если граф отсутствует **или patch применён впервые**, выполни полный pipeline
из установленного skill: новый AST cache, semantic extraction документов,
merge, clustering, report и HTML. После нового patch старый AST cache
недействителен даже при том же номере версии. Сохрани существующие локальные
graph outputs перед полной пересборкой. Не используй `update` как замену первого
полного прохода и не обходи shrink guard через `--force` автоматически.

Agent-mediated pipeline использует текущую агентскую среду для semantic fragments.
Не требуй отдельный платный API key, если skill умеет такой режим.
Headless `graphify extract` без backend либо `--code-only` не подтверждает
семантический граф документов. При недоступном semantic extraction сообщи
неполноту; рабочий code graph можно сохранить как промежуточный результат.

Для уже исправленного готового графа владелец задачи выполняет один финальный
`graphify update .` после всех изменений индексируемых файлов. Другие роли могут
читать граф запросами, но не обновляют его. Если позднее меняется индексируемый
вход, владелец выполняет обновление ещё раз после последнего такого изменения.
Проверь semantic coverage документов отдельным semantic pass по installed skill:
CLI update сам по себе его не доказывает. Проверь непустой `graph.json`,
`GRAPH_REPORT.md`, `graph.html`, source locations, health и успешный query.
Покажи предупреждения целостности и неполное покрытие. Не удаляй плохие edges
вручную, чтобы выдать граф за исправный.

## 5. Git hooks

До записи проверь `git config --show-origin --get core.hooksPath`, фактический
hooks directory и его файлы. Не меняй `core.hooksPath` и custom hooks вслепую.
Сохрани существующие действия, согласуй chaining/поддерживаемую интеграцию
в пределах установки. Конфликт, который требует выбора владельца hooks,
сообщи пользователю, продолжая остальные этапы.

```bash
lefthook install
lefthook validate
graphify hook install
graphify hook status
```

Lefthook обслуживает `pre-commit`/`pre-push`, Graphify — `post-commit`,
`post-checkout`, `post-merge`, `post-rewrite`, локальный merge driver и правило
`.gitattributes`. Они должны сосуществовать.
Проверь путь interpreter, встроенный в Graphify hooks, и merge driver после
установки. Повторная установка/перемещение tool venv требует обновить эти пути.
Не запускай commit/push ради проверки hooks. Проверь `git diff --check` и итоговый
diff общих конфигураций, не откатывая пользовательские изменения.
