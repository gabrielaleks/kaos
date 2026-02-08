# KAOS Homeserver
Available apps:
- lista: Grocery list

# Starting the apps
First, make sure you're logged in:

```bash
docker login ghcr.io -u gabrielaleks
```

## Lista
Create a .env file, copy the contents from .env.example and replace any variables if needed. Make sure to set LOCAL_FRONTEND_HOST accordingly.

```bash
cd ./lista
docker compose up
```