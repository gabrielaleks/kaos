#!/usr/bin/env bash
# Permanently deletes files that have been in Samba's recycle bin for more than RETENTION_DAYS.
# Runs daily from alekspi's crontab (see README.md). Results go to the system log:
#   journalctl -t recycle-cleanup
set -uo pipefail

STORAGE=/mnt/storage
RECYCLE="$STORAGE/.recycle"
RETENTION_DAYS="${RETENTION_DAYS:-30}"

# Disk not mounted: nothing to clean
mountpoint -q "$STORAGE" || exit 0
[ -d "$RECYCLE" ] || exit 0

# Age is measured by ctime, which is set when Samba moves the file into the bin.
# atime/mtime would be the file's original times, so old files would be deleted right away.
deleted=$(find "$RECYCLE" -type f -ctime +"$RETENTION_DAYS" -delete -printf '.' | wc -c)

# Remove folders emptied by the step above, but keep each user's .recycle/<username>/
find "$RECYCLE" -mindepth 2 -type d -empty -delete

logger -t recycle-cleanup "deleted $deleted file(s) older than $RETENTION_DAYS days"
