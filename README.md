# OpenHAB Smart Home Deployment Automation

Автоматизоване розгортання та управління конфігурацією екосистеми розумного будинку на базі **OpenHAB**, **InfluxDB**, **Grafana** та **Mosquitto MQTT** з використанням Docker Compose та Bash-скриптів резервного копіювання.

## Архітектура рішення

Усі сервіси працюють в ізольованій bridge-мережі `smarthome_net` та взаємодіють за внутрішніми DNS-іменами контейнерів. Порти бази даних та MQTT-брокера прив'язані виключно до `127.0.0.1` для мінімізації поверхні атаки.

```mermaid
graph TD
    User([Користувач / Браузер]) -->|HTTP :8081| OpenHAB[OpenHAB 4.2]
    User -->|HTTP :3000| Grafana[Grafana 11.2]
    IoT([IoT Пристрої]) -->|MQTT :1884| Mosquitto[Eclipse Mosquitto]
    
    subgraph smarthome_net [Isolated Docker Network: smarthome_net]
        OpenHAB <-->|Pub/Sub DNS: mosquitto| Mosquitto
        OpenHAB -->|Time-Series Write DNS: influxdb:8086| InfluxDB[(InfluxDB 2.7)]
        Grafana -->|Flux Queries DNS: influxdb:8086| InfluxDB
    end
Quick Start GuideКлонування репозиторію:Bashgit clone <URL_твого_репозиторію>
cd openhab-deployment
Налаштування змінних середовища:Bashcp docker/.env.example docker/.env
# Відредагуйте паролі та токени у файлі docker/.env
Запуск стеку:Bashdocker compose -f docker/docker-compose.yml up -d
Перевірка стану контейнерів (Healthchecks):Bashdocker compose -f docker/docker-compose.yml ps
OpenHAB UI: http://localhost:8081Grafana UI: http://localhost:3000Backup & Restore ProceduresСтворення резервної копіїСкрипт scripts/backup.sh виконує гарячий бекап InfluxDB, копіює конфігураційні файли та архівує Docker-томи. Архів зберігається у backups/, а файли старші за 7 днів автоматично видаляються:Bash./scripts/backup.sh
Планування автоматичних бекапів (Cron)Для запуску щодня о 02:00 у Linux додайте запис у crontab -e:Фрагмент коду0 2 * * * /bin/bash /path/to/openhab-deployment/scripts/backup.sh >> /var/log/openhab_backup.log 2>&1
(У Windows використовується Task Scheduler із запуском C:\Program Files\Git\bin\bash.exe та аргументом шляху до скрипта).Відновлення з резервної копіїBash./scripts/restore.sh backups/openhab_stack_backup_YYYY-MM-DD_HH-MM-SS.tar.gz
TroubleshootingПроблемаПричинаРішенняКонтейнер openhab довго переходить у статус healthyПерший запуск Java-машини та ініціалізація кешу OSGi займає 40–90 секунд.Зачекайте завершення start_period: 60s та перевірте логи: docker logs openhab.Помилка шляхів при запуску backup.sh у Git BashMSYS2 автоматично підміняє POSIX-шляхи /var/lib/... на C:/Program Files/Git/....У скриптах встановлено прапорець export MSYS_NO_PATHCONV=1.Помилка port is already allocated на порту 8081Порт зайнятий іншим локальним сервісом.Змініть OPENHAB_HTTP_PORT=8081 у файлі docker/.env і перезапустіть стек.EOF
