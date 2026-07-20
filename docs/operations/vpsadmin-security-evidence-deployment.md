# Deploying vpsAdmin boot evidence history

This runbook describes the follow-up rollout that distinguishes evidence
origin from boot-time precision, exposes immutable per-boot kernel parameters,
and reconciles the first evidence report with reconstructed boot history.

The preceding security-evidence release is assumed to be deployed to the
entire cluster. Its seven core migrations must already be up and every
eligible Node/storage record must already have complete kernel and system
history backfill checkpoints. Do not repeat those backfills for this release.

## Compatibility

This is a vpsAdmin application and data-correction release. It does not change
the database schema, vpsAdminOS, the evidence schema version, or required Node
status fields. Nodes do not need to be deployed or rebooted. The administrator
resources rename software component value `vpsfree_cz_configuration` to the
generic `system_configuration`.

New supervisors accept both software component values and normalize them to
`system_configuration`. Existing Nodes can therefore keep reporting the old
value indefinitely. New nodectld code emits only the generic value, so deploy
the accepting API/supervisors before any later Node update containing this
vpsAdmin revision. The database stores both component names as enum value `3`;
existing evidence and software-change rows need no data rewrite.

The WebUI accepts both API values during the rolling application deployment.
Its generic implementation has no vpsFree.cz repository name. This
configuration supplies the `system_configuration` commit prefix separately,
so revisions continue to link to `vpsfree-cz-configuration` on GitHub.

Migration `20260720120000 ReconcileReportedBootEvidence` changes data only.
Old and new application processes can continue running while it is applied;
there is no schema compatibility window.

The migration also corrects existing production data:

- directly reported boot events use their reported kernel `btime` as the
  effective history time;
- directly reported boot times are exact unless the reporter recorded the
  `booted_at/estimated_from_uptime` fallback;
- a first evidence-bearing report is matched to a reconstructed boot on the
  same Node and release when boot times are within five minutes;
- one matching derived reconstructed event is deleted while its raw
  `node_statuses` source sample and all reported evidence remain stored; and
- unrelated runtime events and unmatched reconstructed history are unchanged.

The migration locks only the exact incorrect reported-event rows captured at
its start. New supervisors use the same row locking while repairing a report,
so migration and runtime reconciliation cannot consume two reconstructed
candidates for one event. An old-supervisor event inserted after the captured
set remains uncorrected until the new supervisor repairs it atomically.

The running supervisor performs the same reconciliation for a bootstrap or
real reboot event written by an old supervisor after the migration but before
that supervisor is upgraded. Precision is derived from the immutable evidence
snapshot linked to that event, never from a later current report. Only a
bootstrap report can delete one matching reconstructed boot; a later real
reboot remains a distinct event. A newly reported boot always uses the actual
reported boot time in history instead of the first evidence observation time.
A forced history backfill does not recreate the deleted derived bootstrap.

`NodeKernelEvent.confidence` already supports `exact`, `inferred`, and
`incomplete`. The event `source` remains the separate origin dimension:

- `node_report` means that the event and its evidence were reported by a Node;
- `reconstructed_node_status` means that the event came from legacy samples;
- an exact reported boot time came from the kernel's `/proc/stat` `btime`;
- an inferred reported boot time was estimated from uptime; and
- reconstructed legacy boots remain inferred and have no parameter snapshot.

## Prepare the reviewed revision

The review branch pins the application channels to this exact vpsAdmin
revision:

```shell
VPSADMIN_REVISION=1bca29dfac3dba6a82a857ffad24d42e46ae861e
```

The vpsAdminOS revision remains unchanged at
`702155fb91effd7102a92b568f684c7b0d948b1f`. No vpsAdminOS build or deployment
is part of this rollout.

Before building, obtain the exact configuration commit approved for rollout
through the normal change-review channel. Set
`APPROVED_CONFIGURATION_REVISION` to that out-of-band value; do not derive it
from the worktree being checked. Then verify the tracked worktree and review
pins:

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMIN_REVISION=1bca29dfac3dba6a82a857ffad24d42e46ae861e

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.vpsadminStaging.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminProduction.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminosStaging.locked.rev' flake.lock)" = \
  702155fb91effd7102a92b568f684c7b0d948b1f
confctl inputs channel ls
```

The application hosts use `vpsadminServices`, while staging and production
Nodes use `vpsadminStaging` and `vpsadminProduction`. All three are pinned to
the same reviewed revision. Updating these pins does not deploy any host;
application and Node deployments remain separate operator actions.

Build the affected application hosts before the maintenance window:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
```

Confirm that the database backup and the normal API rollback generations are
available.

## Deploy the WebUI first

