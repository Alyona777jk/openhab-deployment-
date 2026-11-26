#!/usr/bin/env bash
set -euo pipefail

export MSYS_NO_PATHCONV=1

if [ $# -lt 1 ]; then
  echo "Використання: ./scripts/restore.sh backups/<ім'я_архіву>.tar.gz"
  exit 1
fi

ARCHIVE_PATH="$1"
if [ ! -f "$ARCHIVE_PATH" ]; then
  echo "❌ Помилка: Файл '$ARCHIVE_PATH' не знайдено."
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="$PROJECT_DIR/docker/docker-compose.yml"
RESTORE_TMP="$PROJECT_DIR/backups/restore_tmp_$(date +%s)"

if [ -f "$PROJECT_DIR/docker/.env" ]; then
  set -a
  source "$PROJECT_DIR/docker/.env"
  set +a
fi

read -p "⚠️ УВАГА: Поточні дані будуть перезаписані. Продовжити? (y/N): " CONFIRM
if [[ ! "$CONFIRM" =~ ^[Yy]$ ]]; then
  echo "Скасовано."
  exit 0
fi

mkdir -p "$RESTORE_TMP"
tar -xzf "$ARCHIVE_PATH" -C "$RESTORE_TMP"

echo "[1/4] Зупинка OpenHAB та Grafana..."
docker compose -f "$COMPOSE_FILE" stop openhab grafana

echo "[2/4] Відновлення конфігурацій OpenHAB та Mosquitto..."
rm -rf "$PROJECT_DIR/openhab/conf/"* "$PROJECT_DIR/mosquitto/config/"*
cp -r "$RESTORE_TMP/configs/openhab_conf/." "$PROJECT_DIR/openhab/conf/"
cp -r "$RESTORE_TMP/configs/mosquitto_config/." "$PROJECT_DIR/mosquitto/config/"

echo "[3/4] Відновлення Docker Named Volumes..."
docker run --rm \
  -v docker_grafana_data:/target_grafana \
  -v docker_openhab_userdata:/target_openhab \
  -v "$RESTORE_TMP/volumes":/backup:ro \
  alpine sh -c "rm -rf /target_grafana/* /target_openhab/* && tar -xzf /backup/grafana_data.tar.gz -C /target_grafana && tar -xzf /backup/openhab_userdata.tar.gz -C /target_openhab"

echo "[4/4] Відновлення бази даних InfluxDB..."
docker exec influxdb rm -rf /tmp/influx_restore
docker cp "$RESTORE_TMP/influxdb" influxdb:/tmp/influx_restore
docker exec influxdb influx restore /tmp/influx_restore --full --token "${INFLUXDB_TOKEN}"
docker exec influxdb rm -rf /tmp/influx_restore

rm -rf "$RESTORE_TMP"

echo "Запуск усього стеку..."
docker compose -f "$COMPOSE_FILE" up -d

echo "✅ Відновлення з '$ARCHIVE_PATH' успішно завершено!"
