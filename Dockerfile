FROM alpine:3.22

RUN apk add --no-cache curl jq ca-certificates && update-ca-certificates

COPY update.sh /usr/local/bin/update-ddns
COPY entrypoint.sh /usr/local/bin/entrypoint.sh

RUN chmod 0755 /usr/local/bin/update-ddns /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
