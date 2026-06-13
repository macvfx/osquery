#!/bin/sh

PATH="/usr/local/bin:/opt/osquery/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAB="$(printf '\t')"

OSQUERYI="${OSQUERYI_PATH:-/usr/local/bin/osqueryi}"
EXTENSION="${MACADMINS_EXTENSION_PATH:-/usr/local/bin/macadmins_extension.ext}"
EXTENSION_LOAD_WAIT="${EXTENSION_LOAD_WAIT:-5}"
EXTENSIONS_TIMEOUT="${EXTENSIONS_TIMEOUT:-15}"

clean_value() {
  value="$(printf '%s\n' "$1" | sed 's/^"//; s/"$//')"
  if [ -z "$value" ]; then
    printf '%s\n' "unknown"
  else
    printf '%s\n' "$value"
  fi
}

if [ -z "$OSQUERYI" ] || [ ! -x "$OSQUERYI" ] || [ -z "$EXTENSION" ] || [ ! -x "$EXTENSION" ]; then
  printf '%s\n' "unavailable"
  exit 0
fi

row="$({ sleep "$EXTENSION_LOAD_WAIT"; printf '%s\n' \
  "select enrolled, user_approved, installed_from_dep, dep_capable, has_scep_payload from mdm limit 1;" \
  '.quit'; } | "$OSQUERYI" --extension "$EXTENSION" --allow_unsafe --extensions_timeout "$EXTENSIONS_TIMEOUT" --csv --header=false --separator "$TAB" 2>/dev/null)"

if [ -z "$row" ]; then
  printf '%s\n' "unavailable: mdm query failed"
  exit 0
fi

enrolled="$(printf '%s\n' "$row" | awk -F "$TAB" 'NR == 1 {print $1}')"
user_approved="$(printf '%s\n' "$row" | awk -F "$TAB" 'NR == 1 {print $2}')"
installed_from_dep="$(printf '%s\n' "$row" | awk -F "$TAB" 'NR == 1 {print $3}')"
dep_capable="$(printf '%s\n' "$row" | awk -F "$TAB" 'NR == 1 {print $4}')"
has_scep="$(printf '%s\n' "$row" | awk -F "$TAB" 'NR == 1 {print $5}')"

enrolled="$(clean_value "$enrolled")"
user_approved="$(clean_value "$user_approved")"
installed_from_dep="$(clean_value "$installed_from_dep")"
dep_capable="$(clean_value "$dep_capable")"
has_scep="$(clean_value "$has_scep")"

printf 'enrolled=%s; user_approved=%s; dep_enrolled=%s; dep_capable=%s; scep=%s\n' \
  "$enrolled" "$user_approved" "$installed_from_dep" "$dep_capable" "$has_scep"
