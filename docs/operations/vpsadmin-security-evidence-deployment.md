# Deploying vpsAdmin security evidence

This runbook describes the production rollout of vpsAdmin's Node kernel,
system, and software evidence. Run each step manually and stop when a
verification check fails. None of the commands in this document are run as
part of a configuration build or deployment.

## Compatibility

The release has seven core vpsAdmin database migrations. They add advisory
revision tracking, Node kernel history and normalized evidence, kernel
configuration options, Node system-state history, and reported capacity
defaults. There are no plugin migrations for this feature.

The migrations are additive and the old API remains able to use the migrated
database during the rolling update. New supervisors accept both the old Node
status payload, which has no security evidence, and the new payload. Deploy
both supervisors before updating nodectld on any Node.

The history backfills are resumable and idempotent per Node. Historical scans
run in batches without the Node lock. Only final boundary verification and the
atomic derived-history/checkpoint writes use the same short lock as status
ingestion. If status or exact history changes during a scan, the task retries
the scan up to three times instead of committing a stale result.

A nodectld update is activated without rebooting the Node. It can immediately
report the current closure and the kernel that is already running. The booted
closure's vpsFree.cz configuration revision is unavailable when that older
closure predates `/etc/confctl/configuration-info.json`; this is expected and
is filled in after a later reboot into a closure that contains the metadata.

## Prepare

Record the vpsAdmin, vpsAdminOS, confctl, and configuration revisions selected
for the rollout. Build the affected configurations before the maintenance
window:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build cz.vpsfree/nodes/stg/node1
confctl build cz.vpsfree/nodes/stg/node2
```

Confirm that the database backup and the normal API rollback generation are
available. Keep the production `vpsadmin` and `vpsadminos` channel pins
unchanged until staging has completed its soak period.

## Deploy the API and migrate

Deploy the first API/supervisor host:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api1 switch
```

Immediately open the production API shell on `api1.int.vpsfree.cz`:

```shell
vpsadmin-api-shell
bundle exec rake db:migrate
bundle exec rake db:migrate:status
```

All seven new core migrations must report `up`. A feature-specific
`vpsadmin:plugins:migrate` run is not required. If the standard operational
procedure runs plugin migrations for every vpsAdmin release, the generic and
idempotent command is:

```shell
bundle exec rake vpsadmin:plugins:migrate
```

Before continuing, verify that the API and `vpsadmin-supervisor` are active on
api1, that ordinary Node statuses are being consumed, and that no missing-table
errors appear in their logs.

Deploy the second API/supervisor host:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api2 switch
```

Verify the API and supervisor on api2. At this point both RabbitMQ consumers
understand old and new Node status payloads.

Deploy both WebUI hosts:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy cz.vpsfree/vpsadmin/int.webui2 switch
```

Verify the cluster and Node administration pages through each frontend.

## Inspect stored history

On `api1.int.vpsfree.cz`, enter `vpsadmin-api-shell` and inspect all eligible
hypervisor/storage Nodes:

```shell
bundle exec rake vpsadmin:node:history_backfill_status
```

Do not backfill every active Node far in advance. Immediately before deploying
one Node, run its combined backfill by numeric vpsAdmin Node ID and verify that
its overall state is `complete`:

```shell
NODE_ID=300 bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=300 bundle exec rake vpsadmin:node:history_backfill_status
```

The component tasks remain available for diagnosis or explicit resume:

```shell
NODE_ID=300 bundle exec rake vpsadmin:node:reconstruct_kernel_history
NODE_ID=300 bundle exec rake vpsadmin:node:reconstruct_system_states
```

The default batch size is 10,000 statuses. Set a positive `BATCH_SIZE` only
when operational load requires it. A completed component is skipped; use
`FORCE=1` only for an intentional verified rerun. A combined run with one
successful component and one failure is `partial`, and the next combined run
resumes only the missing component. Inactive historical Nodes may be
backfilled separately during an off-peak window.

## Roll out staging Nodes

Backfill `node1.stg` on api1 immediately before switching it without rebooting.
Replace `NODE1_ID` with its numeric vpsAdmin Node ID:

```shell
NODE_ID=NODE1_ID bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=NODE1_ID bundle exec rake vpsadmin:node:history_backfill_status
```

Leave the API shell. From the configuration workstation, deploy only after the
Node status row is `complete`:

```shell
confctl deploy cz.vpsfree/nodes/stg/node1 switch
```

Kernel and system history must be ordered correctly, and reconstruction
coverage or gaps must agree with the available `node_statuses` samples.

Wait for several status intervals and verify:

- the status report is accepted without supervisor errors;
- the current kernel evidence has no unexpected collection errors;
- configured boolean sysctls are displayed as `1` or `0` and match the
  effective value when the settings agree;
- booted and current vpsAdminOS, vpsAdmin, and nixpkgs revisions are exact Git
  commits;
- the current vpsFree.cz configuration revision is a Git commit link and is
  marked modified only when built from a dirty worktree;
- missing booted configuration provenance for an older closure is not reported
  as an evidence error; and
- kernel, software, sysctl, cgroup, and capacity histories contain the expected
  changes.

Then backfill and verify `node2.stg` on api1 in the same way:

```shell
NODE_ID=NODE2_ID bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=NODE2_ID bundle exec rake vpsadmin:node:history_backfill_status
```

Leave the API shell and switch it from the configuration workstation:

```shell
confctl deploy cz.vpsfree/nodes/stg/node2 switch
```

Leave both staging Nodes running for the chosen soak period. A reboot is not
part of this rollout.

## Roll out production Nodes

After staging approval, pin the reviewed revisions without changing them
during rollout:

```shell
confctl inputs channel set --commit production vpsadminos VPSADMINOS_REVISION
confctl inputs channel set --commit production vpsadmin VPSADMIN_REVISION
```

Build the selected production Nodes. For each Node, inspect status on api1, run
its numeric-ID combined backfill immediately before deployment, and verify
`complete`:

```shell
NODE_ID=PRODUCTION_NODE_ID bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=PRODUCTION_NODE_ID bundle exec rake vpsadmin:node:history_backfill_status
```

Then leave the API shell and switch that Node from the configuration
workstation. Repeat gradually in small batches. Verify the same evidence checks
after each Node or batch and pause if
supervisor errors, queue growth, evidence errors, or unexpected history
changes appear. Do not reboot Nodes merely to deploy this feature.

## Rollback

Stop the rollout and switch affected hosts back to their previous system
generation when application errors occur. The additive database tables may
remain in place while the previous vpsAdmin version runs; do not run down
migrations during an application rollback.

An older supervisor ignores the new status field, while updated Nodes continue
to send it. Evidence reporting resumes when a new supervisor is restored. The
backfills are safe to rerun after recovery.
