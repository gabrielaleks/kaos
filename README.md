# KAOS homeserver
Available apps:
- traefik: Reverse proxy
- pihole: Network-wide adblocker + DNS server
- Portainer: Container management UI
- lista: Grocery list

# Starting the apps
First, make sure you're logged in:

```bash
docker login ghcr.io -u gabrielaleks
```

This will enable you to pull any images from `ghcr.io/gabrielaleks`

## Lista
Create a .env file, copy the contents from .env.example and replace any variables if needed. Make sure to set PUBLIC_FRONTEND_URL accordingly.

```bash
cd ./lista
docker compose up -d
```

## Portainer
Portainer's setup is simple. To use it, just go to the its folder and start the container:

```bash
cd ./portainer
docker compose up -d
```

## Pihole
Pihole is a bit special as it is not running on a docker container - it runs bare-metal on the Raspberry Pi. To install it run the following command:

```bash
curl -sSL https://install.pi-hole.net | bash
```

## Traefik
Before starting traefik's container, make sure to create a .env file, copy the content from .env.example and populate the vars (based on your cloudflare account).

When that's done, start the container:

```bash
cd ./traefik
docker compose up -d
```