#!/bin/sh

set -eu

BEGET_API_URL="https://api.beget.com/api/dns"

log() {
    echo "$(date -u '+%Y-%m-%dT%H:%M:%SZ') $*" >&2
}

error() {
    log "❌ ERROR: $*"
}

info() {
    log "ℹ️ $*"
}

check() {
    log "🔍 $*"
}

success() {
    log "✅ $*"
}

warning() {
    log "⚠️ $*"
}

update_log() {
    log "🔄 $*"
}

if [ -z "${BEGET_LOGIN:-}" ]; then
    error "BEGET_LOGIN is not set"
    exit 1
fi

if [ -z "${BEGET_PASSWORD:-}" ]; then
    error "BEGET_PASSWORD is not set"
    exit 1
fi

if [ -z "${BEGET_FQDN:-}" ]; then
    error "BEGET_FQDN is not set"
    exit 1
fi

if [ -z "${IP_CHECK_URL:-}" ]; then
    error "IP_CHECK_URL is not set"
    exit 1
fi

UPDATE_ROOT_ON_WILDCARD="${UPDATE_ROOT_ON_WILDCARD:-false}"

api_request() {
    url="$1"
    input_data="$2"

    response_file="$(mktemp)"
    error_file="$(mktemp)"

    http_code="$(
        curl \
            -4 \
            -sS \
            --max-time 20 \
            --connect-timeout 10 \
            -o "$response_file" \
            -w '%{http_code}' \
            -X POST "$url" \
            -H 'Content-Type: application/x-www-form-urlencoded' \
            --data-urlencode "login=$BEGET_LOGIN" \
            --data-urlencode "passwd=$BEGET_PASSWORD" \
            --data-urlencode 'input_format=json' \
            --data-urlencode "input_data=$input_data" \
            2>"$error_file"
    )" || {
        curl_exit_code="$?"

        error "Beget API request failed"
        error "URL: $url"
        error "curl exit code: $curl_exit_code"

        if [ -s "$error_file" ]; then
            error "curl: $(cat "$error_file")"
        fi

        rm -f "$response_file" "$error_file"
        return 1
    }

    if [ "$http_code" -lt 200 ] || [ "$http_code" -ge 300 ]; then
        error "Beget API returned HTTP $http_code"

        if [ -s "$response_file" ]; then
            log "📄 API response:"
            cat "$response_file" >&2
        fi

        rm -f "$response_file" "$error_file"
        return 1
    fi

    if [ ! -s "$response_file" ]; then
        error "Beget API returned an empty response"

        rm -f "$response_file" "$error_file"
        return 1
    fi

    cat "$response_file"

    rm -f "$response_file" "$error_file"
}

get_dns_ip() {
    fqdn="$1"

    check "Checking DNS record for $fqdn"

    input_data="{\"fqdn\":\"$fqdn\"}"

    response="$(api_request "$BEGET_API_URL/getData" "$input_data")" || {
        return 1
    }

    if ! echo "$response" | jq empty >/dev/null 2>&1; then
        error "Beget returned invalid JSON for $fqdn"
        log "📄 API response:"
        echo "$response" >&2
        return 1
    fi

    api_status="$(echo "$response" | jq -r '.status // empty')"
    answer_status="$(echo "$response" | jq -r '.answer.status // empty')"

    if [ "$api_status" != "success" ] || [ "$answer_status" != "success" ]; then
        error "Beget getData returned an API error for $fqdn"
        log "📄 API response:"
        echo "$response" | jq . >&2
        return 1
    fi

    dns_ip="$(echo "$response" | jq -r '.answer.result.records.A[0].address // empty')"

    if [ -z "$dns_ip" ]; then
        error "No A record found for $fqdn"
        log "📄 API response:"
        echo "$response" | jq . >&2
        return 1
    fi

    log "📡 DNS IP for $fqdn: $dns_ip"

    echo "$dns_ip"
}

update_dns() {
    fqdn="$1"

    update_log "Updating $fqdn -> $PUBLIC_IP"

    input_data="{\"fqdn\":\"$fqdn\",\"records\":{\"A\":[{\"address\":\"$PUBLIC_IP\"}]}}"

    response="$(api_request "$BEGET_API_URL/changeRecords" "$input_data")" || {
        return 1
    }

    if ! echo "$response" | jq empty >/dev/null 2>&1; then
        error "Beget returned invalid JSON during update of $fqdn"
        log "📄 API response:"
        echo "$response" >&2
        return 1
    fi

    api_status="$(echo "$response" | jq -r '.status // empty')"
    answer_status="$(echo "$response" | jq -r '.answer.status // empty')"
    result="$(echo "$response" | jq -r '.answer.result // empty')"

    if [ "$api_status" != "success" ] ||
       [ "$answer_status" != "success" ] ||
       [ "$result" != "true" ]; then

        error "Beget changeRecords returned an API error for $fqdn"
        log "📄 API response:"
        echo "$response" | jq . >&2
        return 1
    fi

    success "DNS updated successfully: $fqdn -> $PUBLIC_IP"
}

check_and_update() {
    fqdn="$1"

    dns_ip="$(get_dns_ip "$fqdn")" || {
        return 1
    }

    if [ "$PUBLIC_IP" = "$dns_ip" ]; then
        success "IP unchanged for $fqdn: $PUBLIC_IP"
        return 0
    fi

    update_log "IP changed for $fqdn: $dns_ip -> $PUBLIC_IP"

    update_dns "$fqdn"
}

check "Checking public IP from $IP_CHECK_URL"

ip_error_file="$(mktemp)"

PUBLIC_IP="$(
    curl \
        -4 \
        -fsS \
        --max-time 10 \
        --connect-timeout 5 \
        "$IP_CHECK_URL" \
        2>"$ip_error_file"
)" || {
    curl_exit_code="$?"

    error "Failed to determine public IP"
    error "curl exit code: $curl_exit_code"

    if [ -s "$ip_error_file" ]; then
        error "curl: $(cat "$ip_error_file")"
    fi

    rm -f "$ip_error_file"
    exit 1
}

rm -f "$ip_error_file"

PUBLIC_IP="$(echo "$PUBLIC_IP" | tr -d '[:space:]')"

if [ -z "$PUBLIC_IP" ]; then
    error "Public IP response is empty"
    exit 1
fi

case "$PUBLIC_IP" in
    *.*.*.*)
        ;;
    *)
        error "Invalid public IP: $PUBLIC_IP"
        exit 1
        ;;
esac

log "🌐 Public IP: $PUBLIC_IP"

check_and_update "$BEGET_FQDN" || {
    error "Failed to process $BEGET_FQDN"
    exit 1
}

if [ "$UPDATE_ROOT_ON_WILDCARD" = "true" ] &&
   [ "${BEGET_FQDN#\*.}" != "$BEGET_FQDN" ]; then

    ROOT_FQDN="${BEGET_FQDN#*.}"

    log "🃏 Wildcard detected: $BEGET_FQDN"
    check "Checking root zone: $ROOT_FQDN"

    check_and_update "$ROOT_FQDN" || {
        error "Failed to process root zone $ROOT_FQDN"
        exit 1
    }
fi

success "DDNS check completed"