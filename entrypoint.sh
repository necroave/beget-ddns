#!/bin/sh
set -eu

: "${CHECK_INTERVAL:?CHECK_INTERVAL is required, e.g. 5m, 15m or 1h}"

case "$CHECK_INTERVAL" in
    *m)
        minutes="${CHECK_INTERVAL%m}"
        case "$minutes" in ''|*[!0-9]*) echo "Invalid CHECK_INTERVAL: $CHECK_INTERVAL" >&2; exit 1;; esac
        [ "$minutes" -ge 1 ] || { echo "CHECK_INTERVAL must be >= 1m" >&2; exit 1; }
        if [ "$minutes" -le 59 ]; then
            schedule="*/$minutes * * * *"
        else
            hours=$((minutes / 60))
            schedule="0 */$hours * * *"
        fi
        ;;
    *h)
        hours="${CHECK_INTERVAL%h}"
        case "$hours" in ''|*[!0-9]*) echo "Invalid CHECK_INTERVAL: $CHECK_INTERVAL" >&2; exit 1;; esac
        [ "$hours" -ge 1 ] || { echo "CHECK_INTERVAL must be >= 1h" >&2; exit 1; }
        schedule="0 */$hours * * *"
        ;;
    *)
        echo "CHECK_INTERVAL must look like 5m, 15m or 1h" >&2
        exit 1
        ;;
esac

printf '%s /usr/local/bin/update-ddns >> /proc/1/fd/1 2>> /proc/1/fd/2\n' "$schedule" > /etc/crontabs/root

# Run once immediately so the container does not wait for the first cron tick.
/usr/local/bin/update-ddns || true

exec crond -f -l 2
