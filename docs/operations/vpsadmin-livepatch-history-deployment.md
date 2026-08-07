# Deploying effective livepatch history

This runbook deploys the release that separates livepatch inventory from the
public kernel lifecycle. Kernel history records only when a patch is first
observed as effective, or when an effective patch disappears. Merely making a
patch module available does not put it in node evidence. Loaded modules that
are disabled or transitioning remain internal evidence and do not create a
public kernel event.

The release also shortens inferred version timestamps in the WebUI. The lower
observation bound is visible in kernel, software, sysctl, and system history;
the complete interval remains available as hover and keyboard-focus text.

This is a release-specific runbook. The revision checks apply only to this
change and must not be copied to a later channel update.

## Reviewed revisions

The configuration channels pin these exact feature revisions:

```shell
VPSADMINOS_REVISION=8d5fe0058f5f4db3840c7d8043c7aba3b88ccca4
VPSADMIN_REVISION=c0d87bebf36c6d29b7861990890e8c650fa1afca
```

The vpsAdminOS revision contains the livepatch payload and its existing
release-specific certification test. It does not contain a separate service
or protocol for publishing a completion timestamp; vpsAdmin derives the
lifecycle from ordinary node evidence.

Before building, obtain the exact configuration commit approved for rollout
through the normal change-review channel. Do not derive the approved value
from the worktree being checked.

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMINOS_REVISION=8d5fe0058f5f4db3840c7d8043c7aba3b88ccca4
VPSADMIN_REVISION=c0d87bebf36c6d29b7861990890e8c650fa1afca

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
for input in vpsadminosOsStaging vpsadminosStaging vpsadminosProduction; do
  test "$(jq -r ".nodes.$input.locked.rev" flake.lock)" = \
    "$VPSADMINOS_REVISION"
done
for input in vpsadminStaging vpsadminServices vpsadminProduction; do
  test "$(jq -r ".nodes.$input.locked.rev" flake.lock)" = \
    "$VPSADMIN_REVISION"
done
```

The pins only prepare builds. Committing or merging them does not deploy any
machine.

## Compatibility and ordering

The schema change adds a nullable `livepatch_action` column and appends the
internal `livepatch_inventory_change` event type. Existing enum values and the
public API event value `livepatch` do not change. Old WebUIs render new public
events with the generic Live patch change label; the new WebUI also renders
old rows without an action using that fallback.

The public actions are `applied` and `removed`. Application is inferred from
the first pair of consecutive node reports where a patch newly satisfies all
three conditions: loaded, enabled, and not transitioning. The event therefore
keeps the report interval, has inferred confidence, and has no exact
`effective_at` value. A patch already stable in the first report after boot is
part of boot state and does not create an extra application event.

The data migration is deliberately one-way. It reclassifies an all-false
availability row when its immediately preceding public event either has no
effective patch or contains a different effective patch with the same reported
release. The second case corrects the observed staging sequence where patch 2
remained active but the old reporter showed only unavailable patch 3. An
all-false row for the same effective patch stays generic because it may be a
real removal. A historical stable event is labelled applied only when the old
exact event timestamp can be matched to its application marker; the exact time
is then cleared and the event becomes inferred. Other ambiguous rows remain
generic. Evidence and event rows are not deleted.

The new reporter enumerates `/sys/kernel/livepatch` and enriches only those
loaded modules from the booted and current system closures. A deployed but
unloaded patch is absent. During rollout, an old reporter can hide active patch
2 behind unavailable patch 3. The new API recognizes that different-ID,
same-release shape as inventory rather than a removal. Deploy the API before
the node reporters; no coordinated all-node update or reboot is required.

Do not let an old supervisor write kernel events after the data migration. It
can recreate the availability-only public row that the migration corrected.
The supervisor services on both API hosts must be runtime-masked for the
application switch and migration below. Ordinary HTTP API service continues
to be available during this short reporting pause.

## Prepare and inspect

Build the application hosts and both staging nodes before the maintenance
window:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build cz.vpsfree/nodes/stg/node1
confctl build cz.vpsfree/nodes/stg/node2
```

From a current API console, record the pre-migration livepatch counts. This is
read-only and gives the operator a comparison point; do not edit individual
history rows.

