#!/bin/sh

PATH="/usr/local/bin:/opt/osquery/bin:/usr/bin:/bin:/usr/sbin:/sbin"

OSQUERYI="${OSQUERYI_PATH:-/usr/local/bin/osqueryi}"
EXTENSION="${MACADMINS_EXTENSION_PATH:-/usr/local/bin/macadmins_extension.ext}"
EXTENSION_LOAD_WAIT="${EXTENSION_LOAD_WAIT:-5}"
EXTENSIONS_TIMEOUT="${EXTENSIONS_TIMEOUT:-15}"
ERRORS_FILE="$(mktemp "${TMPDIR:-/tmp}/macadmins-osquery-errors.XXXXXX")"
trap 'rm -f "$ERRORS_FILE"' EXIT

json_escape() {
  printf '%s' "$1" | tr '\n\r\t' '   ' | sed 's/\\/\\\\/g; s/"/\\"/g'
}

q_json() {
  section="$1"
  sql="$2"
  err_file="$(mktemp "${TMPDIR:-/tmp}/macadmins-osquery-stderr.XXXXXX")"
  out="$({ sleep "$EXTENSION_LOAD_WAIT"; printf '%s\n' "$sql" '.quit'; } | \
    "$OSQUERYI" --extension "$EXTENSION" --allow_unsafe --extensions_timeout "$EXTENSIONS_TIMEOUT" --json 2>"$err_file")"
  status="$?"
  err="$(cat "$err_file" 2>/dev/null)"
  rm -f "$err_file"

  if [ "$status" -ne 0 ] || [ -z "$out" ] || printf '%s\n' "$err" | grep -Eq 'Error:|no such table|Extensions disabled|cannot start extension manager'; then
    if [ -z "$err" ]; then
      err="empty output"
    fi
    printf '{"section":"%s","status":%s,"message":"%s"}\n' \
      "$(json_escape "$section")" "$status" "$(json_escape "$err")" >> "$ERRORS_FILE"
    printf '[]\n'
    return 0
  fi

  printf '%s\n' "$out"
}

q_builtin_json() {
  section="$1"
  sql="$2"
  err_file="$(mktemp "${TMPDIR:-/tmp}/macadmins-osquery-stderr.XXXXXX")"
  out="$("$OSQUERYI" --json "$sql" 2>"$err_file")"
  status="$?"
  err="$(cat "$err_file" 2>/dev/null)"
  rm -f "$err_file"

  if [ "$status" -ne 0 ] || [ -z "$out" ]; then
    if [ -z "$err" ]; then
      err="empty output"
    fi
    printf '{"section":"%s","status":%s,"message":"%s"}\n' \
      "$(json_escape "$section")" "$status" "$(json_escape "$err")" >> "$ERRORS_FILE"
    printf '[]\n'
    return 0
  fi

  printf '%s\n' "$out"
}

print_query_errors() {
  printf '['
  if [ -s "$ERRORS_FILE" ]; then
    awk 'BEGIN { first = 1 } { if (!first) printf ","; printf "\n    %s", $0; first = 0 } END { if (!first) printf "\n  " }' "$ERRORS_FILE"
  fi
  printf ']'
}

if [ -z "$OSQUERYI" ] || [ ! -x "$OSQUERYI" ]; then
  printf '%s\n' '{"error":"osqueryi not found"}'
  exit 0
fi

if [ -z "$EXTENSION" ] || [ ! -x "$EXTENSION" ]; then
  printf '%s\n' '{"error":"macadmins extension not found"}'
  exit 0
fi

generated_at="$(date -u '+%Y-%m-%dT%H:%M:%SZ')"
host="$(hostname 2>/dev/null || printf 'unknown')"

report="$(
  printf '{\n'
  printf '  "generated_at": "%s",\n' "$(json_escape "$generated_at")"
  printf '  "host": "%s",\n' "$(json_escape "$host")"
  printf '  "os_version": '
  q_builtin_json 'os_version' 'select name, version, build, platform from os_version limit 1;'
  printf ',\n  "system": '
  q_json 'system' 'select hostname, uuid, hardware_model, hardware_serial, cpu_brand, physical_memory from alt_system_info limit 1;'
  printf ',\n  "mdm": '
  q_json 'mdm' 'select enrolled, user_approved, installed_from_dep, dep_capable, has_scep_payload, server_url, install_date, payload_identifier from mdm limit 1;'
  printf ',\n  "filevault_users": '
  q_json 'filevault_users' 'select username, uuid from filevault_users order by username;'
  printf ',\n  "macos_rsr": '
  q_json 'macos_rsr' 'select rsr_version, macos_version, full_macos_version, rsr_supported from macos_rsr limit 1;'
  printf ',\n  "pending_apple_updates": '
  q_json 'pending_apple_updates' 'select display_name, display_version, identifier, product_key from pending_apple_updates order by display_name;'
  printf ',\n  "sofa_security_release_info": '
  q_json 'sofa_security_release_info' 'select update_name, product_version, release_date, unique_cves_count, days_since_previous_release, os_version, security_info from sofa_security_release_info order by product_version limit 5;'
  printf ',\n  "sofa_unpatched_cves": '
  q_json 'sofa_unpatched_cves' 'select cve, patched_version, actively_exploited, url from sofa_unpatched_cves order by actively_exploited desc, cve;'
  printf ',\n  "local_network_permissions_denied": '
  q_json 'local_network_permissions_denied' 'select bundle_id, display_name, executable_path, type, state from local_network_permissions where state = 0 order by display_name;'
  printf ',\n  "query_errors": '
  print_query_errors
  printf '\n}\n'
)"

printf '%s\n' "$report"

if [ -n "${REPORT_PATH:-}" ]; then
  report_dir="$(dirname "$REPORT_PATH")"
  if [ -d "$report_dir" ] || mkdir -p "$report_dir" 2>/dev/null; then
    printf '%s\n' "$report" > "$REPORT_PATH"
  fi
fi
