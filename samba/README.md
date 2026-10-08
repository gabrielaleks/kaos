# Samba
Samba shares the [storage disk](../storage) over SMB, so it shows up as a network drive on macOS, Windows, Linux and iPhone. There is one share, `storage`, which exposes all of `/mnt/storage`. Each person has their own login, and everyone can see and edit everything.

It runs in Docker ([ServerContainers/samba](https://github.com/ServerContainers/samba), `smbd-only` variant) with host networking. SMB isn't HTTP, so Samba doesn't go through Traefik: it listens on port 445 of the Pi directly. See [storage/README.md](../storage/README.md) for why it's set up this way.

## Setup
1. Make sure the disk is mounted and protected (steps in [storage/README.md](../storage/README.md#setting-up-the-disk))

```bash
findmnt /mnt/storage   # must show /dev/sdb1 (or whichever sdX the disk got), not nothing
```

Step 6 of that guide matters here. If the disk is missing, Samba must fail rather than quietly write to the empty folder on the boot SSD.

2. Make sure nothing else is using port 445

```bash
sudo ss -ltnp | grep -E ':(445|139)\b'   # should print nothing
```

3. Create the accounts

```bash
cp .env.example .env
```

Replace `partner` with her username (in all three variables) and set a strong password for each person. The usernames end up in the variable names, which is why they live in `.env` and not in `docker-compose.yaml`.

Keep `UID_alekspi=1000`. Every user is written to disk as `alekspi`, so files created by anyone keep the same owner as the rest of `/mnt/storage`.

4. Start it

```bash
docker compose up -d
docker logs samba
```

5. Check that new files get the right owner

Connect from any device (see below), create a folder, then on the Pi:

```bash
ls -ln /mnt/storage   # the new folder must show 1000 1000
```

If the group shows something other than `1000`, add `force group = alekspi;` after `force user = alekspi;` in `docker-compose.yaml` and recreate the container.

## Connecting
Use the Pi's **LAN IP** at home. It's faster because the traffic doesn't go through Tailscale. Use **`storage.kaoshome.dev`** from anywhere else. Pi-hole resolves it to the Pi's Tailscale IP, so Tailscale must be on.

| Device | How |
|---|---|
| macOS | Finder → Go → Connect to Server (⌘K) → `smb://<pi-lan-ip>/storage` → Registered User. Tick "Remember this password in my keychain". To reconnect at every login, drag the mounted drive into System Settings → General → Login Items. |
| Windows | File Explorer → This PC → Map network drive → `\\<pi-lan-ip>\storage` → tick "Connect using different credentials" |
| Linux | File manager → `smb://<pi-lan-ip>/storage`, or `sudo mount -t cifs //<pi-lan-ip>/storage /mnt/kaos -o username=<user>,uid=$(id -u),gid=$(id -g)` |
| iPhone | Files → ⋯ → Connect to Server → `smb://storage.kaoshome.dev` → Registered User |

## Deleted files: `.recycle`
SMB has no Trash. Finder warns that a file "will be deleted immediately", and other clients don't even warn. To make up for that, Samba moves deleted files to `.recycle/<username>/`, keeping their original folder structure. To restore a file, open `.recycle` in the share (on macOS, press ⌘⇧. to show hidden folders) and move the file back.

Files in `.recycle` count towards disk usage. To empty anything older than 30 days automatically, add this to `alekspi`'s crontab on the Pi (`crontab -e`):

```bash
0 4 * * * find /mnt/storage/.recycle -type f -atime +30 -delete && find /mnt/storage/.recycle -mindepth 1 -type d -empty -delete
```

## Adding or changing a user
Edit `.env` (`ACCOUNT_<username>`, `GROUPS_<username>=smbusers`), then run:

```bash
docker compose up -d --force-recreate
```

Accounts are recreated from `.env` every time the container starts.
