# HTTPS with Traefik: Using Let's Encrypt, Cloudflare, and Tailscale

## How It Works

### Overview

This setup enables HTTPS access to self-hosted services running behind Traefik, using a real domain with trusted TLS certificates — all accessible through a Tailscale VPN tunnel. The key components are:

- **Traefik** — Reverse proxy and automatic certificate manager
- **Cloudflare** — DNS provider with API access for domain validation
- **Let's Encrypt** — Certificate Authority (CA) that issues trusted certificates
- **Tailscale** — VPN overlay network for secure access from anywhere
- **Pi-hole** — Local DNS server that resolves your domain to a Tailscale IP

### Traefik

Traefik has the following responsibilities in this setup:

1. **Reverse proxy:** Traefik receives requests on port 80 (HTTP) and 443 (HTTPS). It decides where to route these requests based on the Host header (e.g., `app.kaoshome.dev`) and Docker labels defined in each service's `docker-compose.yml`.
2. **Automatic service discovery:** With `--providers.docker=true`, Traefik watches containers via `/var/run/docker.sock`, reads their labels, and automatically creates routers and services.
3. **Automatic TLS certificate management:** With `--certificatesresolvers.le.acme.dnschallenge=true`, Traefik handles the full certificate lifecycle — requesting, validating, renewing, and storing certificates in `/letsencrypt/acme.json`.

### Cloudflare

Cloudflare is used as a DNS provider with API access. It serves two purposes:

1. **Hosts the DNS zone** for the domain (e.g., `kaoshome.dev`).
2. **Allows Traefik to modify DNS records through its API**, which is required for the DNS-01 challenge during certificate issuance.

### Let's Encrypt

Let's Encrypt is a Certificate Authority (CA). It:

- Issues trusted TLS certificates
- Digitally signs them

The browser trusts Let's Encrypt because it is included in the list of trusted CAs that ships with every major browser and operating system. When you access `https://app.kaoshome.dev`, the browser receives the certificate, verifies that it was signed by Let's Encrypt, and — if valid — establishes a secure connection.

### Tailscale

Tailscale creates a virtual network with addresses in the `100.x.x.x` range, allowing devices to communicate as if they were on the same LAN. However, it's important to understand that **Tailscale is not a network itself — it's a layer on top of a network**. The encrypted WireGuard packets still need a real physical network (WiFi, cellular, or ethernet) to travel through. This means:

- ✅ Works on the same WiFi, even without internet
- ✅ Works from a different network via cellular or WiFi
- ❌ Does **not** work with no network at all (airplane mode, no WiFi, no cellular)

---

## Setup Steps

### 1. Buy a Domain on Cloudflare

Purchase a domain through Cloudflare (e.g., `kaoshome.dev`). This is necessary because Let's Encrypt validates domain ownership by querying **public DNS**, so you need a real, publicly registered domain.

### 2. Create a Cloudflare API Token

1. Go to **Cloudflare Dashboard → API Tokens → Create Token → Edit Zone DNS** (use the template).
2. Under **Permissions**, select:
   - `Zone → DNS → Edit`
   - `Zone → Zone → Read`
3. Under **Zone Resources**, select the domain you purchased.
4. Save and copy the token.

### 3. Modify the Traefik Docker Compose File

Add the following to your Traefik `docker-compose.yml`:

```yaml
command:
  ...
  - "--entrypoints.websecure.address=:443"
  - "--entrypoints.web.http.redirections.entrypoint.to=websecure"
  - "--entrypoints.web.http.redirections.entrypoint.scheme=https"

  # For debugging purposes
  - "--log.level=DEBUG"

  # ACME (Let's Encrypt) configuration
  - "--certificatesresolvers.le.acme.email=<your@email.com>"
  - "--certificatesresolvers.le.acme.storage=/letsencrypt/acme.json"
  - "--certificatesresolvers.le.acme.dnschallenge=true"
  - "--certificatesresolvers.le.acme.dnschallenge.provider=cloudflare"

  # Optional: use the staging server to avoid exhausting rate limits during testing
  - "--certificatesresolvers.le.acme.caserver=https://acme-staging-v02.api.letsencrypt.org/directory"
  ...

environment:
  - CLOUDFLARE_DNS_API_TOKEN=${CF_DNS_API_TOKEN}
  - CF_ZONE_API_TOKEN=${CF_DNS_API_TOKEN}

ports:
  - "443:443"

volumes:
  - ./letsencrypt:/letsencrypt

labels:
  ...
  - "traefik.http.routers.dashboard.rule=Host(`traefik.kaoshome.dev`)"
  - "traefik.http.routers.dashboard.entrypoints=websecure"
  - "traefik.http.routers.dashboard.tls=true"
  - "traefik.http.routers.dashboard.tls.certresolver=le"
  ...
```

### 4. Set Up the Certificate Storage File

Before starting the container, create the certificate storage file with the correct permissions:

```bash
mkdir letsencrypt
touch letsencrypt/acme.json
chmod 600 letsencrypt/acme.json
```

> ⚠️ **Important:** ACME can fail silently if the file permissions are not set to `600`.

### 5. Start the Container and Trigger Certificate Issuance

Start the container:

```bash
docker compose up
```

This initiates the ACME flow using the DNS-01 challenge:

1. Traefik generates a cryptographic token.
2. Traefik calls the Cloudflare API and creates a TXT DNS record:
   ```
   _acme-challenge.traefik.kaoshome.dev  TXT  "<token>"
   ```
3. Let's Encrypt queries public DNS, finds the TXT record, and confirms that you control the domain.
4. Let's Encrypt signs the certificate and sends it back to Traefik.
5. Traefik stores the certificate in `/letsencrypt/acme.json`.

Your browser can now establish a valid HTTPS connection! When accessing `*.kaoshome.dev`, the browser receives a certificate signed by a trusted CA, which is all it needs to show the 🔒 lock icon.

---

## Diagrams

### Flow When the Certificate Has Already Been Issued (Normal Access)

```
Browser
 ↓
Domain resolves (via internal Pi-hole) → 100.x.x.x (Tailscale IP)
 ↓
Tailscale tunnel
 ↓
Traefik (port 443)
 ↓
TLS handshake (uses cert stored in acme.json)
 ↓
Router (Host rule matches domain)
 ↓
Correct container
```

> **Note:** DNS resolution happens before any traffic reaches Traefik. Let's Encrypt and Cloudflare are **not involved** in this flow — they are only needed during certificate issuance and renewal.

### Flow When the Certificate Is Issued for the First Time (or Renewed)

```
Traefik needs a certificate
 ↓
Traefik (ACME client)
 ↓
Cloudflare API (creates TXT record: _acme-challenge.*.kaoshome.dev)
 ↓
Let's Encrypt queries public DNS
 ↓
Successful validation
 ↓
Let's Encrypt issues certificate
 ↓
Traefik stores it in acme.json
```

> **Note:** This flow requires internet access on the Raspberry Pi, since Traefik needs to reach both the Cloudflare API and Let's Encrypt servers.