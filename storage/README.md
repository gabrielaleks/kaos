# Storage
A 4 TB hard drive attached to the Raspberry Pi over USB that holds *anything*: RAW and edited photos, videos, documents, music, movies. Apps run as Docker services and access the files on this disk. The drive is a stopgap until a proper NAS replaces it, so every decision here is chosen to make that move easy.

## Requirements
- **General-purpose storage.** The disk is not tied to a single app or file type. Photos are the most important content, but documents, music and movies live here too.
- **Photographer workflow.** Bulk-copy large RAW and video files from the Mac, and open archived files directly from desktop apps (Lightroom, Photoshop). The Lightroom catalog stays on the Mac; only the image files live here.
- **Every device on the tailnet.** macOS, Linux, Windows and iPhone. Two people use the tailnet (me and my girlfriend). She has her own login and, for now, the same access as me: everything under `/mnt/storage`.
- **Private only.** Reachable only from the home LAN and the tailnet. Nothing is exposed to the public internet, and there is no plan to share files with anyone outside the tailnet.
- **Survive mistakes and disk failure.** A single disk is a single copy. Deleted files are recoverable for 30 days. Whether to add an off-site backup is still open (see [Backups](#backups-undecided)).
- **The rest of the homelab must not depend on the disk.** If the drive is unplugged or dies, the Pi still boots and Home Assistant, Pi-hole and the other services keep running.

## Hardware
| Part | Details |
|---|---|
| Drive | WD Red Plus 4 TB (`WD40EFPX`), CMR, 5400 rpm, built for 24/7 NAS use |
| Enclosure | UGREEN 50422, 3.5" USB 3.0 with a 12 V power adapter. Bridge chip is Realtek `0bda:9201`, running in UAS mode. |
| Host | Raspberry Pi 4 Model B, 4 GB, booting from a separate USB SSD |

The enclosure has its own power supply, which matters on a Pi 4: all the USB ports share a power budget of about 1.2 A, and the boot SSD already uses part of it. `vcgencmd get_throttled` should keep reporting `0x0`.

The Realtek bridge isn't in smartctl's database, so SMART commands need `-d sat`:

```bash
sudo smartctl -d sat -H -A /dev/disk/by-id/ata-WDC_WD40EFPX-<serial>
```

Baseline on arrival (2026-10-08): health PASSED, 0 reallocated, pending or uncorrectable sectors, 0 CRC errors, 26 °C, short self-test passed.

## Design decisions

### One disk, many front-ends
The disk is mounted once at `/mnt/storage`. Each app is bind-mounted only the folders it needs, read-only where possible, so every app works on the same files with no copies.

```
/mnt/storage
├── photos/      raw/, edited/, exports/
├── videos/
├── documents/
└── media/       movies/, tv/, music/
```

- **App data stays on the SSD.** Databases and configs live in each service's folder in this repo (as `envelope/db` does). The HDD only holds user files.
- **One owner for every file.** All files are owned by `alekspi` (UID/GID 1000). Every container that writes to the disk runs as that user, or forces it, so files created through one app are never "permission denied" in another.

### Filesystem: ext4, mounted by UUID with `nofail`
- **ext4:** a mature, reliable Linux filesystem. Clients never touch the disk directly (they go through Samba), so it doesn't matter that macOS can't read ext4.
- **Mounted by UUID:** USB disk names (`/dev/sda`, `/dev/sdb`) can swap between boots. A UUID never changes.
- **`nofail` with a 10s device timeout:** a missing disk doesn't block boot.
- **`noatime`:** reading a file doesn't trigger a write.
- **`-m 0`:** don't reserve 5% (~200 GB) for root, which only makes sense on a system disk.
- **`-i 65536`:** one inode (a file-tracking slot) per 64 KB of disk, about 61 M in total. The default would reserve about 60 GB for inodes that a disk of mostly large files never uses. This ratio still leaves room for millions of small files, and it can't be changed after formatting.

### Access: Samba first
[Samba](../samba) serves `/mnt/storage` over SMB, which every OS on the tailnet supports natively: Finder on macOS, File Explorer on Windows, the file manager or `cifs` mounts on Linux, and the Files app ("Connect to Server") on iPhone.

- **Not routed through Traefik.** SMB isn't HTTP. Samba listens on port 445 directly, in Docker with host networking.
- **Security comes from the network.** The router forwards nothing, and every share needs a login. Samba's `hosts allow` only accepts the LAN (`192.168.178.0/24`) and the tailnet (`100.64.0.0/10`, plus Tailscale's IPv6 range `fd7a:115c:a1e0::/48`). This is a second lock behind the router, mainly in case the Pi ever gets a reachable public IPv6 address. It doesn't keep out devices on the LAN; the login does that.
- **One login per person, one share.** `storage` exposes the whole disk to everyone in the `smbusers` group. Every user is written to disk as `alekspi`, so ownership stays consistent. As the Pi's admin, I can always see every file.
- **A recycle bin.** SMB deletes files immediately, and two people can write everywhere. Samba moves deleted files to `.recycle/<username>/` instead, and a cron job empties anything older than 30 days.
- **No SMB encryption.** The Pi 4's CPU has no hardware AES, so SMB encryption would cut throughput badly. On the LAN this is an accepted trade-off. Remotely, Tailscale already encrypts the traffic with WireGuard, whose ChaCha20 cipher runs fine on the Pi.
- **macOS compatibility:** `vfs_fruit` + `streams_xattr`. Finder browsing is faster and tags and metadata are preserved.
- **Bulk copies use the LAN IP.** Going through the Tailscale IP or `*.kaoshome.dev` works from anywhere, but it's slower on a Pi 4 because the Pi encrypts every byte.

### Web UI: deferred
The iPhone Files app already covers mobile access over SMB, so a web file manager isn't needed yet. If it turns out to be useful later, for example because I'd like to have a browser UI or I want per-person folders and search, the choice is **[FileBrowser Quantum](https://github.com/gtsteffaniak/filebrowser)** on the `1.5-stable` tag, behind Traefik like the other web services. The original [File Browser](https://github.com/filebrowser/filebrowser) was archived on 2026-08-31 with unfixed security issues and must not be used.

### Backups: undecided
Until this is decided, the disk is the **only copy** of anything that no longer exists elsewhere. As long as the photos also stay on the Mac, there are two copies. Decide this before deleting anything from the Mac.

What a backup protects against that the recycle bin doesn't: the disk dying, filesystem corruption, a power surge, theft or fire, and ransomware on any device that has the share mounted (it encrypts files in place, so nothing reaches `.recycle`).

The option on the table is **restic → Backblaze B2**:
- Runs nightly. Data is encrypted on the Pi before upload, and only changes are sent. Keeps 7 daily, 4 weekly and 12 monthly snapshots.
- Covers `photos/`, `videos/` and `documents/`, the irreplaceable data. Leaves out `media/` (movies, TV, music), which is replaceable and would make up most of the bill.
- Costs about $6/TB per month. 60 GB is about $0.40/month.
- The restic password goes in a password manager. Without it the backup can't be restored.

Alternatives: restic to a second USB disk kept somewhere else, a Hetzner Storage Box, or a Pi at a family member's place over Tailscale.

### Later
- **More apps on the same folders:** Navidrome (music, light), Jellyfin (movies; fine for direct play, but the Pi 4 is weak at transcoding), Immich (photos; tight on 4 GB RAM, better on a NAS).
- **NAS migration:** buy the NAS and a second WD Red Plus, create the pool on the new disk, and copy everything over the network. Then add this disk to the NAS as a mirror. The UGREEN enclosure becomes the enclosure for a local backup disk.

### Out of scope
- Public sharing (share links, client galleries, Tailscale Funnel).
- Nextcloud (too heavy for a Pi 4).
- RAID on the Pi. Redundancy comes with the NAS, and backups come from B2.

## Setting up the disk
These steps run on the Raspberry Pi. **Always address the drive by its `by-id` path.** The boot disk is also a USB disk, and formatting the wrong one wipes the system.

1. Identify the drive

```bash
lsblk -o NAME,SIZE,MODEL,SERIAL,TRAN,FSTYPE,MOUNTPOINTS
ls -l /dev/disk/by-id/ | grep -v part
```

The WD shows up as `WDC WD40EFPX…`, about 3.6T, with no partitions. Note its `ata-WDC_WD40EFPX-…` id.

2. Partition and format

```bash
DISK=/dev/disk/by-id/ata-WDC_WD40EFPX-<serial>

sudo apt install -y parted
sudo parted --script "$DISK" mklabel gpt mkpart storage ext4 1MiB 100%
sudo partprobe "$DISK"
lsblk "$DISK"   # a single ~3.6T partition

sudo mkfs.ext4 -L storage -m 0 -i 65536 "${DISK}-part1"
```

After formatting, the drive stays busy for a while even when idle. That's ext4 initializing its metadata in the background, which is normal.

3. Mount it permanently

```bash
sudo mkdir -p /mnt/storage
sudo cp /etc/fstab /etc/fstab.bak
UUID=$(sudo blkid -s UUID -o value "${DISK}-part1")
echo "UUID=$UUID  /mnt/storage  ext4  defaults,noatime,nofail,x-systemd.device-timeout=10s  0  2" | sudo tee -a /etc/fstab
sudo systemctl daemon-reload
sudo mount -a
df -h /mnt/storage
```

4. Set ownership and create the folders

```bash
id   # expect uid=1000(alekspi) gid=1000(alekspi)
sudo chown alekspi:alekspi /mnt/storage
mkdir -p /mnt/storage/{photos/{raw,edited,exports},videos,documents,media/{movies,tv,music}}
```

5. Reboot and verify

```bash
sudo reboot
# after it comes back:
findmnt /mnt/storage
```

6. Protect the empty mount point

If the disk is missing at boot (`nofail`), `/mnt/storage` is just an empty folder on the boot SSD. Samba and any other container would then write into that folder without noticing. Making the folder itself immutable while the disk is unmounted turns that into an error instead. The flag stays on the folder underneath and doesn't affect the mounted disk.

```bash
sudo umount /mnt/storage
sudo chattr +i /mnt/storage
lsattr -d /mnt/storage   # shows "----i---------e-------"
sudo mount /mnt/storage
touch /mnt/storage/test && rm /mnt/storage/test   # writes to the mounted disk still work
```

Stop any container using the disk before unmounting.

## Status
- [x] Drive and enclosure installed, SMART baseline clean
- [x] Disk partitioned, formatted and mounted at `/mnt/storage`
- [x] Empty mount point made immutable (setup step 6)
- [x] Samba service running, both logins working ([samba/](../samba))
- [x] Recycle bin cleanup cron job

## Open questions
- **Backups:** off-site or not, and where (see [Backups](#backups-undecided)).
- **Spin-down:** the drive currently never sleeps. Leaving it spinning is fine for a NAS drive; letting it sleep saves a few watts and the hum, at the cost of a few seconds' wait on first access.
- **Time Machine:** Samba can also act as a Time Machine target for the Mac (a separate share with a size limit).
