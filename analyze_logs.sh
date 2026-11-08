#!/usr/bin/env bash

set -euo pipefail

if [[ $# -ne 0 ]]; then
    echo "Использование: $0" >&2
    exit 1
fi

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="$SCRIPT_DIR/access.log"
COUNT=300

IPS=("192.168.1.10" "192.168.1.11" "10.0.0.5" "10.0.0.7" "172.16.0.3")
METHODS=("GET" "POST" "PUT" "DELETE")
URLS=("/api/users" "/api/login" "/api/orders" "/api/products")
CODES=(200 200 200 201 301 400 401 403 404 500 502 503)

if ! > "$LOG_FILE"; then
    echo "Ошибка: не удалось создать файл $LOG_FILE" >&2
    exit 1
fi

for ((i = 0; i < COUNT; i++)); do
    ip="${IPS[$RANDOM % ${#IPS[@]}]}"
    method="${METHODS[$RANDOM % ${#METHODS[@]}]}"
    url="${URLS[$RANDOM % ${#URLS[@]}]}"
    code="${CODES[$RANDOM % ${#CODES[@]}]}"

    printf -v timestamp '08/Nov/2026:%02d:%02d:%02d' \
        "$((10 + i / 3600))" \
        "$((i / 60 % 60))" \
        "$((i % 60))"

    if ! printf '%s - - [%s] "%s %s HTTP/1.1" %s\n' \
        "$ip" "$timestamp" "$method" "$url" "$code" >> "$LOG_FILE"; then
        echo "Ошибка: не удалось записать данные в $LOG_FILE" >&2
        exit 1
    fi
done

echo "Создан тестовый файл: $LOG_FILE"
echo

awk 'END {
    printf "Всего запросов: %d\n", NR
}' "$LOG_FILE"

echo
echo "Топ-3 IP-адреса:"

IP_REGEX='^([0-9]{1,3}\.){3}[0-9]{1,3}'

grep -Eo "$IP_REGEX" "$LOG_FILE" \
    | sort \
    | uniq -c \
    | sort -k1,1nr -k2,2 \
    | awk 'NR <= 3 {
        printf "%s — %d запросов\n", $2, $1
    }'

echo

awk '
    $NF ~ /^4[0-9]{2}$/ { errors4xx++ }
    $NF ~ /^5[0-9]{2}$/ { errors5xx++ }
    END {
        printf "Запросов с кодами 4xx: %d\n", errors4xx
        printf "Запросов с кодами 5xx: %d\n", errors5xx
        printf "Всего ошибок 4xx и 5xx: %d\n", errors4xx + errors5xx
    }
' "$LOG_FILE"
