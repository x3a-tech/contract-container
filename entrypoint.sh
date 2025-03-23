#!/bin/sh

set -e

send_telegram_notification() {
    local status=$1
    local message

     if [ "$status" = "success" ]; then
      message="✅ <b>Сборка успешно завершена!</b>
<b>Репозиторий:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}\">${GITHUB_REPOSITORY}</a>
<b>Ветка:</b> ${GITHUB_REF_NAME}
<b>Тег:</b> ${GITHUB_REF_NAME}
<b>Коммит:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}\">${GITHUB_SHA}</a>
<b>Автор:</b> ${GITHUB_ACTOR}
<b>Сообщение:</b> ${COMMIT_MESSAGE}
<b>Workflow:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\">Просмотр запуска Workflow</a>

<i>Proto файлы успешно скомпилированы и отправлены в репозиторий <a href=\"https://${GO_REPO}\">Go</a>"

        if [ -z "$EXCLUDE_TS" ]; then
            message="${message} и <a href=\"https://${TS_REPO}\">TypeScript</a>"
        fi

        message="${message}.</i>"
    else
        message="❌ <b>Ошибка сборки!</b>
<b>Репозиторий:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}\">${GITHUB_REPOSITORY}</a>
<b>Ветка:</b> ${GITHUB_REF_NAME}
<b>Тег:</b> ${GITHUB_REF_NAME}
<b>Коммит:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}\">${GITHUB_SHA}</a>
<b>Автор:</b> ${GITHUB_ACTOR}
<b>Сообщение:</b> ${COMMIT_MESSAGE}
<b>Workflow:</b> <a href=\"${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}\">Просмотр запуска Workflow</a>

<i>Пожалуйста, проверьте логи workflow для получения подробной информации об ошибке.</i>"
    fi
    curl -s -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${message}" \
        -d "parse_mode=HTML" \
        -d "disable_web_page_preview=true"
}

# Функция для выполнения команд с обработкой ошибок
execute_with_error_handling() {
    if ! "$@"; then
        send_telegram_notification "failure"
        exit 1
    fi
}

create_release() {
    local repo_url=$1
    local version=$2

    # Добавляем протокол https:// если его нет
    if [[ $repo_url != https://* ]]; then
        repo_url="https://${repo_url}"
    fi

    # Извлечение имени владельца и репозитория из URL
    local repo_owner=$(echo ${repo_url} | sed -E 's|https://github.com/||' | cut -d'/' -f1)
    local repo_name=$(echo ${repo_url} | sed -E 's|https://github.com/||' | cut -d'/' -f2 | sed 's/\.git$//')

    echo "Creating release for ${repo_owner}/${repo_name} with version ${version}"

    local response=$(curl -X POST \
      -H "Authorization: token ${REPO_PACKAGE_TOKEN}" \
      -H "Accept: application/vnd.github.v3+json" \
      -w "\n%{http_code}" \
      https://api.github.com/repos/${repo_owner}/${repo_name}/releases \
      -d '{
        "tag_name": "'"${version}"'",
        "name": "Release '"${version}"'",
        "body": "Release '"${version}"' (from proto '"${version}"')",
        "draft": false,
        "prerelease": false
      }')

    local body=$(echo "$response" | sed '$d')
    local status=$(echo "$response" | tail -n1)

    echo "Response body: $body"
    echo "Status code: $status"

    if [ "$status" != "201" ]; then
        echo "Failed to create release. Status code: $status"
        send_telegram_notification "failure"
        exit 1
    fi
}

# Компиляция Proto файлов
execute_with_error_handling mkdir -p go_out
execute_with_error_handling protoc -I src --go_out=go_out --go_opt=paths=source_relative --go-grpc_out=go_out --go-grpc_opt=paths=source_relative src/*/*.proto

if [ -z "$EXCLUDE_TS" ]; then
    execute_with_error_handling mkdir -p ts_out
    execute_with_error_handling protoc -I src --plugin=protoc-gen-ts=/usr/local/bin/protoc-gen-ts --ts_out=ts_out src/*/*.proto
fi

# Пуш Go файлов
execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${GO_REPO} go-repo
execute_with_error_handling cp -R go_out/* go-repo/
cd go-repo
execute_with_error_handling go mod tidy
execute_with_error_handling git config user.name github-actions
execute_with_error_handling git config user.email github-actions@github.com
execute_with_error_handling git add .
execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
execute_with_error_handling git push origin main --tags
create_release ${GO_REPO} ${PARENT_VERSION}
cd ..

# Пуш TypeScript файлов
if [ -z "$EXCLUDE_TS" ]; then
  execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${TS_REPO} ts-repo
  execute_with_error_handling rm -rf ts-repo/src/*
  execute_with_error_handling cp -R ts_out/* ts-repo/src
  cd ts-repo
  execute_with_error_handling git config user.name github-actions
  execute_with_error_handling git config user.email github-actions@github.com
  execute_with_error_handling npm version ${PARENT_VERSION} --no-git-tag-version
  execute_with_error_handling git add .
  execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
  execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
  execute_with_error_handling git push origin main --tags
  create_release ${TS_REPO} ${PARENT_VERSION}
  cd ..
fi

# Отправка уведомления об успешном выполнении
send_telegram_notification "success"