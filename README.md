# kaos

A self-hosted homeserver running on a Raspberry Pi: privately accessible from anywhere via Tailscale, with automatic HTTPS through Traefik and Let's Encrypt.

## Services

| Service | Description |
|---|---|
| [Dashboard](./dashboard) | Services overview |
| [Traefik](./traefik) | Reverse proxy with automatic TLS |
| [Pi-hole](./pihole) | Network-wide ad blocking and local DNS |
| [Tailscale](./tailscale) | VPN overlay for secure remote access |
| [Home Assistant](./homeassistant) | Home automation platform |
| [Portainer](./portainer) | Container management UI |
| [Lista](./lista) | Grocery list app |
| [Nanomatter](./nanomatter) | Lightweight Matter controller |

## Setup

Most services are Docker-based. The general pattern is:

```bash
cp .env.example .env   # fill in values
docker compose up -d
```

See each service's folder for specific setup instructions.

### Traefik

Requires a Cloudflare API token for DNS-01 certificate issuance. Copy `.env.example`, populate your Cloudflare credentials, then copy `dynamic/traefik-dashboard.yml.example` to `dynamic/traefik-dashboard.yml` and set your hashed admin password:

```bash
htpasswd -nb admin yourpassword
```

### Pi-hole

Runs bare-metal on the Raspberry Pi (not in Docker). See [pihole/README.md](./pihole/README.md) for the full setup, including Tailscale DNS integration and custom dnsmasq configuration.

## Architecture

All HTTPS traffic is routed through Traefik, which terminates TLS using certificates issued by Let's Encrypt via Cloudflare's DNS API. Services are only reachable through Tailscale — nothing is exposed to the public internet. Pi-hole acts as the internal DNS server, resolving `*.kaoshome.dev` to the Raspberry Pi's Tailscale IP.

```
Client (on Tailnet)
  → Pi-hole resolves *.kaoshome.dev → Tailscale IP
  → Traefik (port 443) terminates TLS
  → Routes to the appropriate container
```
