# vpsAdmin storage integrity rollout

This is the site rollout record for the storage integrity feature branch. It
separates the disposable freeze trial from a later shared-host release and
physical catalog repair. **No shared host has been switched by preparing this
document or its channel pin.** Replace the revision placeholders only with
reviewed, fetchable feature commits and record the executed commands and
results in the initiative rollout record.

## Revisions and channels

`vpsadmin` maps to `vpsadminServices`. Eleven shared internal hosts consume
that channel, including `int.api1`, `int.api2`, `int.webui1`, `int.webui2`
and `int.vpsadmin1`. The last host runs a minimal-mode NodeCtld built from
the service channel. Staging and production storage nodes instead use
`vpsadminStaging` and `vpsadminProduction`. Pinning a channel switches no
host, but switching `int.vpsadmin1` can upgrade its NodeCtld.

In this site configuration, the service channel's `vpsadminos` input follows
the separately pinned `vpsadminosStaging` input. That OS pin selects osctld
for `stg/node1` and `stg/node2`; the internal hosts use `vpsadminosOsStaging`
for their base OS. Updating `vpsadminServices` alone does not upgrade osctld.
An older osctld leaves the 5291 activity result unknown. A later reviewed
provider-first staging rollout must port the provider onto the current staging
OS lineage, review and test it, then update the OS pin. Pinning an older
provider commit directly would discard intervening staging changes. Build and
dry-activate both staging nodes and the affected internal hosts with their
respective OS pins. Production keeps its separate OS pin.

After the complete vpsAdmin branch has passed its final independent review
and its exact commit is available from GitHub, prepare the configuration
feature branch with:

```shell
VPSADMIN_REVISION=REVIEWED_FETCHABLE_FEATURE_SHA
confctl inputs channel set --commit vpsadmin vpsadmin "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
git show --stat --oneline HEAD
```

Keep the generated confctl message. Review every changed `flake.lock` input
and its transitive dependencies. Inventory all hosts consuming the channel
and build their configurations from this feature branch; do not deploy them
as a side effect of pinning. Build the API, WebUI and internal NodeCtld host
explicitly:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build cz.vpsfree/vpsadmin/int.vpsadmin1
```

The staging and production node pins need a separate reviewed update before
their NodeCtld processes are rolled. Record those revisions and the service
channel revision for `int.vpsadmin1` separately in the release record.

## Disposable freeze trial

Use the session-owned vpsAdmin worktree and the development cluster named
`2026-09-23-storage-redesign`. Before starting, inspect its session-owned
state and record whether VM disks and a database already exist. Reset only a
verified disposable cluster if the trial must test a fresh schema load. Use
bridge networking and the storage topology:

```shell
vpsadmin-devcluster start 2026-09-23-storage-redesign \
  --topology storage --network bridge
