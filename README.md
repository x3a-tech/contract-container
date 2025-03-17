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


### Использование в CI/CD
```yaml
 - name: Сборка .proto файлов, пуш репозитории и отправка уведомления в Telegram
   env:
     REPO_PACKAGE_TOKEN: ${{ secrets.REPO_PACKAGE_TOKEN }}
     PARENT_VERSION: ${{ github.ref_name }}
     TELEGRAM_BOT_TOKEN: ${{ secrets.TELEGRAM_CICD_BOT_TOKEN }}
     TELEGRAM_CHAT_ID: ${{ secrets.TELEGRAM_CICD_BOT_CHAT_ID }}
     GITHUB_SERVER_URL: ${{ github.server_url }}
     GITHUB_REPOSITORY: ${{ github.repository }}
     GITHUB_REF_NAME: ${{ github.ref_name }}
     GITHUB_REF_TYPE: ${{ github.ref_type }}
     GITHUB_SHA: ${{ github.sha }}
     GITHUB_ACTOR: ${{ github.actor }}
     GITHUB_RUN_ID: ${{ github.run_id }}
     COMMIT_MESSAGE: ${{ github.event.head_commit.message }}
   run: |
     docker run --rm \
       -e GO_REPO=${{ env.GO_REPO }} \
       -e TS_REPO=${{ env.TS_REPO }} \
       -e REPO_PACKAGE_TOKEN \
       -e PARENT_VERSION \
       -e TELEGRAM_BOT_TOKEN \
       -e TELEGRAM_CHAT_ID \
       -e GITHUB_SERVER_URL \
       -e GITHUB_REPOSITORY \
       -e GITHUB_REF_NAME \
       -e GITHUB_REF_TYPE \
       -e GITHUB_SHA \
       -e GITHUB_ACTOR \
       -e GITHUB_RUN_ID \
       -e COMMIT_MESSAGE \
       -v ${{ github.workspace }}:/app \
       ${{ env.DOCKER_IMAGE }}
```