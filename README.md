# KAOS homeserver
Available apps:
- Portainer: Container management UI
- lista: Grocery list

# Managing dnsmasq
Edit the file on /etc/dnsmasq.d/02-kaos.conf and restart pihole:

```bash
sudo systemctl restart pihole-FTL
```

# Starting the apps
First, make sure you're logged in:

```bash
docker login ghcr.io -u gabrielaleks
```
## Portainer
```bash
cd ./portainer
docker compose up -d
```

## Lista
Create a .env file, copy the contents from .env.example and replace any variables if needed. Make sure to set LOCAL_FRONTEND_HOST accordingly.

```bash
cd ./lista
docker compose up -d
```