```ruby
puts({
  public_livepatch: NodeKernelEvent.livepatch_change.count,
  public_without_effective_time: NodeKernelEvent.livepatch_change
    .where(effective_at: nil).count,
  current_public_per_node: NodeKernelEvent
    .where(event_type: %i[boot reported_release_change livepatch_change])
    .where(current: true).group(:node_id).count
}.inspect)
```

## Deploy WebUI and migrate the API

The new WebUI is backward compatible with the old API, so deploy both WebUI
hosts first and verify that existing history still renders:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy cz.vpsfree/vpsadmin/int.webui2 switch
```

Pause all node-report event writers and keep them masked across both API
switches:

```shell
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl mask --runtime --now vpsadmin-supervisor.service
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl show --property UnitFileState --property ActiveState \
    vpsadmin-supervisor.service
```

Both hosts must report a runtime-masked, inactive supervisor. Switch api1,
confirm the mask still holds, and run the packaged migration service:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api1 switch
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property UnitFileState --property ActiveState \
    vpsadmin-supervisor.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-api-migrate-db.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Result vpsadmin-api-migrate-db.service
```

Migration `20260806120000 Add node kernel livepatch actions` and migration
`20260806120100 Reclassify node livepatch events` must both report `up`. The
migration service result must be `success`. Then switch api2 and restart the
new supervisors:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api2 switch
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl unmask --runtime vpsadmin-supervisor.service
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl start vpsadmin-supervisor.service
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl is-active vpsadmin-supervisor.service
```

All hosts must report `active`.

Roll the new reporter to staging nodes only after both API hosts run the new
recorder:

```shell
confctl deploy cz.vpsfree/nodes/stg/node1 switch
confctl deploy cz.vpsfree/nodes/stg/node2 switch
```

Verify staging before rolling the same vpsAdmin revision through production
nodes using the ordinary bounded node-update procedure.

## Verify application history

After several node status intervals, run these checks from a new API console:

```ruby
inventory_current = NodeKernelEvent.livepatch_inventory_change
                                   .where(current: true).pluck(:id)
duplicate_current = NodeKernelEvent
  .where(event_type: %i[boot reported_release_change livepatch_change])
  .where(current: true).group(:node_id).count.select { |_node, n| n > 1 }
invalid_applied = NodeKernelEvent.livepatch_change
  .where(livepatch_action: :applied)
  .where.not(effective_at: nil, confidence: :inferred).pluck(:id)

puts "inventory marked current: #{inventory_current.inspect}"
puts "duplicate public current rows: #{duplicate_current.inspect}"
puts "invalid applied rows: #{invalid_applied.inspect}"
abort 'livepatch history verification failed' unless
  inventory_current.empty? && duplicate_current.empty? &&
    invalid_applied.empty?
```

In both WebUI frontends, inspect the staging nodes and at least one production
node that has livepatch evidence. Confirm that:

- availability-only observations are absent from Kernel history;
- node evidence contains loaded patch 2 but not deployed, unloaded patch 3;
- effective additions are labelled applied and disappearances are removed;
- a bounded inferred time shows only `after DATE`, with the complete interval
  available by mouse hover and keyboard focus; and
- exact, bounded, and upper-only times remain distinguishable.

The retained vpsAdminOS channel revision `8d5fe005` contains cumulative patch 3
and must not be downgraded. Patch 3 becomes lifecycle and security evidence only
after it is loaded into the running kernel.

## Rollback

Before the data migration, all components can be switched back normally.

After the migration, prefer rolling forward with a fix. The schema migration
can remove the nullable column, but the classification migration has an
intentional no-op rollback because the original public meaning cannot be
reconstructed safely. Old application code ignores the extra column and its
public history query excludes the appended inventory event value, but its
admin event resource may display that internal enum as unknown.

If an API rollback is unavoidable, runtime-mask both supervisors first and
keep them paused after the old application is active on both API hosts. They
must not be restarted on the old release: doing so recreates availability-only
public events after the one-way correction. Restore node reporting only by
rolling forward to the new recorder, or by approving an explicit semantic
regression and a new corrective migration plan. Do not rerun or manually
reverse the classification migration.
