#!/bin/bash

set -eu

readonly BACKUP_DIR="${BACKUP_DIR:-$HOME/Backups/Apple Notes}"

if [ ! -d "$BACKUP_DIR" ]; then
  echo "Backup destination is unavailable: $BACKUP_DIR" >&2
  exit 1
fi

archives=$(
  /usr/bin/find "$BACKUP_DIR" -maxdepth 1 -type f -name 'apple-notes-*.zip' \
    -exec /usr/bin/stat -f '%m|%N' {} \; |
    /usr/bin/sort -rn |
    /usr/bin/cut -d '|' -f2-
)

echo "Notehold backups"
echo "Destination: $BACKUP_DIR"
echo

if [ -z "$archives" ]; then
  echo "No backups found."
  echo
  echo "Total: 0 backups, 0 KB"
  exit 0
fi

backup_count=0
total_kb=0
while IFS= read -r archive; do
  [ -n "$archive" ] || continue
  archive_name=$(/usr/bin/basename "$archive")
  archive_kb=$(/usr/bin/du -k "$archive" | /usr/bin/awk '{ print $1 }')
  archive_size=$(/usr/bin/awk -v kb="$archive_kb" 'BEGIN {
    if (kb >= 1073741824) printf "%.1f TB", kb / 1073741824
    else if (kb >= 1048576) printf "%.1f GB", kb / 1048576
    else if (kb >= 1024) printf "%.1f MB", kb / 1024
    else printf "%d KB", kb
  }')
  archive_date=$(/usr/bin/stat -f '%Sm' -t '%Y-%m-%d %l:%M %p' "$archive" | /usr/bin/sed 's/  */ /g')
  if [ -f "$archive.sha256" ]; then
    checksum_status="checksum present"
  else
    checksum_status="checksum missing"
  fi
  echo "$archive_name  $archive_size  $archive_date  $checksum_status"
  backup_count=$((backup_count + 1))
  total_kb=$((total_kb + archive_kb))
done <<EOF
$archives
EOF

total_size=$(/usr/bin/awk -v kb="$total_kb" 'BEGIN {
  if (kb >= 1073741824) printf "%.1f TB", kb / 1073741824
  else if (kb >= 1048576) printf "%.1f GB", kb / 1048576
  else if (kb >= 1024) printf "%.1f MB", kb / 1024
  else printf "%d KB", kb
}')
echo
if [ "$backup_count" -eq 1 ]; then
  echo "Total: 1 backup, $total_size"
else
  echo "Total: $backup_count backups, $total_size"
fi
