#!/usr/bin/env bash

if [[ $# -ne 1 ]]; then
	echo "URL пуст"
	echo "Использование: $0 <URL>" >&2
	exit 1
fi

url="$1"

if [[ ! "$url" =~ ^https?://[^[:space:]]+$ ]]; then
    echo "Ошибка: укажите URL с http:// или https:// без пробелов." >&2
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    echo "Ошибка: curl не установлен." >&2
    exit 1
fi

if http_code=$(curl \
    --silent \
    --show-error \
    --output /dev/null \
    --write-out '%{http_code}' \
    --connect-timeout 5 \
    --max-time 15 \
    --globoff \
    "$url"); then

    if [[ "$http_code" == "200" ]]; then
        echo "API доступен"
        exit 0
    fi

    echo "API недоступен, код ответа: $http_code"
    exit 1
else
    echo "API недоступен: HTTP-ответ не получен." >&2
    exit 1
fi
