# Caddy co-hosted sites (drop-in)

This directory is mounted into the Caddy container at `/etc/caddy/sites` and
imported by the main `Caddyfile` via:

```
import /etc/caddy/sites/*.caddy
```

Other applications hosted on this server (e.g. **bluelight.ventures**) place a
`*.caddy` file here containing their own site block(s), then reload Caddy:

```
docker exec tagnote-caddy-1 caddy reload --config /etc/caddy/Caddyfile --adapter caddyfile
```

A reload is graceful — it does **not** interrupt TagNote or any other site that
is already running.

## Notes

- `release/deploy.sh` only overwrites `Caddyfile` and `docker-compose.yml`. It
  does **not** touch this directory, so co-hosted routing survives TagNote
  deploys.
- Each co-hosted app's container must share a Docker network with Caddy
  (`tagnote_default`) so Caddy can reach it by name in `reverse_proxy`.
- An empty glob is harmless: Caddy logs a warning and starts normally.
