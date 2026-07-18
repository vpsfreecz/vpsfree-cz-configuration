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

The history backfills are idempotent. They lock one Node at a time using the
same lock as status ingestion, so status messages can wait while that Node is
being reconstructed. Run only one backfill task at a time and watch the
supervisor logs and RabbitMQ status queues for a growing backlog.

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

## Backfill stored history

On `api1.int.vpsfree.cz`, enter `vpsadmin-api-shell` and run the tasks
sequentially:

```shell
bundle exec rake vpsadmin:node:reconstruct_kernel_history
bundle exec rake vpsadmin:node:reconstruct_system_states
```

Both commands must finish successfully before Node rollout begins. Check a
sample of active hypervisor and storage Nodes in the API and WebUI. Kernel and
system history must be ordered correctly, service-only Nodes must have no
kernel evidence, and reconstruction coverage or gaps must agree with the
available `node_statuses` samples.

## Roll out staging Nodes

Switch `node1.stg` without rebooting it:

```shell
confctl deploy cz.vpsfree/nodes/stg/node1 switch
```

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

Then switch and verify `node2.stg` in the same way:

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

Build the selected production Nodes, then switch them gradually in small
batches. Verify the same evidence checks after each batch and pause if
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
