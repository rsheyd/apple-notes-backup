#!/bin/bash

set -eu

readonly PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd -P)"
readonly BACKUP_SCRIPT="$PROJECT_DIR/scripts/notehold-backup.sh"

work_dir=$(/usr/bin/mktemp -d "${TMPDIR:-/tmp}/notehold-backup-email-test.XXXXXX")
cleanup() {
  /bin/rm -rf "$work_dir"
}
trap cleanup EXIT HUP INT TERM

test_home="$work_dir/home"
notes_dir="$work_dir/notes"
backup_dir="$work_dir/backups"
request_body="$work_dir/request.json"
fake_curl="$work_dir/curl"
/bin/mkdir -p "$test_home" "$notes_dir" "$backup_dir"
/usr/bin/printf 'synthetic note data\n' >"$notes_dir/NoteStore.sqlite"

/usr/bin/printf '%s\n' \
  '#!/bin/bash' \
  'set -eu' \
  'output=""' \
  'payload=""' \
  'while [ "$#" -gt 0 ]; do' \
  '  case "$1" in' \
  '    -o) output="$2"; shift 2 ;;' \
  '    --data-binary) payload="${2#@}"; shift 2 ;;' \
  '    *) shift ;;' \
  '  esac' \
  'done' \
  '/bin/cp "$payload" "$NOTEHOLD_TEST_REQUEST_BODY"' \
  '/usr/bin/printf '\''{"id":"test-email"}\n'\'' >"$output"' \
  '/usr/bin/printf 200' >"$fake_curl"
/bin/chmod 755 "$fake_curl"

HOME="$test_home" \
NOTES_DIR="$notes_dir" \
BACKUP_DIR="$backup_dir" \
AUTO_CLEANUP=false \
RESEND_EMAIL_TO="recipient@example.com" \
RESEND_EMAIL_FROM="Notehold <onboarding@resend.dev>" \
NOTEHOLD_RESEND_API_KEY="re_test" \
NOTEHOLD_CURL_COMMAND="$fake_curl" \
NOTEHOLD_TEST_REQUEST_BODY="$request_body" \
  "$BACKUP_SCRIPT" --force

email_text=$(/usr/bin/plutil -extract text raw -o - "$request_body")
/usr/bin/printf '%s\n' "$email_text" | /usr/bin/grep -Eq 'apple-notes-[0-9]{4}-[0-9]{2}-[0-9]{2}\.zip  [0-9.]+ KB'
/usr/bin/printf '%s\n' "$email_text" | /usr/bin/grep -Eq '^Total: 1 backup, [0-9.]+ KB$'

echo "Backup email tests passed."
