# SimpleMDM scripts for MacAdmins osquery extension

These scripts are meant to be pasted into SimpleMDM scripts, used as Custom Attributes, or used as starting points for longer collection jobs.

They are built around the [MacAdmins osquery extension](https://github.com/macadmins/osquery-extension).

They assume:

- `osqueryi` is installed at `/usr/local/bin/osqueryi`.
- The MacAdmins extension binary is deployed at `/usr/local/bin/macadmins_extension.ext`.
- The extension can be loaded by `osqueryi --extension`.

The official osquery package may still install the app bundle and support files under `/opt/osquery`. These scripts intentionally call `/usr/local/bin/osqueryi` because that is a common symlink or wrapper path for scripts and MDM tooling.

Set these environment variables in SimpleMDM only if your paths differ:

```sh
OSQUERYI_PATH="/usr/local/bin/osqueryi"
MACADMINS_EXTENSION_PATH="/usr/local/bin/macadmins_extension.ext"
EXTENSION_LOAD_WAIT="5"
EXTENSIONS_TIMEOUT="15"
```

The scripts do not search multiple paths. Fixed paths make SimpleMDM Custom Attribute troubleshooting much easier.

The MacAdmins extension waits briefly before registering its tables. The scripts account for that with `EXTENSION_LOAD_WAIT`, which defaults to 5 seconds.

## Custom Attribute scripts

Each script prints one short line.

| Script | Suggested attribute name | Output example |
| --- | --- | --- |
| `scripts/custom-attributes/sofa-security-summary.sh` | `SOFA Security Summary` | `macOS 15.5; release 15.5; CVEs in release 42; unpatched 0; exploited 0` |
| `scripts/custom-attributes/sofa-unpatched-cve-count.sh` | `SOFA Unpatched CVEs` | `0` |
| `scripts/custom-attributes/mdm-security-summary.sh` | `MDM Security Summary` | `enrolled=true; user_approved=true; dep_enrolled=true; dep_capable=true; scep=true` |
| `scripts/custom-attributes/filevault-unlock-users.sh` | `FileVault Unlock Users` | `2 users: user1,user2` |
| `scripts/custom-attributes/macos-security-rollup.sh` | `macOS Security Rollup` | `os=15.5; rsr=none; mdm=true/true; fv_users=2; pending_updates=0; sofa_unpatched=0; exploited=0; local_net_denied=1` |

## Longer report script

`scripts/reports/macos-security-report.sh` prints a JSON object with multiple osquery result sets. Use it when a one-line Custom Attribute is too cramped.

The report includes a `query_errors` array. If the extension is not loading, the extension-backed sections will be empty and `query_errors` will show the osquery error, such as a missing table or an extension manager socket failure.

The report includes these sections:

| Section | Source | Notes |
| --- | --- | --- |
| `generated_at` | shell | UTC timestamp for when the report ran. |
| `host` | shell | Local hostname. |
| `os_version` | built-in osquery | macOS name, version, build, and platform. This does not require the MacAdmins extension. |
| `system` | `alt_system_info` | Hardware model, serial, UUID, CPU, memory, and hostname data. |
| `mdm` | `mdm` | Enrollment status, user approval, DEP state, SCEP payload presence, server URL, install date, and payload identifier. |
| `filevault_users` | `filevault_users` | Users able to unlock the current boot volume. This may require root because it uses FileVault data from macOS. |
| `macos_rsr` | `macos_rsr` | Rapid Security Response version and related macOS version fields. |
| `pending_apple_updates` | `pending_apple_updates` | Pending Apple software updates, if any are reported by macOS. |
| `sofa_security_release_info` | `sofa_security_release_info` | SOFA security release metadata for the running macOS version. |
| `sofa_unpatched_cves` | `sofa_unpatched_cves` | CVEs SOFA considers unpatched for the running macOS version, including actively exploited status. |
| `local_network_permissions_denied` | `local_network_permissions` | Apps with denied local network permission entries. |
| `query_errors` | script | Per-section osquery errors captured while building the report. Empty means all sections queried successfully. |

By default it prints JSON to stdout. To also save it locally:

```sh
REPORT_PATH="/Library/Application Support/SimpleMDM/macadmins-osquery-security.json" ./scripts/reports/macos-security-report.sh
```

## Deploying the extension

This repository does not include the MacAdmins osquery extension binary. Build or download the extension separately, then deploy the correct architecture to:

```sh
/usr/local/bin/macadmins_extension.ext
```

If the extension is owned by root, `osqueryi` can load it normally. These scripts also pass `--allow_unsafe` so they remain useful while testing locally or during early deployment.

## Notes

The scripts return short, inventory-friendly values for SimpleMDM. They avoid external dependencies such as `jq` or Python so they can run in a default macOS shell environment.

## Related projects

- [macadmins/osquery-extension](https://github.com/macadmins/osquery-extension): osquery extension that provides the MacAdmins tables queried by these scripts.
- [macvfx/SimpleSecurityCheck](https://github.com/macvfx/SimpleSecurityCheck): SimpleMDM security checks using SOFA feeds, including an app-based workflow.
- [macvfx/SimpleChecks](https://github.com/macvfx/SimpleChecks): SimpleMDM script examples for lightweight checks.

This repository stays separate from the other SimpleMDM security projects because it depends on osquery and the MacAdmins extension. Keeping it separate makes setup, troubleshooting, and reuse clearer.
