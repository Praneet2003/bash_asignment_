#!/usr/bin/env bash
set -uo pipefail
SERVICES_FILE="services.txt"
LOG_FILE="/var/log/health_monitor.log"
DRY_RUN=false
TOTAL=0
HEALTHY=0
RECOVERED=0
FAILED=0

for arg in "$@"; do
    if [[ "$arg" == "--dry-run" ]]; then
        DRY_RUN=true
    else
        SERVICES_FILE="$arg"
    fi
done

log() {
    local level="$1"
    local message="$2"
    local service="${3:-system}"
    local timestamp

    timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "${timestamp} [${level}] [${service}] ${message}" | tee -a "$LOG_FILE"
}

check_service() {
    local service="$1"

    ((TOTAL++))

    if systemctl is-active --quiet "$service"; then
        log "OK" "Service is healthy" "$service"
        ((HEALTHY++))
    else
        log "WARN" "Service is down — attempting restart" "$service"

        if [ "$DRY_RUN" = true ]; then
            log "INFO" "[DRY-RUN] Would restart service" "$service"
            ((FAILED++))
            return
        fi

        systemctl restart "$service"

        sleep 5

        if systemctl is-active --quiet "$service"; then
            log "OK" "Service RECOVERED after restart" "$service"
            ((RECOVERED++))
        else
            log "ERROR" "Service FAILED to restart" "$service"
            ((FAILED++))
        fi
    fi
}

log "INFO" "Starting health monitor"

if [[ ! -f "$SERVICES_FILE" ]]; then
    log "ERROR" "Services file not found: $SERVICES_FILE"
    exit 1
fi

if [[ ! -s "$SERVICES_FILE" ]]; then
    log "ERROR" "Services file is empty"
    exit 1
fi

while IFS= read -r service || [[ -n "$service" ]]; do
    # Skip empty lines
    [[ -z "$service" ]] && continue

    check_service "$service"

done < "$SERVICES_FILE"

echo "======================================"
echo "Health Monitor Summary"
echo "======================================"
echo "Total services : $TOTAL"
echo "Healthy        : $HEALTHY"
echo "Recovered      : $RECOVERED"
echo "Failed         : $FAILED"
echo "======================================"
