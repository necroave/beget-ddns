# Beget DDNS

Minimal Docker container for automatic IPv4 DDNS updates via the [Beget DNS API](https://beget.com/ru/kb/api/funkczii-upravleniya-dns).
The container periodically checks the public IPv4 address, compares it with the configured A record, and updates DNS **only when the IP changes**.

Prebuilt image: necroave/beget-ddns:0.0.1

## Features

* 🐳 Alpine-based minimal container
* 🔄 Configurable cron interval
* 🌐 Configurable public IP service
* 📡 Beget DNS API
* 🃏 Wildcard record support
* 🌍 Optional root zone update for wildcard records
* 📝 Clear emoji-based logs
* ❌ HTTP, curl and API error handling

## Configuration

Create `.env`:

```env
BEGET_LOGIN=your_login
BEGET_PASSWORD=your_api_password

BEGET_FQDN=*.example.com
UPDATE_ROOT_ON_WILDCARD=true

IP_CHECK_URL=https://2ip.ru
CHECK_INTERVAL=5m
```

| Variable                  | Default          | Description                                    |
| ------------------------- | ---------------- | ---------------------------------------------- |
| `BEGET_LOGIN`             | —                | Beget login                                    |
| `BEGET_PASSWORD`          | —                | Beget API password                             |
| `BEGET_FQDN`              | —                | A record to update                             |
| `UPDATE_ROOT_ON_WILDCARD` | `false`          | Also update `example.com` for `*.example.com`  |
| `IP_CHECK_URL`            | `https://2ip.ru` | Public IPv4 endpoint(also works on ifconfig.me)|
| `CHECK_INTERVAL`          | `5m`             | Check interval                                 |

## Run

```bash
docker compose up -d --build
```

View logs:

```bash
docker compose logs -f
```

## Example

With:

```env
BEGET_FQDN=*.example.com
UPDATE_ROOT_ON_WILDCARD=true
```

the container checks and updates both:

```text
*.example.com
example.com
```

Each record is handled independently and is updated only when its current IP differs from the public IP.

## Logs

```text
🌐 Public IP: 4.3.2.1
🔍 Checking DNS record for *.example.com
📡 DNS IP for *.example.com: 4.3.2.1
✅ IP unchanged for *.example.com
🃏 Wildcard detected: *.example.com
🔍 Checking root zone: example.com
📡 DNS IP for example.com: 1.2.3.4
🔄 IP changed for example.com: 1.2.3.4 -> 4.3.2.1
🔄 Updating example.com -> 4.3.2.1
✅ DNS updated successfully: example.com -> 4.3.2.1
```

TTL is not modified by the container.

## License

MIT
