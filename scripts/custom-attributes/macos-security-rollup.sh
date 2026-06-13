#!/bin/sh

PATH="/usr/local/bin:/opt/osquery/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAB="$(printf '\t')"

OSQUERYI="${OSQUERYI_PATH:-/usr/local/bin/osqueryi}"
EXTENSION="${MACADMINS_EXTENSION_PATH:-/usr/local/bin/macadmins_extension.ext}"
EXTENSION_LOAD_WAIT="${EXTENSION_LOAD_WAIT:-5}"
EXTENSIONS_TIMEOUT="${EXTENSIONS_TIMEOUT:-15}"

q() {
  { sleep "$EXTENSION_LOAD_WAIT"; printf '%s\n' "$1" '.quit'; } | \
    "$OSQUERYI" --extension "$EXTENSION" --allow_unsafe --extensions_timeout "$EXTENSIONS_TIMEOUT" --csv --header=false --separator "$TAB" 2>/dev/null
}

number_or_unavailable() {
  case "$1" in
    ''|*[!0-9]*) printf '%s\n' "unavailable" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

strip_quotes() {
  printf '%s\n' "$1" | sed 's/^"//; s/"$//'
}

clean_mdm_pair() {
  enrolled="$(printf '%s\n' "$1" | awk -F/ '{print $1}')"
  approved="$(printf '%s\n' "$1" | awk -F/ '{print $2}')"
  enrolled="$(strip_quotes "$enrolled")"
  approved="$(strip_quotes "$approved")"
  [ -n "$enrolled" ] || enrolled="unknown"
  [ -n "$approved" ] || approved="unknown"
  printf '%s/%s\n' "$enrolled" "$approved"
}

if [ -z "$OSQUERYI" ] || [ ! -x "$OSQUERYI" ] || [ -z "$EXTENSION" ] || [ ! -x "$EXTENSION" ]; then
  printf '%s\n' "unavailable"
  exit 0
fi

os_version="$(q "select version from os_version limit 1;" | awk -F "$TAB" 'NR == 1 {print $1}')"
rsr="$(q "select rsr_version from macos_rsr limit 1;" | awk -F "$TAB" 'NR == 1 {print $1}')"
mdm="$(q "select enrolled, user_approved from mdm limit 1;" | awk -F "$TAB" 'NR == 1 {print $1 "/" $2}')"
fv_users="$(q "select count(*) from filevault_users;" | awk -F "$TAB" 'NR == 1 {print $1}')"
pending_updates="$(q "select count(*) from pending_apple_updates;" | awk -F "$TAB" 'NR == 1 {print $1}')"
sofa="$(q "select count(*) as unpatched, sum(case when actively_exploited = 'true' then 1 else 0 end) as exploited from sofa_unpatched_cves;" | awk -F "$TAB" 'NR == 1 {print $1 "/" $2}')"
local_net_denied="$(q "select count(*) from local_network_permissions where state = 0;" | awk -F "$TAB" 'NR == 1 {print $1}')"

[ -n "$os_version" ] || os_version="unknown"
[ -n "$rsr" ] || rsr="none"
rsr="$(strip_quotes "$rsr")"
[ -n "$rsr" ] || rsr="none"
[ -n "$mdm" ] || mdm="unknown/unknown"
mdm="$(clean_mdm_pair "$mdm")"
[ -n "$fv_users" ] || fv_users="unavailable"
fv_users="$(number_or_unavailable "$fv_users")"
[ -n "$pending_updates" ] || pending_updates="unavailable"
pending_updates="$(number_or_unavailable "$pending_updates")"
[ -n "$sofa" ] || sofa="unknown/unknown"
[ -n "$local_net_denied" ] || local_net_denied="unavailable"
local_net_denied="$(number_or_unavailable "$local_net_denied")"

sofa_unpatched="$(printf '%s\n' "$sofa" | awk -F/ '{print $1}')"
sofa_exploited="$(printf '%s\n' "$sofa" | awk -F/ '{print $2}')"
sofa_unpatched="$(number_or_unavailable "$sofa_unpatched")"
sofa_exploited="$(number_or_unavailable "$sofa_exploited")"

printf 'os=%s; rsr=%s; mdm=%s; fv_users=%s; pending_updates=%s; sofa_unpatched=%s; exploited=%s; local_net_denied=%s\n' \
  "$os_version" "$rsr" "$mdm" "$fv_users" "$pending_updates" "$sofa_unpatched" "$sofa_exploited" "$local_net_denied"
