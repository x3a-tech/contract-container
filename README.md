# Contract Container

Этот репозиторий содержит Docker-контейнер для работы с протобуфами (Protocol Buffers) и gRPC. Контейнер предназначен для генерации кода на основе .proto файлов для различных языков программирования, в частности Go и TypeScript.

## Содержимое репозитория

- `Dockerfile`: Описывает многоэтапную сборку Docker-образа.
- `entrypoint.sh`: Скрипт, который выполняется при запуске контейнера.
- `.github/workflows/docker-publish.yml`: GitHub Actions workflow для автоматической сборки и публикации Docker-образа.

## Особенности Docker-образа

1. Базируется на `node:20-alpine` для легковесности.
2. Включает инструменты для работы с Go и Protocol Buffers:
   - `protoc` (Protocol Buffers compiler)
   - `protoc-gen-go` (Go plugin для protoc)
   - `protoc-gen-go-grpc` (gRPC plugin для Go)
3. Устанавливает `@protobuf-ts/plugin` для работы с TypeScript.
4. Содержит дополнительные инструменты: git, curl.

## Использование

Этот контейнер может быть использован в CI/CD пайплайнах или локально для генерации кода из .proto файлов.

### Сборка и публикация

Docker-образ автоматически собирается и публикуется в GitHub Container Registry при создании нового тега, начинающегося с 'v' (например, v1.0.0).