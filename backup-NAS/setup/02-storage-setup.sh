#!/usr/bin/env bash
# Phase 2: Storage setup - RAID configuration and mount points
set -euo pipefail

echo "=== Storage Setup ==="
echo ""

# --- Detect drives ---
echo "[1/4] Detecting available drives..."
echo ""
lsblk -d -o NAME,SIZE,MODEL,SERIAL,TYPE | grep disk
echo ""

echo "Enter the drives to use for NAS array (space-separated, e.g., 'sda sdb'):"
read -p "> " DRIVES

DRIVE_COUNT=$(echo "$DRIVES" | wc -w)
DRIVE_PATHS=""
for d in $DRIVES; do
  DRIVE_PATHS="$DRIVE_PATHS /dev/$d"
done

echo ""
echo "Drives selected: $DRIVE_PATHS"
echo "Drive count: $DRIVE_COUNT"
echo ""

# --- SMART check ---
echo "[2/4] Running SMART health check..."
for d in $DRIVES; do
  echo "  /dev/$d:"
  smartctl -H "/dev/$d" 2>/dev/null | grep -E "SMART overall|result" || echo "    (SMART not available)"
done
echo ""

# --- RAID setup ---
if [ "$DRIVE_COUNT" -eq 2 ]; then
  RAID_LEVEL="1"
  echo "2 drives detected -> RAID1 (mirror)"
elif [ "$DRIVE_COUNT" -eq 4 ]; then
  echo "4 drives detected. Choose RAID level:"
  echo "  1) RAID10 - Mirrored stripes (best performance + safety, 50% capacity)"
  echo "  2) RAID5  - Distributed parity (75% capacity, slower writes)"
  read -p "> " RAID_CHOICE
  if [ "$RAID_CHOICE" = "2" ]; then
    RAID_LEVEL="5"
  else
    RAID_LEVEL="10"
  fi
else
  echo "Unsupported drive count: $DRIVE_COUNT (need 2 or 4)"
  exit 1
fi

echo ""
echo "Creating RAID$RAID_LEVEL array with: $DRIVE_PATHS"
echo "WARNING: This will ERASE all data on these drives!"
read -p "Continue? (yes/no) > " CONFIRM
[ "$CONFIRM" = "yes" ] || exit 1

mdadm --create /dev/md0 --level="$RAID_LEVEL" --raid-devices="$DRIVE_COUNT" $DRIVE_PATHS

# Wait for initial sync to start
sleep 2
cat /proc/mdstat

# --- Filesystem ---
echo "[3/4] Creating filesystem..."
mkfs.ext4 -L nas-storage /dev/md0

# --- Mount ---
echo "[4/4] Mounting and configuring..."
mkdir -p /mnt/nas
mount /dev/md0 /mnt/nas

# Add to fstab
echo "/dev/md0  /mnt/nas  ext4  defaults,noatime  0  2" >> /etc/fstab

# Save RAID config
mdadm --detail --scan >> /etc/mdadm/mdadm.conf
update-initramfs -u

# --- Directory structure ---
echo "Creating directory structure..."
mkdir -p /mnt/nas/{media/{movies,shows,music,downloads,uploads},backups/{restic-repo,db-dumps,keepass},shared}
chown -R 1000:1000 /mnt/nas/media
chmod -R 775 /mnt/nas/media

echo ""
echo "=== Storage setup complete ==="
echo ""
lsblk /dev/md0
df -h /mnt/nas
echo ""
echo "RAID status:"
mdadm --detail /dev/md0 | grep -E "State|Size|Level|Devices"
echo ""
echo "Next: ./03-backup-target.sh"
