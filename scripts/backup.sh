#!/usr/bin/env bash
set -euo pipefail

# Вимкнення автоконвертації шляхів у Git Bash (Windows)
export MSYS_NO_PATHCONV=1

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BACKUP_ROOT="$PROJECT_DIR/backups"
TIMESTAMP="$(date +"%Y-%m-%d_%H-%M-%S")"
TMP_DIR="$BACKUP_ROOT/tmp_$TIMESTAMP"
ARCHIVE_NAME="openhab_stack_backup_$TIMESTAMP.tar.gz"
RETENTION_DAYS=7

# Завантаження змінних середовища
if [ -f "$PROJECT_DIR/docker/.env" ]; then
  set -a
  source "$PROJECT_DIR/docker/.env"
  set +a
fi

mkdir -p "$TMP_DIR/influxdb" "$TMP_DIR/volumes" "$TMP_DIR/configs"

echo "[1/4] Резервне копіювання бази даних InfluxDB..."
docker exec influxdb rm -rf /tmp/influx_backup
docker exec influxdb influx backup /tmp/influx_backup --token "${INFLUXDB_TOKEN}"
docker cp influxdb:/tmp/influx_backup/. "$TMP_DIR/influxdb/"
docker exec influxdb rm -rf /tmp/influx_backup

echo "[2/4] Копіювання локальних конфігурацій OpenHAB та Mosquitto..."
cp -r "$PROJECT_DIR/openhab/conf" "$TMP_DIR/configs/openhab_conf"
cp -r "$PROJECT_DIR/mosquitto/config" "$TMP_DIR/configs/mosquitto_config"

echo "[3/4] Архівування Docker Named Volumes (Grafana та OpenHAB userdata)..."
docker run --rm \
  -v docker_grafana_data:/source_grafana:ro \
  -v docker_openhab_userdata:/source_openhab:ro \
  -v "$TMP_DIR/volumes":/backup \
  alpine sh -c "tar -czf /backup/grafana_data.tar.gz -C /source_grafana . && tar -czf /backup/openhab_userdata.tar.gz -C /source_openhab ."

echo "[4/4] Створення фінального архіву та очищення..."
tar -czf "$BACKUP_ROOT/$ARCHIVE_NAME" -C "$TMP_DIR" .
rm -rf "$TMP_DIR"

# Політика ротації: видалення бекапів, старших за RETENTION_DAYS
find "$BACKUP_ROOT" -maxdepth 1 -name "openhab_stack_backup_*.tar.gz" -type f -mtime +${RETENTION_DAYS} -delete

echo "✅ Бекап успішно створено: backups/$ARCHIVE_NAME"
