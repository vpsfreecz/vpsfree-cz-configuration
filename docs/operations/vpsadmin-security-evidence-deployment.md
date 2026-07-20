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

All security-advisory draft mutations and publication now require the content
revision displayed during review. An old WebUI or administrative client does
not send that precondition and therefore fails safely against the new API.
Freeze advisory draft changes, synchronization, and publication from the first
API deployment until both APIs and both WebUIs run the reviewed release. If an
API rollback is required, keep the freeze in place: the old API does not
enforce the revision precondition. Re-read and re-review the current draft
revision after all API and WebUI hosts are on one version before lifting the
freeze.

A nodectld update is activated without rebooting the Node. It can immediately
report the current closure and the kernel that is already running. The booted
closure's vpsFree.cz configuration revision is unavailable when that older
closure predates `/etc/confctl/configuration-info.json`; this is expected and
is filled in after a later reboot into a closure that contains the metadata.

## Prepare

The reviewed source revisions for this rollout are:

- confctl `7bee58a52372b95c2198ce3f2a719807a3c2c66b`;
- vpsAdminOS `736f689391bc3f920e808eb574662ed6a9e6c955`; and
- vpsAdmin `c7e4b87854fe27619dd5450f93a1e5c4d4f8e4d1`.

Before building, obtain the exact configuration commit approved for rollout
through the normal change-review channel. Set
`APPROVED_CONFIGURATION_REVISION` to that out-of-band value; do not derive it
from the worktree being checked. Then verify the tracked worktree and resolved
inputs:

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.confctl.locked.rev' flake.lock)" = \
  7bee58a52372b95c2198ce3f2a719807a3c2c66b
test "$(jq -r '.nodes.vpsadminosStaging.locked.rev' flake.lock)" = \
  736f689391bc3f920e808eb574662ed6a9e6c955
test "$(jq -r '.nodes.vpsadminStaging.locked.rev' flake.lock)" = \
  c7e4b87854fe27619dd5450f93a1e5c4d4f8e4d1
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  c7e4b87854fe27619dd5450f93a1e5c4d4f8e4d1
confctl inputs ls
confctl inputs channel ls
```

The `confctl`, `vpsadminosStaging`, `vpsadminStaging`, and `vpsadminServices`
locks must resolve to the reviewed revisions above. Stop if they differ. The
production vpsAdmin and vpsAdminOS inputs intentionally remain unchanged until
the staging soak is approved.

Build the vpsAdmin application hosts affected by this release and both staging
Nodes before the maintenance window:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build cz.vpsfree/vpsadmin/int.vpsadmin1
confctl build cz.vpsfree/nodes/stg/node1
confctl build cz.vpsfree/nodes/stg/node2
```

Confirm that the database backup and the normal API rollback generation are
available. Keep the production `vpsadmin` and `vpsadminos` channel pins
unchanged until staging has completed its soak period.

## Deploy the API and migrate

Confirm that the security-advisory mutation/publication freeze is in effect.
Deploy the first API/supervisor host only after administrators and automation
have stopped changing drafts.

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
Verify that both WebUIs submit the current advisory content revision before
lifting the security-advisory mutation/publication freeze.

Deploy the service-only mailer/nodectld host after both supervisors are ready:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.vpsadmin1 switch
```

Verify `vpsadmin-nodectld.service`. This host has the mailer role, so it must
continue reporting ordinary status without kernel evidence and it has no
history backfill.

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

Backfill `node1.stg`, whose configured vpsAdmin Node ID is 400, on api1
immediately before switching it without rebooting:

```shell
NODE_ID=400 bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=400 bundle exec rake vpsadmin:node:history_backfill_status
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

Then re-enter `vpsadmin-api-shell` on api1 and backfill `node2.stg`, whose
configured vpsAdmin Node ID is 401:

```shell
NODE_ID=401 bundle exec rake vpsadmin:node:reconstruct_history
NODE_ID=401 bundle exec rake vpsadmin:node:history_backfill_status
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
VPSADMINOS_REVISION=736f689391bc3f920e808eb574662ed6a9e6c955
VPSADMIN_REVISION=c7e4b87854fe27619dd5450f93a1e5c4d4f8e4d1
production_pin_base=$(git rev-parse HEAD)

confctl inputs channel set --commit production vpsadminos \
  "$VPSADMINOS_REVISION"
confctl inputs channel set --commit production vpsadmin \
  "$VPSADMIN_REVISION"

test "$(git rev-list --count "$production_pin_base"..HEAD)" = 2
test "$(git diff --name-only "$production_pin_base"..HEAD)" = flake.lock
```

Inspect both resulting generated commits and confirm that each changes only its
intended production channel input. Keep their confctl-generated commit messages
unchanged.

Before building, reconcile every active hypervisor/storage row from
`history_backfill_status` with the current Node deployment inventory under
`cluster/cz.vpsfree/nodes/`. Use the `node.id` from each Node's `module.nix`;
do not infer it from the hostname or deployment order. Resolve missing or
duplicate mappings before continuing.

Build the selected production Nodes. For each Node, enter
`vpsadmin-api-shell` on api1, run its numeric-ID combined backfill immediately
before deployment, and verify `complete`:

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
backfills are safe to rerun after recovery. Keep all advisory draft mutation,
synchronization, and publication frozen while any API or WebUI is rolled back.
After the application fleet is on one version, re-read the advisory content
revision and repeat human review before allowing changes or publication.
