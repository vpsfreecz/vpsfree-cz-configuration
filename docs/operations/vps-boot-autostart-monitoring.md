# VPS boot auto-start monitoring

`VpsAutostartNotRunning` identifies an unmet auto-start expectation from node
boot. Nodes freeze the expected VPS set before nodectld admits transactions.
A VPS remains pending until osctld has observed it running during this boot or
vpsAdmin confirms that the original obligation no longer applies. Failed starts
remain pending without an uptime limit. Once fulfilled or retired, an obligation
does not return during this boot, including during restore, swap, intentional
stop, daemon restart or pool export/import.

Observed container state history belongs to osctld; vpsAdmin owns the boot
cohort and authoritative retirement policy. The first-running summary retains
successful-start evidence for the whole boot, even after the bounded recent
timeline evicts its running event. See the
[vpsAdmin boot tracking contract](https://github.com/vpsfreecz/vpsadmin/blob/master/docs/boot-autostart.md)
for those interfaces and state guarantees, and the
[vpsAdminOS compatibility contract](https://github.com/vpsfreecz/vpsadmin/blob/master/docs/vpsadminos-compatibility.md)
for recovery safety and supported upgrade boundaries.

## Metrics and alerts

The rules use only `nodectld_vps_boot_autostart_*` metrics and require
`nodectld_vps_boot_autostart_supported` to be 1. The older
`nodectld_vps_autostart_*` metrics remain diagnostics and do not select these
alerts. Missing or unsupported boot metrics leave a node without boot-autostart
coverage from these rules. No warning is generated solely for that missing
capability. An absent alert or series does not establish that the node's boot
auto-start check is healthy.

Both per-VPS alerts and check-failed warnings have a 30-minute boot grace
period and a continuous 10-minute hold. The per-VPS alert requires active
tracking, a successful check and a last-success timestamp less than 300 seconds
old. Its identity includes the pool and VPS ID, without the diagnostic reason,
so a reason change does not restart the hold. Boot grace and freshness do not
expire unresolved boot failures.

`VpsAutostartCheckFailed` warns when boot tracking is unavailable, or an active
check fails or becomes at least 300 seconds old. The warning keeps the same node
identity across changes in state or reason. Unavailable boot tracking does not
select the older diagnostics as a fallback.
`VpsAutostartAwaitingReboot` has `severity=none` and is silent under the normal
Alertmanager policy. It identifies nodes upgraded during an older boot that
have no boot cohort. Their per-VPS boot coverage starts at the next normal
reboot; this informational state does not require an immediate reboot.

## Deployment and verification

Deploy the additive supervisor RPCs before the node consumer. Upgrade osctld,
nodectld and their boot hooks on the monitored nodes before enabling these
rules on the monitors. Verify each node exports boot support and a classified
boot state. Active nodes need a successful recent check for per-VPS coverage;
awaiting-reboot nodes have an explicit coverage gap until their next normal
reboot. Investigate unavailable states before relying on their results.

Boot tracking begins on each node's next real reboot. Nodes can update
independently; no coordinated fleet reboot is required. After node readiness
has been checked, update both Prometheus monitors and verify rule reload health
on each replica. Keep rollout checks for missing boot metrics explicit, since
these rules do not supply a missing-capability warning.

Inspect `/run/metrics/nodectld.prom` on a node or the corresponding Prometheus
series. A healthy enrolled node exports supported=1, state active/reason none,
check_success=1 and a recent last-success timestamp. An empty cohort is valid.
Expected counts include fulfilled and retired members; unsatisfied series only
identify pending obligations. Failed checks withhold per-VPS result series;
the absence of those series alone does not establish success.

For unavailable tracking, inspect the exported state reason and nodectld/osctld
logs. Confirm supervisor RPC and container-state history support, current boot
identity and runtime-state persistence. Missing or invalid state on a
feature-enabled boot is a monitoring failure. Restarting daemons does not
recreate a cohort. Preserve runtime ledgers and failure sentinels when diagnosing
problems. Rebooting solely to clear an unresolved alert loses evidence without
proving the preceding boot's VPSes ever ran.

Follow the
[vpsAdminOS compatibility contract](https://github.com/vpsfreecz/vpsadmin/blob/master/docs/vpsadminos-compatibility.md)
before changing node software. Downgrading across its recovery-safety boundary
is unsupported; reboot does not make that downgrade safe. Follow its guidance to
fix problems with a recovery-aware daemon and consult the applicable
revision-scoped upgrade instructions. Changing these
alert rules does not require deleting Prometheus or Alertmanager state.

## Focused rule checks

```sh
nix build --no-write-lock-file --no-link \
  .#checks.x86_64-linux.vps-autostart-prometheus-rules
```

The check covers ignored legacy-only and unsupported inputs, pending failures
hours after boot, stable alert identities, unavailable and stale checks,
awaiting reboot, and fulfilled or empty cohorts during long stops. It uses
virtual rule time for boot grace and debounce. It evaluates alert rules offline
and does not boot nodes or send notifications.
