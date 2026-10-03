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
at or below 5% after five minutes. Alertmanager keeps its normal routes and
receivers, including normal routing for independently supplied critical alerts.

The `/run` selection remains. `/run` is normally tmpfs; expanding a VPS disk
does not expand it.

## Configuration changes

Update both monitors with the labels and critical rule together. No exporter,
node, VM or video bridge update is required. Alertmanager routing is unchanged.
Changing target labels creates new series and alert identities and can reset
pending alerts and rate windows. During mixed monitor versions, an older monitor
may still emit VPS critical alerts. Complete both monitor updates before
checking the policy; HA deduplication does not cover different label sets.

Restoring the previous deployed monitor configuration restores its filesystem
eligibility and host/bridge label shape. Reverting only the critical selector
restores filesystem eligibility while preserving labels. Restoring Alertmanager
alone cannot recreate an alert that Prometheus does not emit. Existing Prometheus and Alertmanager state remains
readable; no data migration or deletion is needed. Verify effective labels,
rules and configuration reload health on both monitor replicas.

## Focused checks

From the repository's pinned development shell:

```sh
nix build --no-write-lock-file --no-link .#checks.x86_64-linux.infra-monitoring-config
```

The config check evaluates real machine metadata, generated host and video
bridge labels, global filesystem eligibility, thresholds, values and timing.
It also checks offline Alertmanager routing with inert receivers. Offline
routing verifies receiver selection; it does not send notifications or exercise
delivery, daytime activation, repeat timers or inhibition.