The new WebUI accepts both the legacy `vpsfree_cz_configuration` value from an
old API and the generic `system_configuration` value from a new API. Deploy it
before either API host so the System configuration row and link remain visible
throughout the rolling backend update:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy cz.vpsfree/vpsadmin/int.webui2 switch
```

Verify both frontends against the still-old APIs, including the existing
System configuration software-version row and its GitHub link.

## Deploy api1 and apply the migration

Keep api2 on the old generation so it continues to serve the API and consume
Node statuses. Deploy api1 normally:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api1 switch
```

Enter the new generation's `vpsadmin-api-shell` on api1 and apply the core
migration:

```shell
bundle exec rake db:migrate
bundle exec rake db:migrate:status
```

`20260720120000 Reconcile reported boot evidence` must report `up`. A plugin
migration is not required. Confirm from the same shell that this release did
not add the discarded supersession column:

```ruby
connection = ActiveRecord::Base.connection
puts connection.column_exists?(:node_kernel_events, :superseded_by_event_id)
```

The result must be `false`. Verify API and supervisor health, ordinary Node
status consumption, and the absence of migration or evidence errors in their
logs.

## Deploy api2

Deploy the second API/supervisor host:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api2 switch
```

Verify API and supervisor health on api2 and wait for several ordinary status
intervals. A bootstrap or real reboot event written by api2's old supervisor
between the migration and this deployment must be repaired from its immutable
evidence snapshot by the new supervisor. After this point, future Node
deployments may safely emit `system_configuration`.

No deployment of `int.vpsadmin1` is required: its mailer-role nodectld does
not report host-kernel evidence.

## Verify stored and displayed evidence

In `vpsadmin-api-shell` on api1, inspect the corrected distribution without
changing data:

```ruby
reported = NodeKernelEvent.boot.node_report
puts reported.group(:confidence).count

estimated = reported
  .joins(kernel_evidence: :kernel_evidence_errors)
  .where(
    node_kernel_evidence_errors: {
      component: 'booted_at',
      reason: 'estimated_from_uptime'
    }
  )
puts estimated.group(:confidence).count

reconstructed = NodeKernelEvent.boot.reconstructed_node_status
puts reconstructed.group(:confidence).count
```

The normal case is:

- directly reported boots with kernel `btime` evidence are exact;
- directly reported boots with the uptime-estimation error are inferred;
- their effective history time equals the linked evidence `booted_at`;
- a matched first-report reconstructed row is absent while its raw status
  source remains available; and
- unmatched reconstructed legacy boots remain inferred and visible.

Investigate exceptions against linked evidence before changing any row. Do
not rerun the history backfill to alter precision or reconcile duplicates.

Through each WebUI frontend, inspect `node1.stg`, `node2.stg`, and at least one
additional Node:

- Kernel history has separate Origin and Time precision columns;
- a matched reconstructed/reported pair appears once at the actual boot time;
- the already reported reboot on `node2.stg` is exact when its event snapshot
  has no uptime-estimation error;
- reported boot rows link administrators to Boot evidence;
- Boot evidence shows observation/report metadata, the raw command line, and
  parameters in their original order;
- reconstructed rows say that detailed evidence is unavailable;
- Software versions labels the generic component as System configuration and
  links its revision to the configured `vpsfree-cz-configuration` commit;
- normal members can read sanitized history but cannot open evidence detail;
  and
- a Boot evidence URL cannot display an event belonging to another Node.

Wait for several status intervals and verify that no duplicate current kernel
row appears. No Node reboot is required solely for this check; use an ordinary
reboot only when one is already operationally planned.

## Rollback

If application errors occur after the migration, normally leave the migration
applied and switch both API hosts back to their previous system generations
before switching the WebUI hosts back. The new WebUI accepts either API
spelling, while an old WebUI would temporarily omit the generic System
configuration row returned by a new API. The old application can read the
corrected confidence values and authoritative reported events.

This application rollback is safe while Nodes still run the old reporter, as
required by this rollout. After a future Node deployment starts emitting
`system_configuration`, do not roll supervisors back to a version that accepts
only `vpsfree_cz_configuration` unless those Nodes are rolled back first.

There is no schema to remove. The migration's `down` is intentionally a no-op:
it does not recreate a misleading derived duplicate or revert corrected event
precision and time. If operational bookkeeping specifically requires marking
the migration down, first roll api2 back but keep api1 on the new generation.
Run the following command from that still-new api1 application shell; the old
package does not contain this migration:

```shell
bundle exec rake db:migrate:down VERSION=20260720120000
bundle exec rake db:migrate:status
```

Then roll api1 back. After both APIs are old, roll back both WebUI hosts. The
corrected reported event, raw command line, ordered parameters, and source
status sample remain available. A later redeployment requires no Node backfill
or reboot.
