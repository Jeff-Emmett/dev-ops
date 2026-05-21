#!/bin/bash
# Wait for Europe PBF download to complete, then start ORS
# Run as: nohup bash /opt/apps/openrouteservice/wait-and-start.sh &

PBF_FILE="/opt/apps/openrouteservice/data/europe-latest.osm.pbf"
COMPOSE_DIR="/opt/apps/openrouteservice"
LOG="/opt/apps/openrouteservice/logs/startup.log"

echo "$(date): Waiting for PBF download to complete..." | tee -a "$LOG"

while true; do
    # Check if wget is still running
    if ! pgrep -f "wget.*europe-latest.osm.pbf" > /dev/null 2>&1; then
        SIZE=$(stat -c%s "$PBF_FILE" 2>/dev/null || echo 0)
        echo "$(date): wget finished. PBF size: $(numfmt --to=iec $SIZE)" | tee -a "$LOG"
        break
    fi
    SIZE=$(stat -c%s "$PBF_FILE" 2>/dev/null || echo 0)
    echo "$(date): Download in progress: $(numfmt --to=iec $SIZE)" | tee -a "$LOG"
    sleep 60
done

echo "$(date): Starting OpenRouteService..." | tee -a "$LOG"
cd "$COMPOSE_DIR" && docker compose up -d
echo "$(date): docker compose up -d complete (exit $?)" | tee -a "$LOG"
