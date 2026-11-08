# DNS primary readiness deployment and recovery

The DNS readiness configuration requires the matching vpsAdmin API, supervisor,
DNS-node scheduler/worker/unit settings and notification templates. It is a
coordinated protocol transition, not a rolling-compatible node update. Stock
BIND remains in use; no vpsAdminOS change is required. This procedure describes
future operations and does not authorize deployment or database changes.

## Policy and retained history

`dns_primary_transfer_failure` monitors one `DnsZone` incident for direct
user-primary readiness. The shared API predicate distinguishes current evidence
from stale observations. Explicit failures need continuous evidence for 30
minutes; network failures require repeated observations spanning 24 hours.
Default probes run hourly, retry access/network failures every five minutes,
and retry content/protocol/stale failures hourly. Five isolated workers per DNS
node bound concurrency. Keep DNS and API clocks synchronized.

An existing incident stays open while expected paths are pending or stale.
Stale evidence cannot trigger repeat mail. Positive recovery requires every
expected path to have current positive evidence. Removing all incident-failing
paths may instead close it as `configuration_changed`; remaining known failures,
including stale failures, prevent that configuration-based closure. A generation
change or missing probe is not removal. The measured path keys and closure
reason remain in existing monitor observations/action state for audit and mail.

`dns_secondary_missing_primary` uses existing user-primary associations, excluding
peers and pending destruction. It checks enabled external zones of active owners,
confirms after 30 minutes, repeats daily and uses an hour cooldown. An explicitly
owned detached allocation still counts as configured and continues to be probed.
Last-primary removal can close readiness as changed configuration and open this
separate incident. Re-adding a primary restores configuration; readiness starts
pending. The missing-primary closure does not assert a successful transfer.

Both monitors retain the existing framework's acknowledgement and ignore rules.
Acknowledged incidents close on a passing evaluation. Actively ignored incidents
remain ignored without evaluation/closure mail until ordinary lifecycle resumes.
No additional detached-address incident stream is created.

Core migration `20261108120000` preserves transfer audit rows and latest-attempt
pointers, classifies pre-cutover rows as `legacy`, and starts derived readiness
unknown. Monitoring migration `20261108121000` supersedes active legacy
`dns_secondary_transfer_failure` incidents without alerts or history deletion.
Its observation marker is `reason: superseded_by_primary_readiness` and
`replacement_monitor: dns_primary_transfer_failure`. Legacy templates remain
available. Additive schema is retained during software rollback; migration down
is deliberately irreversible. Never run the archived destructive reset tasks.

## Prepare the complete input set

Publish the exact final application and template feature heads before updating
configuration. Use `confctl inputs channel set --commit vpsadmin vpsadmin REV`
for `vpsadminServices` and channel/role `vpsfree-notification-templates` for
`vpsfreeNotificationTemplates`. The latter's vpsAdmin input follows the former.
Do not edit locks manually or change staging/production node channels incidentally.
Check every generated input change and record final revisions in rollout evidence.

Before activation, prepare builds/copies and independently review the complete
series. Verify API, supervisor and every DNS node use the same event/configuration
contract; worker and hardening settings must move with their scheduler. Inventory
enabled zones without user primaries and existing incidents before enabling the
new monitor. Reconcile orphaned persisted rows reported by migration validation;
do not delete them or guess their association to make validation pass.

## Forward transition

1. Pause DNS monitoring and drain already-enqueued alert/mail work. Stop API/DNS
   configuration writers. With old nodectld still running, drain old DNS
   transactions. Make the new release's schema-independent verifier available
   without starting its services and require
   `bundle exec rake vpsadmin:dns:verify_configuration_drained` to report zero.
2. Stop old nodectld producers on every DNS node. Drain `dns_transfer_logs` with
   old supervisors, then stop all consumers and monitoring-event writers.
3. Apply the prepared additive migrations with matching application/configuration
   and templates installed. With writers/consumers still stopped, run
   `CONFIRM=1 bundle exec rake vpsadmin:dns:reset_primary_transfer_tracking`.
   This clears only derived readiness, rotates generations, normalizes null
   rollback-era attempt kinds to legacy and queues full configuration refreshes.
   Verify audit rows/latest pointers survive and inspect the queued refresh count.
4. Start matching new nodectld/stock-BIND producers on every DNS node. Verify all
   queued refreshes complete and persisted zone configuration has server-zone/
   transfer IDs, generation, primary kinds and real transfer source addresses.
5. Start only matching new consumers; inspect/drain new-format events. Resume
   writers and monitoring after the boundary is proven. Check direct same-serial
   recovery, failed user-primary versus peer serving, missing-primary and restored
   pending states. Do not infer upstream recovery from an unchanged serving serial.

## Software rollback and later re-upgrade

Stop new writers while the full new node fleet is still running. Require
`bundle exec rake vpsadmin:dns:verify_primary_transfer_configuration_drained`
to report zero before stopping producers. A partial upgrade must first restore
enough matching new nodectld service to drain its transactions. Never send
new-format configuration to old nodectld. Drain new events with new consumers,
then stop consumers/monitor writers. While new API code remains available, run
`CONFIRM=1 REFRESH_CONFIGURATION=0 bundle exec rake vpsadmin:dns:reset_primary_transfer_tracking`.
Preserve additive schema, transfer audit and incident history; do not invoke a
destructive monitor reset or reverse the migration.

With BIND stopped, atomically advance `/var/lib/nodectld/dns-transfer-log.cursor`
on each DNS node to the current `bind.service` journal tail. Capture only the
opaque cursor from `journalctl -u bind.service -n 0 --show-cursor`, write it as
root with mode 0600 using a temporary file and atomic rename, and verify that
reading after the installed cursor returns no entries. This preserves the
archived rollback boundary for already-drained trailing diagnostics; never skip
unresolved work. Restore the matching old application/configuration/templates,
start old consumers before producers, then let old software issue compatible
refreshes. Old detach writers can again remove owned-IP references; rollback
cannot reconstruct deleted associations.

For re-upgrade, repeat the old-writer/configuration drain and matching
producer/queue/consumer barrier. Run the same safe reset with refreshes enabled
before starting new nodes/consumers. It admits null rollback-era attempt kinds
only as historical legacy data; they never seed current readiness. Old software
may also create new legacy-monitor incidents during rollback. The one-time
plugin migration does not retire those on re-upgrade. With monitoring writers
and alert work drained/stopped, run
`CONFIRM=1 bundle exec rake vpsadmin:monitoring:supersede_legacy_dns_transfer_events`
and inspect its inspected/retired counts before resuming monitoring. This
repeat-safe operation appends the same supersession audit marker as the
migration without callbacks, mail or deletion; it never reruns a migration.
Record exact inputs, queue/configuration evidence and verified effects for
each transition.
