# infra-monitoring-project

Мониторинг доступности API, генерация и анализ access-логов, запуск echo-сервиса с Nginx через Docker Compose и автоматические проверки GitHub Actions.

## Требования и подготовка

Linux, Bash, Git, curl, grep, awk, sort, uniq; запущенный Docker с Docker Compose V2 и доступ пользователя к Docker. Для передачи файлов — SSH-клиент и scp; на сервере должен работать SSH-сервер.

```bash
git clone --branch feature/monitoring https://github.com/zlefka/infra-monitoring-project.git
cd infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
```

Работа ведётся в `feature/monitoring`, изменения передаются в `main` через Pull Request. Команды запуска выполняются из корня проекта в Linux.

## Запуск

### Проверка API

Скрипт принимает URL, выполняет запрос через curl и возвращает `0` только при HTTP 200, иначе — `1`.

```bash
./check_api.sh https://httpbin.org/status/200
echo $?  # Ожидается: API доступен; код возврата 0

./check_api.sh https://httpbin.org/status/404
echo $?  # Ожидается: API недоступен, код ответа: 404; код возврата 1

./check_api.sh http://nonexistent.invalid
echo $?  # Ожидается: HTTP-ответ не получен; код возврата 1
```

### Анализ логов

```bash
./analyze_logs.sh
```

Скрипт создаёт `access.log` из 300 записей и выводит общее число запросов, топ-3 IP-адреса, количество ответов 4xx и 5xx и их сумму. Используются grep, awk, sort, uniq и регулярное выражение для выделения IP. При повторном запуске лог перезаписывается; случайные данные и статистика меняются. Логи исключены из Git через `.gitignore`.

### Docker Compose

- `api` — образ `hashicorp/http-echo:latest`, слушает порт 8080 и возвращает `Monitoring Service Active`.
- `proxy` — образ `nginx:alpine`, публикует порт 80 и проксирует запросы на `http://api:8080`.
- Контейнеры связаны сетью `monitoring`; настройки Nginx находятся в `nginx/default.conf`.

```bash
docker compose up -d
docker compose ps
curl http://localhost:80
```

Ожидается статус `Up` у обоих контейнеров и ответ:

```text
Monitoring Service Active
```

Остановка и удаление контейнеров и сети проекта:

```bash
docker compose down
```

Используется команда Compose V2 `docker compose` (в задании — `docker-compose`).

## GitHub Actions

Файл `.github/workflows/ci.yml` запускает проверки при создании и обновлении Pull Request в `main`:

```bash
bash -n check_api.sh
bash -n analyze_logs.sh
./check_api.sh https://httpbin.org/status/200
```

Первые две команды проверяют синтаксис без выполнения скриптов. Последняя должна завершиться с кодом `0`. Результат доступен в Checks у PR и в Actions репозитория. Автоматический деплой не настроен.

## Передача проекта и запуск на сервере через SSH/SCP

В работе файлы передавались напрямую через SCP: Bash-скрипты, `docker-compose.yml` и папка `nginx`. Архив не создавался, tar не использовался.

Подключение к нашей Ubuntu выполняется с локального компьютера: пользователь `user`, адрес `127.0.0.1`, порт `2222`. Этот локальный порт перенаправляется на SSH-порт 22 виртуальной машины. Используется ключ `~/.ssh/infra_monitoring_ed25519`.

### 1. SSH-ключ

На локальном компьютере ключ создаётся командой:

```bash
ssh-keygen -t ed25519 -C "infra-monitoring-project" -f ~/.ssh/infra_monitoring_ed25519
```

Если ключ уже существует, повторно создавать его не нужно. Приватный ключ остаётся на локальном компьютере и не добавляется в Git. На сервер устанавливается только публичный ключ `.pub`.

Использованный способ установки публичного ключа через SSH:


```bash
ssh-copy-id -i ~/.ssh/infra_monitoring_ed25519.pub -p 2222 user@127.0.0.1
```

### 2. Подготовка папки на сервере

Подключение с локального компьютера:

```bash
ssh -i ~/.ssh/infra_monitoring_ed25519 -p 2222 user@127.0.0.1
```

В SSH-сессии:

```bash
mkdir -p ~/infra-monitoring-project
exit
```

Команда `exit` возвращает в локальный терминал.

### 3. Передача файлов через SCP

На локальном компьютере, из корня проекта:

```bash
scp -i ~/.ssh/infra_monitoring_ed25519 -P 2222 check_api.sh analyze_logs.sh user@127.0.0.1:~/infra-monitoring-project/
scp -i ~/.ssh/infra_monitoring_ed25519 -P 2222 -r docker-compose.yml nginx user@127.0.0.1:~/infra-monitoring-project/
```

Флаг `-r` позволяет передать папку `nginx` вместе с содержимым. Одноимённые файлы на сервере заменяются. Наш порт `2222` задаётся у ssh через маленькую `-p`, а у scp — через большую `-P`.

### 4. Запуск на сервере

С локального компьютера:

```bash
ssh -i ~/.ssh/infra_monitoring_ed25519 -p 2222 user@127.0.0.1
```

В SSH-сессии:

```bash
cd ~/infra-monitoring-project
chmod +x check_api.sh analyze_logs.sh
docker compose config
docker compose up -d
docker compose ps
docker compose exec proxy nginx -t
curl -i --max-time 10 http://localhost:80
```

Ожидается статус `Up` у обоих контейнеров, успешная проверка настроек Nginx и ответ HTTP 200 с текстом `Monitoring Service Active`. Здесь `localhost` обозначает сервер, где выполняется команда.
