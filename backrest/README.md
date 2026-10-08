# Backrest
[Backrest](https://github.com/garethgeorge/backrest) is a web UI and scheduler for [restic](https://restic.net). Every night it backs up the irreplaceable folders of the [storage disk](../storage) to Backblaze B2. Data is encrypted on the Pi before it leaves, only changes are uploaded and old versions are kept. Through the UI you can see whether backups ran, browse old snapshots and restore files. It's available at `https://backrest.kaoshome.dev`, behind Traefik like the other web services.

See [storage/README.md](../storage/README.md#backups-restic--backblaze-b2) for why it's set up this way.

| Setting | Value |
|---|---|
| Backed up | `photos/`, `videos/`, `documents/` |
| Not backed up | `media/` (replaceable), `.recycle/`, `restores/` |
| Schedule | Every night at 03:00 |
| Kept | 7 daily, 4 weekly, 12 monthly snapshots |
| Destination | Backblaze B2, EU Central, through its S3-compatible API (restic's recommended way) |

## What you must keep safe
Store these in a password manager **before** the first backup. They don't live in git (`backrest/config/` is gitignored), and if the Pi's SSD dies, they're the only way to get your data back:

- **restic repository password.** Without it the backup can't be decrypted by anyone, including Backblaze and you.
- **B2 application key ID and application key**
- **Bucket name and S3 endpoint**

## Setup

### 1. Backblaze B2
1. **Create an account** at [backblaze.com](https://www.backblaze.com/sign-up/cloud-storage). On the sign-up page, set the region to **EU Central**. It can't be changed later, and every bucket lives in the account's region.
2. **Create a bucket** (B2 Cloud Storage → Buckets → Create a Bucket):
   - Name: anything globally unique, e.g. `kaos-backup-<random>`
   - Files in bucket: **Private**
   - Default encryption: off (restic already encrypts everything). Object Lock: off.
3. **Lifecycle settings** for the bucket: **Keep only the last version of the file**. restic recommends this, because otherwise deleted data lingers as hidden versions and keeps costing money.
4. **Note the bucket's Endpoint**, shown on the bucket card, e.g. `s3.eu-central-003.backblazeb2.com`.
5. **Create an application key** (Application Keys → Add a New Application Key):
   - Name: `kaos-backrest`
   - Allow access to bucket: **only the bucket above**
   - Type of access: **Read and Write**
   - Copy the **keyID** and **applicationKey** right away. The key is shown only once. The account's master key won't work here, because it isn't accepted by the S3 API.

### 2. Repository password
Generate one and save it in your password manager:

```bash
openssl rand -base64 32
```

### 3. Start Backrest on the Pi

```bash
cd ~/kaos/backrest
mkdir -p data config cache         # must exist before starting, so they're owned by alekspi, not root
mkdir -p /mnt/storage/restores     # same, on the storage disk
docker compose up -d
docker logs backrest               # ends with "starting web server"
```

Traefik picks up `traefik/dynamic/backrest.yml` automatically.

### 4. First login
Open `https://backrest.kaoshome.dev`. Set the instance ID to `kaos` and create the admin username and password. Save them in your password manager as well.

### 5. Add the repository
**Repositories → Add Repository**:

| Field | Value |
|---|---|
| Name | `b2` |
| Repository URI | `s3:https://<endpoint>/<bucket-name>/kaos`, e.g. `s3:https://s3.eu-central-003.backblazeb2.com/kaos-backup-xyz/kaos` |
| Password | the repository password from step 2 |
| Env vars | `AWS_ACCESS_KEY_ID=<keyID>` and `AWS_SECRET_ACCESS_KEY=<applicationKey>` |
| Prune policy | monthly (e.g. `0 5 1 * *`), defaults otherwise |
| Check policy | monthly (e.g. `0 6 15 * *`), defaults otherwise |

Submit. Backrest initializes the repository in the bucket.

### 6. Add the plan
**Plans → Add Plan**:

| Field | Value |
|---|---|
| Name | `storage` |
| Repository | `b2` |
| Paths | `/userdata/photos`, `/userdata/videos`, `/userdata/documents` |
| Excludes | `.DS_Store`, `._*` |
| Schedule | cron `0 3 * * *` (every night at 03:00) |
| Retention | by time period: 7 daily, 4 weekly, 12 monthly |

### 7. First backup
Click **Backup Now** on the plan. The first run uploads everything, so it takes hours, depending on your upload speed: about 3–4 hours for 60 GB at 40 Mbit/s. Later runs only upload what changed. If the first run gets interrupted, the next run continues where it left off.

### 8. Test a restore
A backup you've never restored from isn't a backup yet. In Backrest, open the latest snapshot, pick a file, and choose **Restore to path** with `/restores/test`. It shows up in the Samba share under `restores/test/`. Check that it opens, then delete the test folder.

### 9. Optional: alert when backups fail
Backrest can notify on errors through **hooks** (Plan → Hooks). A free [Healthchecks.io](https://healthchecks.io) check is a good fit: it alerts if a backup fails **and** if one simply never runs.

## Restoring files
- **A few files:** open the snapshot in Backrest → Restore to path → `/restores/<something>`, then move the files back to where they belong through Samba.
- **Everything, or Backrest itself is gone:** install restic anywhere (`brew install restic`), set `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY`, then run `restic -r s3:https://<endpoint>/<bucket>/kaos restore latest --target <dir>`. You only need the four items from [What you must keep safe](#what-you-must-keep-safe). Downloads are free up to 3× the amount stored per month.

## Ransomware
Only the Pi has the B2 key. A device with the share mounted can encrypt files on the disk, but it can't touch the backups. The encrypted files would be uploaded as a new snapshot, while the older snapshots stay intact for up to 12 months. If something like that happens, restore from a snapshot taken before it.

## Costs
B2 charges $6.95/TB per month, and the first 10 GB are free. At 60 GB that's about $0.35/month. Around 500 GB, a Hetzner Storage Box (€3.20/month flat for 1 TB) **becomes cheaper**! restic supports it too, so switching is a new repository and one full upload.