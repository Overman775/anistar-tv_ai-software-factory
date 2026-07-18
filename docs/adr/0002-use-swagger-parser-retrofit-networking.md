# 🧭 ADR-0002: Swagger Parser, Retrofit и core networking

> **Статус:** принято 19 июля 2026 года. Уточняет ADR-0001.

## 1. Контекст

Первый OpenAPI-клиент был сгенерирован OpenAPI Generator с `built_value`. Он работал, но отличался от принятого в mobile-app подхода и содержал собственную обвязку Dio внутри generated package.

## 2. Решение

1. Пакет `api/` генерируется Swagger Parser из `openapi/anistar.openapi.json`.
2. Endpoints создаются как Retrofit-клиенты, DTO — как Freezed/JSON-модели.
3. Единственный Dio строится в `core/network/DioClient`; generated API не задаёт timeout, retry и interceptor.
4. `core/network/HttpClient` остаётся отдельным адаптером для запросов вне OpenAPI-контракта.
5. Генерация воспроизводится командой `bash tool/generate_api.sh`.

## 3. Последствия

**Положительные:** одинаковый подход с mobile-app, прозрачный Dio lifecycle, простые mockable Retrofit-клиенты в репозиториях.

**Ограничения:** generated-код нельзя менять вручную; после изменения схемы обязательно запускаются generator, `fvm dart analyze api` и приложение тесты.
