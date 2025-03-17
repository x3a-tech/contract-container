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

<i>Proto файлы успешно скомпилированы и отправлены в репозитории <a href=\"https://${GO_REPO}\">Go</a> и <a href=\"https://${TS_REPO}\">TypeScript</a>.</i>"
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

# Компиляция Proto файлов
execute_with_error_handling mkdir -p go_out ts_out
execute_with_error_handling protoc -I src --go_out=go_out --go_opt=paths=source_relative --go-grpc_out=go_out --go-grpc_opt=paths=source_relative src/*/*.proto
execute_with_error_handling protoc -I src --plugin=protoc-gen-ts=/usr/local/bin/protoc-gen-ts --ts_out=ts_out src/*/*.proto

# Пуш Go файлов
execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${GO_REPO} go-repo
execute_with_error_handling cp -R go_out/* go-repo/
cd go-repo
execute_with_error_handling git config user.name github-actions
execute_with_error_handling git config user.email github-actions@github.com
execute_with_error_handling git add .
execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
execute_with_error_handling git push origin main --tags
cd ..

# Пуш TypeScript файлов
execute_with_error_handling git clone https://${REPO_PACKAGE_TOKEN}@${TS_REPO} ts-repo
execute_with_error_handling rm -rf ts-repo/src
execute_with_error_handling cp -R ts_out/* ts-repo/src
cd ts-repo
execute_with_error_handling git config user.name github-actions
execute_with_error_handling git config user.email github-actions@github.com
execute_with_error_handling npm version ${PARENT_VERSION} --no-git-tag-version
execute_with_error_handling git add .
execute_with_error_handling git commit -m "Update from proto repo ${PARENT_VERSION}" --allow-empty
execute_with_error_handling git tag -a ${PARENT_VERSION} -m "Release ${PARENT_VERSION} (from proto ${PARENT_VERSION})"
execute_with_error_handling git push origin main --tags

# Отправка уведомления об успешном выполнении
send_telegram_notification "success"