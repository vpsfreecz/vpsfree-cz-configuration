# Monitoring policy

## Machine classification

Cluster metadata exposes `machineType`: `vps` for managed containers, `physical`
for other machines by default, and `vm` for aitherdev, em1 and build. Set an
explicit value in the machine's `module.nix` when the default does not apply.

Host exporter targets publish this as `machine_type` on the `infra`, `nodes`
and `mon` jobs. This includes the local Prometheus/node-exporter pair, the peer
monitor, and node ZFS/IPMI exporters. This value overrides a conflicting
`monitoring.labels.machine_type`; other custom labels retain their precedence.
Node targets also retain `type="node"` and their existing identity and role labels.

All configured video bridges run as VPSes. The `meet-jvbs` job labels each
bridge's paired node-exporter (9100) and Jitsi exporter (9700) targets with
`machine_type="vps"`, preserving alias, type and project labels. Reconsider this
classification when the bridge inventory changes.

## Alert recipients

Set `monitoring.alertRecipients` in a system's cluster metadata to send its
alerts only to selected users:

```nix
cluster."cz.vpsfree/machines/aitherdev".monitoring.alertRecipients = [ "aither" ];
```

The default `null` uses normal team routing. A nonempty list replaces team
recipients; `[ "aither" "snajpa" ]` selects both users. Empty lists and unknown
users fail configuration evaluation. Ordering and duplicate entries do not
change the selection. This setting does not disable monitoring or alert rules.

`data/monitoring.nix` defines the registered users, their email addresses,
optional SMS daytime windows, and the normal team recipients. To add SMS for
a user, also configure the matching `sms-<user>` receiver in the private sachet
configuration on both APU gateways and the Alertmanager fallback service.
Email-only contacts need no SMS setup. The contact registry contains no secrets.

Selected recipients receive warning, critical and fatal alerts by email, with
the normal repeat frequencies and resolved notifications. Critical and fatal
alerts also use each selected user's configured SMS receiver. Critical SMS
respects that user's daytime window in Europe/Prague; fatal SMS is active at
all times. Shared Telegram is excluded. `severity=none` remains silent, while
an unknown or missing severity falls back to selected-user email.

Alertmanager generates exclusive routes from the existing identity labels.
These routes match the system's primary FQDN and, for nodes, its management
FQDN. A nonempty `node_fqdn` identifies the subject and takes precedence over
the scrape host's `fqdn`. This covers node checks supplied by another system,
such as download-pool healthchecks. A selected system cannot override its
custom `monitoring.labels.fqdn` with a different identity.

Public service and global alerts without machine identity keep team routing.
Selecting one machine does not select its dependent systems or public services.
Recipient metadata does not add Prometheus labels or change alert identities.

Recipient changes require updating both Alertmanager replicas. Exporters,
monitors and the selected machine need no runtime update. During a rolling
update, an old replica can still send team notifications; the exclusive policy
is effective only after both replicas load it. Check reload health and loaded
routes on both replicas. New route groups can send fresh notifications.
Restoring both previous configurations restores previous routing and can read
the existing Alertmanager state; no migration or state deletion is needed.

## Filesystem alerts

`FilesystemCritFreeSpace` applies only to exact `machine_type="vm"` or
`machine_type="physical"` values on any job. It keeps the existing calculation:
available space at or below 10%, held for five minutes, on `/`, `/run` or
`/nix/store`. The original percentage value, critical severity, `fsavail` class
and hourly frequency remain. The numerator selects `machine_type=~"vm|physical"`;
size metrics must match the available-space metric's labels, including device,
filesystem type and machine type.

VPS, missing, empty, unknown and lookalike machine types such as `vmx` do not
produce this critical alert. This includes the VPS monitors and video bridges.
Job names do not affect eligibility. Absent critical alerts generate no new
critical email, Telegram or SMS notifications; active alerts may resolve when
monitor configuration changes and send their normal resolved notifications.

`FilesystemLowFreeSpace` still warns below 20% after five minutes, with hourly
frequency, for every type, including VPS and missing types. A VPS critical
filesystem alert cannot inhibit its warning because that critical is absent;
other inhibition still applies. The separate node fatal-rootfs alert remains
at or below 5% after five minutes. Independently supplied critical alerts keep
normal routing, subject to the machine's recipient policy.

The `/run` selection remains. `/run` is normally tmpfs; expanding a VPS disk
does not expand it.

## CPU usage alerts

Staging (`stg`) and playground (`pgnd`) hypervisors share the relaxed CPU
usage policy: warning above 80% and vpsAdminOS critical above 90%, both held
for 50 minutes. Other locations, including a missing location label, keep the
10 minute holds. Both policies require a boot age strictly above one hour.

The relaxed alerts retain their actual location. Their names keep the
`Staging` suffix for compatibility. CPU usage still averages the idle rate
across CPU cores. Raw load-average, I/O-wait, storage CPU, filesystem and ZFS
rules keep their existing policies.

## Configuration changes

Update both monitors with the labels and critical rule together. No exporter,
node, VM or video bridge update is required. These label and rule changes do
not require an Alertmanager update.
Changing target labels creates new series and alert identities and can reset
pending alerts and rate windows. During mixed monitor versions, an older monitor
may still emit VPS critical alerts. Complete both monitor updates before
checking the policy; HA deduplication does not cover different label sets.

Restoring the previous deployed monitor configuration restores its filesystem
eligibility, host/bridge label shape and playground CPU policy. Reverting only
the critical selector restores filesystem eligibility while preserving labels
and CPU changes. Restoring Alertmanager alone cannot recreate an alert that
Prometheus does not emit. Existing Prometheus and Alertmanager state remains
readable; no data migration or deletion is needed. Verify effective labels,
rules and configuration reload health on both monitor replicas.

## Focused checks

From the repository's pinned development shell:

```sh
nix build --no-write-lock-file --no-link \
  .#checks.x86_64-linux.alert-recipients \
  .#checks.x86_64-linux.infra-monitoring-config \
  .#checks.x86_64-linux.infra-monitoring-rules
```

The config check evaluates real machine metadata, generated host and video
bridge labels, global filesystem eligibility, thresholds, values and timing.
It also checks offline Alertmanager routing with inert receivers. The CPU
check covers thresholds, hold times, locations and boot suppression. The
recipient check covers metadata validation, email destinations, SMS policies,
exclusive routing and subject identity precedence. Offline
routing verifies receiver selection; it does not send notifications or exercise
delivery, daytime activation, repeat timers or inhibition.
