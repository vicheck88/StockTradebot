#!/bin/bash
set -Eeuo pipefail

expectedSerial="S5TGNJ0RA02757K"
sourceData="/var/lib/postgresql/11/main_sd"
activeData="/var/lib/postgresql/11/main"
ssdData="/var/lib/postgresql/11/main_ssd"
temporaryMount="/mnt/postgresql-ssd"
service="postgresql@11-main.service"

if [ "$(id -u)" -ne 0 ]; then
  exec sudo "$0" "$@"
fi

device="${1:-}"
confirmation="${2:-}"

if [ -z "$device" ] || [ "$confirmation" != "--confirm-erase" ]; then
  echo "Usage: $0 /dev/sdX --confirm-erase" >&2
  exit 2
fi

if [ ! -b "$device" ] || [ "$(lsblk -ndo TYPE "$device")" != "disk" ]; then
  echo "Not a disk device: $device" >&2
  exit 2
fi

if [[ "$device" == /dev/mmcblk* ]] || [ "$device" = "/dev/root" ]; then
  echo "Refusing to erase the Raspberry Pi SD card" >&2
  exit 2
fi

serial="$(
  udevadm info --query=property --name="$device" |
    sed -n 's/^ID_SERIAL_SHORT=//p' |
    head -1
)"
if [ "$serial" != "$expectedSerial" ]; then
  echo "Unexpected SSD serial: ${serial:-unknown}" >&2
  echo "Expected Samsung T7 serial: $expectedSerial" >&2
  exit 2
fi

if [ ! -d "$sourceData" ] || [ ! -f "$sourceData/PG_VERSION" ]; then
  echo "SD PostgreSQL source is missing: $sourceData" >&2
  exit 2
fi

rollback(){
  set +e
  systemctl stop "$service"
  umount "$temporaryMount" 2>/dev/null
  umount "$ssdData" 2>/dev/null
  ln -sfn "$sourceData" "$activeData"
  if [ -f /etc/systemd/system/postgresql@11-main.service.d/ssd.conf ]; then
    mv /etc/systemd/system/postgresql@11-main.service.d/ssd.conf \
      /etc/systemd/system/postgresql@11-main.service.d/ssd.conf.failed
  fi
  systemctl daemon-reload
  systemctl start "$service"
  echo "Migration failed; PostgreSQL was switched back to the SD card" >&2
}
trap rollback ERR

pkill -TERM -f '[I]nsertCorpData\.R' 2>/dev/null || true
sleep 3
systemctl stop "$service"

if systemctl is-active --quiet "$service"; then
  echo "PostgreSQL did not stop" >&2
  exit 1
fi

sourceState="$(
  runuser -u postgres -- /usr/lib/postgresql/11/bin/pg_controldata "$sourceData" |
    sed -n 's/^Database cluster state:[[:space:]]*//p'
)"
if [ "$sourceState" != "shut down" ]; then
  echo "PostgreSQL source is not cleanly shut down: $sourceState" >&2
  exit 1
fi

while read -r mountedPath; do
  [ -z "$mountedPath" ] || umount "$mountedPath"
done < <(lsblk -nrpo MOUNTPOINT "$device" | awk 'NF')

wipefs --all "$device"
printf 'label: gpt\n, , L\n' | sfdisk "$device"
partprobe "$device"
udevadm settle

partition="${device}1"
if [ ! -b "$partition" ]; then
  echo "SSD partition was not created: $partition" >&2
  exit 1
fi

mkfs.ext4 -F -L postgres_ssd "$partition"
install -d -o postgres -g postgres -m 700 "$temporaryMount" "$ssdData"
mount "$partition" "$temporaryMount"
chown postgres:postgres "$temporaryMount"
chmod 700 "$temporaryMount"

rsync -aHAX --numeric-ids --delete "$sourceData/" "$temporaryMount/"
sync

differences="$(
  rsync -aHAXnci --numeric-ids --delete "$sourceData/" "$temporaryMount/"
)"
if [ -n "$differences" ]; then
  echo "SSD copy verification failed:" >&2
  echo "$differences" >&2
  exit 1
fi

sourceSystemId="$(
  runuser -u postgres -- /usr/lib/postgresql/11/bin/pg_controldata "$sourceData" |
    sed -n 's/^Database system identifier:[[:space:]]*//p'
)"
targetSystemId="$(
  runuser -u postgres -- /usr/lib/postgresql/11/bin/pg_controldata "$temporaryMount" |
    sed -n 's/^Database system identifier:[[:space:]]*//p'
)"
if [ "$sourceSystemId" != "$targetSystemId" ]; then
  echo "PostgreSQL system identifier mismatch" >&2
  exit 1
fi

uuid="$(blkid -s UUID -o value "$partition")"
fstabTemporary="$(mktemp)"
awk '$2 != "/var/lib/postgresql/11/main_ssd" { print }' /etc/fstab > "$fstabTemporary"
printf 'UUID=%s /var/lib/postgresql/11/main_ssd ext4 defaults,nofail,noatime 0 2\n' "$uuid" >> "$fstabTemporary"
install -o root -g root -m 644 "$fstabTemporary" /etc/fstab

umount "$temporaryMount"
mount "$ssdData"

linkBackup="/var/lib/postgresql/11/main.sd-link-$(date +%Y%m%d_%H%M%S)"
cp -a "$activeData" "$linkBackup"
ln -sfn "$ssdData" "$activeData"

install -d -o root -g root -m 755 /etc/systemd/system/postgresql@11-main.service.d
cat > /etc/systemd/system/postgresql@11-main.service.d/ssd.conf <<EOF
[Unit]
RequiresMountsFor=$ssdData
EOF

systemctl daemon-reload
systemctl start "$service"
sleep 5

runuser -u postgres -- pg_isready -h /var/run/postgresql -p 5432
runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -d stocks -c \
  'SELECT count(*) AS annual_rows FROM metainfo."연간재무제표"'
runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -d stocks -c \
  'SELECT count(*) AS quarterly_rows FROM metainfo."분기재무제표"'
runuser -u postgres -- psql -X -v ON_ERROR_STOP=1 -d stocks -c \
  'SELECT count(*) AS monthly_rows FROM metainfo."월별기업정보"'

trap - ERR
echo "PostgreSQL SSD migration completed"
echo "The SD copy remains at $sourceData for rollback"
