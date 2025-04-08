#!/bin/sh

set -e

send_discord_notification() {
    local status=$1
    local message

    if [ "$status" = "success" ]; then
        message='{
            "embeds": [
                {
                    "title": "✅ Сборка успешно завершена!",
                    "color": 3066993,
                    "fields": [
                        {
                            "name": "Репозиторий",
                            "value": "['${GITHUB_REPOSITORY}']('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}')"
                        },
                        {
                            "name": "Ветка",
                            "value": "'${GITHUB_REF_NAME}'"
                        },
                        {
                            "name": "Тег",
                            "value": "'${GITHUB_REF_NAME}'"
                        },
                        {
                            "name": "Коммит",
                            "value": "['${GITHUB_SHA}']('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}')"
                        },
                        {
                            "name": "Автор",
                            "value": "'${GITHUB_ACTOR}'"
                        },
                        {
                            "name": "Сообщение",
                            "value": "'${COMMIT_MESSAGE}'"
                        },
                        {
                            "name": "Workflow",
                            "value": "[Просмотр запуска Workflow]('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}')"
                        },
                        {
                            "name": "Статус",
                            "value": "Proto файлы успешно скомпилированы и отправлены в репозиторий [Go](https://'${GO_REPO}')"
                        }
                    ]
                }
            ]
        }'
        
        if [ -z "$EXCLUDE_TS" ]; then
            message=$(echo "$message" | sed 's/репозиторий \[Go\]"/репозиторий [Go](https:\/\/'${GO_REPO}') и [TypeScript](https:\/\/'${TS_REPO}')"/')
        fi
        
        message=$(echo "$message" | sed 's/"Статус"/"Статус",\n"inline": false/')
    else
        message='{
            "embeds": [
                {
                    "title": "❌ Ошибка сборки!",
                    "color": 15158332,
                    "fields": [
                        {
                            "name": "Репозиторий",
                            "value": "['${GITHUB_REPOSITORY}']('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}')"
                        },
                        {
                            "name": "Ветка",
                            "value": "'${GITHUB_REF_NAME}'"
                        },
                        {
                            "name": "Тег",
                            "value": "'${GITHUB_REF_NAME}'"
                        },
                        {
                            "name": "Коммит",
                            "value": "['${GITHUB_SHA}']('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${GITHUB_SHA}')"
                        },
                        {
                            "name": "Автор",
                            "value": "'${GITHUB_ACTOR}'"
                        },
                        {
                            "name": "Сообщение",
                            "value": "'${COMMIT_MESSAGE}'"
                        },
                        {
                            "name": "Workflow",
                            "value": "[Просмотр запуска Workflow]('${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/runs/${GITHUB_RUN_ID}')"
                        },
                        {
                            "name": "Подробности",
                            "value": "Пожалуйста, проверьте логи workflow для получения подробной информации об ошибке."
                        }
                    ]
                }
            ]
        }'
    fi
    
    curl -s -H "Content-Type: application/json" -X POST -d "$message" "${DISCORD_WEBHOOK}"
}

# Функция для выполнения команд с обработкой ошибок
execute_with_error_handling() {
    if ! "$@"; then
        send_discord_notification "failure"
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
        send_discord_notification "failure"
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
send_discord_notification "success"
