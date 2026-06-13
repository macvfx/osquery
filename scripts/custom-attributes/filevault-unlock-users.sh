#!/bin/sh

PATH="/usr/local/bin:/opt/osquery/bin:/usr/bin:/bin:/usr/sbin:/sbin"

OSQUERYI="${OSQUERYI_PATH:-/usr/local/bin/osqueryi}"
EXTENSION="${MACADMINS_EXTENSION_PATH:-/usr/local/bin/macadmins_extension.ext}"
EXTENSION_LOAD_WAIT="${EXTENSION_LOAD_WAIT:-5}"
EXTENSIONS_TIMEOUT="${EXTENSIONS_TIMEOUT:-15}"

if [ -z "$OSQUERYI" ] || [ ! -x "$OSQUERYI" ] || [ -z "$EXTENSION" ] || [ ! -x "$EXTENSION" ]; then
  printf '%s\n' "unavailable"
  exit 0
fi

users="$({ sleep "$EXTENSION_LOAD_WAIT"; printf '%s\n' \
  "select username from filevault_users order by username;" \
  '.quit'; } | "$OSQUERYI" --extension "$EXTENSION" --allow_unsafe --extensions_timeout "$EXTENSIONS_TIMEOUT" --csv --header=false 2>/dev/null | paste -sd, -)"

case "$users" in
  *"runFDESetupList"*|*"Error:"*|*"exit status"*)
    printf '%s\n' "unavailable: fdesetup query failed"
    exit 0
    ;;
esac

if [ -z "$users" ]; then
  printf '%s\n' "0 users"
  exit 0
fi

count="$(printf '%s\n' "$users" | awk -F, '{print NF}')"
printf '%s users: %s\n' "$count" "$users"