vpsadmin-devcluster status 2026-09-23-storage-redesign
vpsadmin-devcluster urls 2026-09-23-storage-redesign
```

Confirm that schema load, the explicit storage-freeze singleton bootstrap and
migrations completed before opening the API or WebUI. From a direct, active
administrator session, record `storage_freeze.show` mode and epoch, then
exercise `read_only` and `read_write` with a reason and the current epoch.
Check one transition audit row per change, a stale-epoch refusal, a denied
storage admission and a representative denied off-graph write. Observe
already admitted work and bounded blocker counts; use explicit
`settle_observer` only when a prepared old-node intent needs that DB-only
catch-up. Return to `read_write` with a fresh epoch and leave the cluster
running for the user's trial.

`db_drained` reports DB control flow only. This trial does not establish
node-child or osctld garbage-collector quiet, verified physical identities
or permission to apply reconciliation actions.

## Later shared-host rollout

This section is a procedure to prepare and review, **not an instruction to
execute during the disposable trial**. Before an approved shared-host
maintenance window, verify the reviewed configuration and vpsAdmin revisions,
take a restorable database backup, retain prior system generations, inventory
queued/running chains and node workers, and identify every API, scheduler,
supervisor and NodeCtld writer. Do not rely on `read_only` while any old API
worker can admit transactions.

The schema is additive. On the two API hosts,
`vpsadmin.databaseSetup.autoSetup = false`; migration is an explicit service
operation. The safe order is:

1. Stop new admissions at the ingress. On both API hosts, mask and stop API
   and supervisor; mask and stop the scheduler on `int.api1`, where it is
   enabled. On `int.api1`, inventory the `vpsadmin-api-*.timer` units and
   their task services in both the running and target generations. Mask and
   stop every enabled task timer with `systemctl mask --runtime --now`, and
   stop any active task service, leaving
   `vpsadmin-api-migrate-db.service` available for the explicit migration.
   This includes the migration-plan, clone-purge, VPS-expiration, other-object
   expiration and dataset-expansion timers. Confirm every held timer has
   `UnitFileState=masked-runtime` and `ActiveState=inactive`, and every held
   task service is inactive. Keep the masks across both
   `confctl deploy ... switch` operations and the migration, so systemd
   cannot restart an old or new writer early. Let already dispatched node
   work reach a reviewed terminal state.
2. Switch `int.api1` to the reviewed package. Verify, without first repeating
   a mask command, that every held unit and task timer is still masked or
   inactive on both API hosts. If a target-generation unit is not held, stop
   the rollout and inspect whether it ran. Run
   `vpsadmin-api-migrate-db.service`, require `Result=success`, verify
   the foundation migration is `up` and singleton control row 1 exists, and
   retain the database backup. A fresh schema load must have run the explicit
   singleton bootstrap; an established database missing row 1 is a failure,
   not a reason to auto-create a new read-write epoch.
3. Upgrade NodeCtld only after the schema it writes is present. The staging
   and production storage nodes use their separately reviewed channel pins.
   `int.vpsadmin1` instead uses the service pin: either leave that host on its
   old system generation with its assigned work proved compatible, or include
   it as an explicit NodeCtld rollout step after the migration. An unproved
   old writer blocks the later API restart. Before switching that host,
   inspect its queued and running commands, run its dry activation, and
   confirm that the new minimal-mode NodeCtld package and schema are
   compatible. After any node switch, verify its running package, service
   health and terminal or drained old commands. Record which nodes were
   switched; do not infer a NodeCtld rollout from switching either API host.
4. Switch `int.api2` while the masks remain in place. Verify the holds again
   without reapplying them. Unmask and start upgraded API and supervisor on
   both hosts, plus scheduler on `int.api1`, only after both packages and
   required node writers are compatible. Restore the recorded task timers on
   `int.api1` only after that point. Switch the WebUI hosts last, then
   verify the
   authenticated status and epoch-CAS controls from a direct administrator
   session.

Before an actual switch, turn these steps into an exact command checklist
for the approved revisions and run `confctl deploy HOST dry-activate` on
each selected host. Record system generations, service results, migration
status, mode/epoch, blocker counts and the rollback decision point. A channel
pin, build or dry activation alone is not deployment.

Apply these host-specific unit holds before the first switch:

```shell
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl mask --runtime --now vpsadmin-api.service \
    vpsadmin-supervisor.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl mask --runtime --now vpsadmin-scheduler.service
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl show --property Id --property UnitFileState \
    --property ActiveState vpsadmin-api.service \
    vpsadmin-supervisor.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Id --property UnitFileState \
    --property ActiveState vpsadmin-scheduler.service
```

Inventory old and target `vpsadmin-api-*.timer` units before the switch.
On `int.api1`, the default set includes
`vpsadmin-api-migration-plans.timer`, `vpsadmin-api-purge-clones.timer`,
`vpsadmin-api-vpses-expire.timer`, `vpsadmin-api-others-expire.timer` and
`vpsadmin-api-dataset-expansion-run.timer`. Run
`systemctl mask --runtime --now` on the complete evaluated timer set, stop any
active matching task services, and verify that each timer is masked and
inactive and each held task service is inactive. Keep the migration service
unmasked. Record the full timer list and its service states in the release
checklist. A new or unknown target-generation timer blocks the switch until
its effect and hold are reviewed. Post-switch checks inspect the recorded
list without first masking again, so a lost hold or transient restart remains
visible.

Require `UnitFileState=masked-runtime` and `ActiveState=inactive` for every
listed unit on its host. If a check fails, hold the rollout before another
switch. After migration and compatibility checks, release the masks and start
the same units on their respective hosts:

```shell
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl unmask --runtime vpsadmin-api.service \
    vpsadmin-supervisor.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl unmask --runtime vpsadmin-scheduler.service
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl start vpsadmin-api.service vpsadmin-supervisor.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-scheduler.service
```

Check `ActiveState=active` for every listed long-running unit on its host.
Unmask and start the recorded task timers on `int.api1` only after the
compatibility gate. Check their active timer state and inspect task services
for work that was already running before the hold.

## Strict repair gate and rollback

The observer release leaves production strict dispatch and reconciliation
APPLY disabled. A later repair window additionally requires all old writers
excluded, full strict execute/rollback coverage for the operations that can
run, node-child and attributable delayed-osctld quiet, a stable freeze epoch,
complete signed capture and an exact approved plan. Unknown effects or a
changed epoch block apply. Reconciliation changes database rows only; it does
not import disk-only objects or mutate ZFS.

For an observer-only software rollback, leave the additive schema and audit
history in place. Return to `read_write` through the upgraded API only after
deciding that old writers may safely resume; the retired CLI is not a
fallback. An old API cannot enforce the new freeze. Once owner-linked physical
identities or origin links have been published, keep storage `read_only`
until a compatible strict writer returns. Do not down-migrate populated
evidence tables or treat an old NodeCtld process as a proved no-effect writer.
