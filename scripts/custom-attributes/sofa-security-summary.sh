#!/bin/sh

PATH="/usr/local/bin:/opt/osquery/bin:/usr/bin:/bin:/usr/sbin:/sbin"
TAB="$(printf '\t')"

OSQUERYI="${OSQUERYI_PATH:-/usr/local/bin/osqueryi}"
EXTENSION="${MACADMINS_EXTENSION_PATH:-/usr/local/bin/macadmins_extension.ext}"
EXTENSION_LOAD_WAIT="${EXTENSION_LOAD_WAIT:-5}"
EXTENSIONS_TIMEOUT="${EXTENSIONS_TIMEOUT:-15}"

run_query() {
  { sleep "$EXTENSION_LOAD_WAIT"; printf '%s\n' "$1" '.quit'; } | \
    "$OSQUERYI" --extension "$EXTENSION" --allow_unsafe --extensions_timeout "$EXTENSIONS_TIMEOUT" --csv --header=false --separator "$TAB" 2>/dev/null
}

if [ -z "$OSQUERYI" ] || [ ! -x "$OSQUERYI" ]; then
  printf '%s\n' "unavailable: osqueryi not found"
  exit 0
fi

if [ -z "$EXTENSION" ] || [ ! -x "$EXTENSION" ]; then
  printf '%s\n' "unavailable: macadmins extension not found"
  exit 0
fi

release_row="$(run_query "select os_version, product_version, unique_cves_count from sofa_security_release_info order by product_version limit 1;")"
cve_row="$(run_query "select count(*) as unpatched, sum(case when actively_exploited = 'true' then 1 else 0 end) as exploited from sofa_unpatched_cves;")"

if [ -z "$release_row" ]; then
  printf '%s\n' "unavailable: sofa query failed"
  exit 0
fi

os_version="$(printf '%s\n' "$release_row" | awk -F "$TAB" 'NR == 1 {print $1}')"
release_version="$(printf '%s\n' "$release_row" | awk -F "$TAB" 'NR == 1 {print $2}')"
release_cves="$(printf '%s\n' "$release_row" | awk -F "$TAB" 'NR == 1 {print $3}')"
unpatched="$(printf '%s\n' "$cve_row" | awk -F "$TAB" 'NR == 1 {print $1}')"
exploited="$(printf '%s\n' "$cve_row" | awk -F "$TAB" 'NR == 1 {print $2}')"

[ -n "$unpatched" ] || unpatched="0"
[ -n "$exploited" ] || exploited="0"

printf 'macOS %s; release %s; CVEs in release %s; unpatched %s; exploited %s\n' \
  "$os_version" "$release_version" "$release_cves" "$unpatched" "$exploited"
