# Deploying the vpsAdmin event system

This runbook deploys the first production release of the vpsAdmin event system.
It covers the vpsAdmin API and WebUI, all `nodectld` consumers, RabbitMQ,
managed notification templates, Telegram, the two physical SMS gateways, and
retirement of the old mailer container.

This is a release-specific maintenance deployment. Do not use it for a later
event-system revision without checking that its migrations, message protocol,
secrets, and service inventory still match this document.

The database migration is the point of no return. The first event migration
renames tables used by the old application, intermediate migrations remove the
old mail recipient configuration, and the last migration removes the OOM rule
schema irreversibly. Old and new API processes must not run together across
this migration boundary.

## Compatibility and rollback boundary

The release includes migrations `20260722120000` through `20260722121000`.
They:

- rename the old mail template and recipient tables;
- add events, routes, receivers, targets, delivery attempts, grouping, rate
  limits, and time intervals;
- preserve disabled user mail delivery in the new delivery-method table;
- convert advanced template and role recipients to event routes;
- mark all legacy mailer-role Nodes inactive;
- convert every OOM rule to an ordered event route and add one grouped OOM
  catch-all route per account; and
- remove `oom_report_rules` and the legacy OOM columns.

Migration `20260722121000 MigrateOomReportRulesToRoutes` raises
`ActiveRecord::IrreversibleMigration` on rollback. Other down migrations are
also insufficient for production recovery: the recipient-table down migration
recreates empty tables, and the mailer retirement migration intentionally does
not reactivate mailer Nodes.

The supported rollback before reopening production traffic is therefore:

1. stop all new writers;
2. restore the pre-migration database snapshot;
3. switch the API, WebUI, database, and RabbitMQ hosts to their previous
   generations; and
4. start the retained legacy mailer container and restore traffic.

After traffic is reopened, restoring the snapshot loses all writes made after
the cutover. Prefer a forward fix. Any later snapshot restore needs a separate
operator decision that accounts for the write-loss interval.

The new `nodectld` is backward-compatible with the old API and can remain
deployed during an application rollback. The widened RabbitMQ permissions and
the new SMS gateways can remain as well. No vpsAdminOS reboot is required, but
every running Node, storage host, backup host, and DNS `nodectld` must have the
new transaction handler before the API emits event-delivery release
transactions with handle `9002`.

## Prepare the exact release

Obtain all approved revisions through the normal review channel. Do not derive
them from whichever worktree happens to be present during deployment.

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMIN_REVISION=REVIEWED_VPSADMIN_REVISION
NOTIFICATION_TEMPLATES_REVISION=REVIEWED_TEMPLATE_REVISION
SMS_GATEWAY_REVISION=REVIEWED_SMS_GATEWAY_REVISION
```

The three vpsAdmin channels must use the same revision. Update their pins in a
reviewed configuration change before the deployment, using `confctl` rather
than editing `flake.lock`:

```shell
confctl inputs channel set --commit vpsadmin vpsadmin "$VPSADMIN_REVISION"
confctl inputs channel set --commit staging vpsadmin "$VPSADMIN_REVISION"
confctl inputs channel set --commit production vpsadmin "$VPSADMIN_REVISION"
```

Verify the approved configuration and all release inputs:

```shell
test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"

test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminStaging.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsadminProduction.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsfreeNotificationTemplates.locked.rev' flake.lock)" = \
  "$NOTIFICATION_TEMPLATES_REVISION"
test "$(jq -r '.nodes.vpsfreeSmsGateway.locked.rev' flake.lock)" = \
  "$SMS_GATEWAY_REVISION"

confctl inputs channel ls vpsadmin
confctl inputs channel ls staging
confctl inputs channel ls production
```

Stop if a pin differs. `vpsadminServices` supplies the API, WebUI, and DNS
containers. `vpsadminStaging` and `vpsadminProduction` supply the running
vpsAdminOS Nodes. A partial pin update can leave an old `nodectld` unable to
complete new transaction chains.

Build all affected machines before the maintenance window. Keep the generation
identifiers printed by `confctl`; deployment commands later in this runbook
must use those exact reviewed generations.

```shell
confctl build 'cz.vpsfree/vpsadmin/int.api*'
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build 'cz.vpsfree/vpsadmin/int.rabbitmq*'
confctl build cz.vpsfree/vpsadmin/int.db
confctl build cz.vpsfree/machines/brq/apu
confctl build cz.vpsfree/machines/prg/apu
confctl build 'cz.vpsfree/containers/ns*'
confctl build 'cz.vpsfree/nodes/stg/*'
confctl build 'cz.vpsfree/nodes/brq/*'
confctl build 'cz.vpsfree/nodes/prg/*'
confctl build 'cz.vpsfree/nodes/pgnd/*'
confctl generation ls --local
```

Copy the selected generations to their hosts without activating them:

```shell
confctl deploy --generation GENERATION --copy-only \
  'cz.vpsfree/vpsadmin/int.api*'
confctl deploy --generation GENERATION --copy-only \
  cz.vpsfree/vpsadmin/int.webui1
confctl deploy --generation GENERATION --copy-only \
  cz.vpsfree/vpsadmin/int.webui2
confctl deploy --generation GENERATION --copy-only \
  'cz.vpsfree/vpsadmin/int.rabbitmq*'
confctl deploy --generation GENERATION --copy-only \
  cz.vpsfree/vpsadmin/int.db
```

Also copy the selected Node, DNS, and APU generations before their preparatory
deployments. Confirm normal rollback generations remain available everywhere.

Resolve and record the api1 toplevel from the selected local generation:

```shell
API1_GENERATION=REVIEWED_API1_GENERATION
API2_GENERATION=REVIEWED_API2_GENERATION
WEBUI1_GENERATION=REVIEWED_WEBUI1_GENERATION
WEBUI2_GENERATION=REVIEWED_WEBUI2_GENERATION
API1_NEW_SYSTEM="$(
  readlink -f \
    ".confctl/generations/cz.vpsfree:vpsadmin:int.api1/$API1_GENERATION/toplevel"
)"
test -d "$API1_NEW_SYSTEM"
```

The same immutable `/nix/store` path is available on api1 after `--copy-only`.
It will supply the migration package without activating the new API.

## Provision secrets

Provision secrets before activating a generation that consumes them. Use the
normal encrypted secret-distribution process. Do not put secret values in the
configuration repository, shell history, deployment notes, or command output.

Both API hosts require:

- `/private/vpsadmin-notification-rabbitmq.pw`;
- `/private/vpsadmin-telegram-bot-token`;
- `/private/vpsadmin-telegram-webhook-secret`;
- `/private/vpsadmin-sms-callback-token`; and
- `/private/vpsadmin-sms-gateway-token`.

Both `apu.brq` and `apu.prg` require:

- `/private/alertmanager/sms_gateway_token.txt`;
- `/private/vpsadmin-sms-gateway-token`;
- `/private/vpsfree-sms-gateway/status-token`; and
- `/private/vpsadmin-sms-callback-token`.

The API and both APUs must have identical vpsAdmin gateway and callback tokens.
Check file ownership and mode without displaying file contents.

## Run the database preflight

Run these read-only checks against the pre-migration production database. Keep
their counts with the deployment record.

First confirm that none of the event migration versions is present:

```sql
SELECT version
FROM schema_migrations
WHERE version BETWEEN '20260722120000' AND '20260722121000'
ORDER BY version;
```

The query must return no rows. Separately inspect the approved vpsAdmin source
and confirm it contains exactly the following pending range:

The expected pending range is exactly:

```text
20260722120000 Rename notification template tables
20260722120100 Add events
20260722120200 Add user notification delivery methods
20260722120300 Remove users mailer enabled
20260722120400 Add event routing contexts
20260722120500 Migrate legacy email recipients to routes
20260722120600 Add notification rate limits
20260722120700 Refine event route matches
20260722120730 Normalize default notification labels
20260722120800 Retire mailer nodes
20260722120900 Add event time intervals
20260722121000 Migrate OOM report rules to routes
```

List every configured global legacy recipient:

```sql
SELECT
  mail_templates.name AS template_name,
  mail_recipients.label AS recipient_label,
  mail_recipients.to,
  mail_recipients.cc,
  mail_recipients.bcc
FROM mail_template_recipients
JOIN mail_templates
  ON mail_templates.id = mail_template_recipients.mail_template_id
JOIN mail_recipients
  ON mail_recipients.id = mail_template_recipients.mail_recipient_id
ORDER BY mail_templates.name, mail_recipients.id;
```

For every comma-separated address in `to`, `cc`, and `bcc`, verify that it
resolves to exactly one user by case-insensitive primary e-mail. When no user
has that e-mail, the recipient label may resolve to exactly one login. The
resolved user must have `level >= 90`. Compare every listed template name with
`MigrateLegacyEmailRecipientsToRoutes::TEMPLATE_ROUTE_MAP` in the approved
migration. Stop if a template is unknown, an address is ambiguous or missing,
or a recipient resolves to a non-administrator; migration `20260722120500`
rejects all of those cases.

Confirm every OOM rule joins an existing VPS and owner:

```sql
SELECT COUNT(*) AS orphan_oom_rules
FROM oom_report_rules
LEFT JOIN vpses ON vpses.id = oom_report_rules.vps_id
LEFT JOIN users ON users.id = vpses.user_id
WHERE vpses.id IS NULL OR users.id IS NULL;
```

`orphan_oom_rules` must be zero. Record these conversion source counts:

```sql
SELECT COUNT(*) AS user_count FROM users;
SELECT COUNT(*) AS disabled_mailer_count
FROM users
WHERE mailer_enabled = 0;
SELECT COUNT(*) AS legacy_recipient_link_count
FROM mail_template_recipients;
SELECT COUNT(*) AS oom_rule_count FROM oom_report_rules;
SELECT COUNT(DISTINCT vpses.user_id) AS oom_rule_owner_count
FROM oom_report_rules
JOIN vpses ON vpses.id = oom_report_rules.vps_id;
SELECT COUNT(*) AS active_mailer_nodes
FROM nodes
WHERE role = 2 AND active <> 0;
```

Finally, drain old mail deliveries before stopping the mailer. Transaction
handle `9001` is `Transactions::Mail::Send`; `done = 1` is complete:

```sql
SELECT id, node_id, done, created_at
FROM transactions
WHERE handle = 9001 AND done <> 1
ORDER BY id;
```

The result must be empty and remain empty before the maintenance window starts.

## Prepare RabbitMQ

The production vhost is `vpsadmin_prod`. Do not rely on
`tools/rabbitmqcfg.rb`'s development-vhost default.

Create the `notification` RabbitMQ user once on a cluster member before
deploying the RabbitMQ generation. RabbitMQ replicates its internal user
database across the cluster. Enter its password through the operator-approved
secret workflow so it matches
`/private/vpsadmin-notification-rabbitmq.pw`; do not include the password on a
shared command line.

The existing `vpsadmin-rabbitmq-setup` service is state-file gated and does not
update existing users. Apply the new permissions explicitly from the approved
vpsAdmin revision:

```shell
ruby tools/rabbitmqcfg.rb user \
  --vhost vpsadmin_prod \
  --perms --execute \
  --host rabbitmq1.int.vpsfree.cz \
  notification notification

ruby tools/rabbitmqcfg.rb user \
  --vhost vpsadmin_prod \
  --perms --execute \
  --host rabbitmq1.int.vpsfree.cz \
  console console-router
```

The notification profile grants configure, write, and read only for:

```text
^(amq\.gen.*|vpsadmin\.notifications|vpsadmin\.notifications\.(email|telegram|sms|webhook|grouping))$
```

The console profile adds control exchanges to its configure and write access.
The supervisor profile remains `.*` and needs no change.

Enumerate the current RabbitMQ users and compare them with the complete active
Node/storage/DNS inventory. Reapply the node profile to every account used by a
live `nodectld`, including `ns0` through `ns4`. Do not apply it to arbitrary
RabbitMQ users:

```shell
for rabbit_user in VERIFIED_NODE_AND_DNS_USERNAMES; do
  ruby tools/rabbitmqcfg.rb user \
    --vhost vpsadmin_prod \
    --perms --execute \
    --host rabbitmq1.int.vpsfree.cz \
    node "$rabbit_user"
done
```

The node profile adds writes to `vpsadmin.notifications` and access to the
account's own console input/control resources. Verify the resulting rows before
continuing:

```shell
confctl ssh cz.vpsfree/vpsadmin/int.rabbitmq1 \
  rabbitmqctl list_permissions --vhost vpsadmin_prod
```

The new RabbitMQ generation contains
`vpsadmin-notification-rabbitmq-permissions.service`, which reconciles the
notification profile on every broker. It assumes that the user already exists;
if it does not, broker activation fails.

## Deploy compatible prerequisites

These changes are compatible with the old API and should be deployed and
verified before the maintenance window.

### Update all nodectld consumers

Deploy staging first, exercise ordinary transaction chains, then update every
production Node, storage host, backup host, and DNS container. The inventory
currently includes the `stg`, `brq`, `prg`, and `pgnd` Node groups plus
`backuper2` and `ns0` through `ns4`; reconcile this list with live inventory at
deployment time.

```shell
confctl deploy --generation GENERATION 'cz.vpsfree/nodes/stg/*' switch
confctl deploy --generation GENERATION 'cz.vpsfree/containers/ns*' switch
confctl deploy --generation GENERATION 'cz.vpsfree/nodes/brq/*' switch
confctl deploy --generation GENERATION 'cz.vpsfree/nodes/prg/*' switch
confctl deploy --generation GENERATION 'cz.vpsfree/nodes/pgnd/*' switch
```

For every host, verify `nodectld` is healthy, connected to RabbitMQ, and running
the reviewed vpsAdmin revision. Confirm ordinary transaction processing and
DNS updates still advance. Do not start the API cutover while any old consumer
remains capable of receiving handle `9002`.

### Deploy the SMS gateways

Deploy the BRQ and PRG APUs one at a time:

```shell
confctl deploy --generation GENERATION cz.vpsfree/machines/brq/apu switch
confctl deploy --generation GENERATION cz.vpsfree/machines/prg/apu switch
```

The service creates and retains
`/var/lib/vpsfree-sms-gateway/gateway.db`. A new empty database initializes at
schema version 1. The service refuses an unversioned or incompatible database;
there is no sachet database migration. Preserve this file across restarts.

Verify `vpsfree-sms-gateway.service`, its authenticated status endpoint, modem
access, and queue state on both APUs. Send a test SMS only to an
operator-approved number. The Alertmanager path prefers the PRG physical
gateway, then BRQ, then the existing local sachet/Nexmo fallback. The vpsAdmin
dispatcher prefers BRQ and then PRG. Do not remove sachet as part of this
release.

## Maintenance cutover

Announce the maintenance window and disable external API/WebUI writes. Keep the
reviewed generation IDs, database snapshot destination, and rollback operator
available throughout the cutover.

### Stop all old writers

On both API hosts, stop timers before their services, wait for running
oneshots to finish, then stop and runtime-mask the API stack. Include all
`vpsadmin-api-*.service` units, not only the timers shown by the current
configuration.

```shell
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  systemctl stop 'vpsadmin-api-*.timer'
```

Wait until `systemctl list-units 'vpsadmin-api-*.service' --state=activating`
is empty on both hosts. Do not terminate an in-progress task merely to shorten
the maintenance preparation.

On each API host, collect the installed rake services, stop the old stack, and
runtime-mask old and new writer units:

```shell
mapfile -t API_RAKE_UNITS < <(
  systemctl list-unit-files --type=service --no-legend \
    'vpsadmin-api-*' |
    awk '{print $1}'
)

APPLICATION_UNITS=(
  vpsadmin-api.service
  vpsadmin-supervisor.service
  vpsadmin-scheduler.service
  vpsadmin-console-router.service
  vpsadmin-notification-grouper.service
  vpsadmin-notification-dispatcher-email.service
  vpsadmin-notification-dispatcher-telegram.service
  vpsadmin-notification-dispatcher-webhook.service
  vpsadmin-notification-dispatcher-sms.service
  vpsadmin-telegram-receiver.service
)

systemctl stop "${API_RAKE_UNITS[@]}"
for unit in "${APPLICATION_UNITS[@]}"; do
  if systemctl cat "$unit" >/dev/null 2>&1; then
    systemctl stop "$unit"
  fi
done
systemctl mask --runtime "${API_RAKE_UNITS[@]}" "${APPLICATION_UNITS[@]}"
```

The runtime-masked set includes:

- `vpsadmin-api.service`;
- every `vpsadmin-api-*.service` writer;
- `vpsadmin-supervisor.service`;
- `vpsadmin-scheduler.service` where present;
- `vpsadmin-console-router.service`;
- all notification dispatcher and grouping services; and
- `vpsadmin-telegram-receiver.service`.

Runtime masks prevent the NixOS switch from starting the new application
before migrations finish. Do not mask
`vpsadmin-database-setup.service`; with `autoSetup = false`, it prepares the
database application's configuration but does not run migrations.

Recheck transaction handle `9001`. When it is empty, stop
`vpsadmin-nodectld.service` on `int.vpsadmin1` and power the container off.
Retain the powered-off container and its previous generation until final
acceptance.

Verify there are no remaining API, supervisor, scheduler, notification, or
mailer database writers before taking the backup.

### Take the database backup and targeted export

With all writers stopped, take an authoritative snapshot of the production
database container and its persistent storage using the normal infrastructure
snapshot workflow. Record the immutable snapshot identifier and verify that the
restore operator can locate it. A full logical dump is not required.

Also create a small logical recovery bundle outside the repository. Set
`umask 077`, export schema and rows without printing credentials, and include:

- full data and definitions for `mail_recipients`, `mail_templates`,
  `mail_template_recipients`, `mail_template_translations`,
  `user_mail_role_recipients`, `user_mail_template_recipients`, and
  `oom_report_rules`;
- `users(id, login, email, level, mailer_enabled)`;
- `nodes(id, name, role, active)` for `role = 2`;
- `vpses(id, user_id, implicit_oom_report_rule_hit_count)`;
- `oom_reports(id, oom_report_rule_id, reported_at, ignored)`; and
- `schema_migrations` plus the preflight source counts.

Use `mariadb-dump` for the small complete tables and batch SQL/TSV output for
the selected columns. Generate SHA-256 checksums for every file, keep ownership
restricted to the deployment operators, and record the recovery-bundle path.
This bundle supports conversion auditing and selective manual recovery; the
snapshot remains the only complete rollback artifact.

### Activate infrastructure changes

With the old mailer stopped, switch the database and RabbitMQ hosts to their
prepared generations. This removes `int.vpsadmin1` from their client allowlists
and starts the notification permission reconciler:

```shell
confctl deploy --generation GENERATION cz.vpsfree/vpsadmin/int.db switch
confctl deploy --generation GENERATION \
  'cz.vpsfree/vpsadmin/int.rabbitmq*' switch
```

All three brokers must be healthy. Confirm the `notification` permission row
and the existing console/node permission changes in `vpsadmin_prod` before
continuing.

### Run migrations once from the copied api1 generation

Keep the active api1 generation and every application writer stopped. On api1,
set `API1_NEW_SYSTEM` to the immutable toplevel recorded after `--copy-only`
and confirm its database unit exists:

```shell
test -d "$API1_NEW_SYSTEM"
DB_UNIT="$(
  readlink -f \
    "$API1_NEW_SYSTEM/etc/systemd/system/vpsadmin-database-setup.service"
)"
test -f "$DB_UNIT"
```

Derive the exact database package and setup command from that inactive unit,
not from the old active unit, a worktree, or an ambient Ruby installation:

```shell
DB_WORKDIR="$(sed -n 's/^WorkingDirectory=//p' "$DB_UNIT")"
DB_SETUP="$(sed -n 's/^ExecStart=//p' "$DB_UNIT")"

echo "$DB_WORKDIR" |
  grep -Eq '^/nix/store/.+-vpsadmin-database-.+/database$'
echo "$DB_SETUP" |
  grep -Eq '^/nix/store/.+-vpsadmin-database-setup-start/bin/'

DB_PACKAGE="${DB_WORKDIR%/database}"
DB_BUNDLE="$DB_PACKAGE/ruby-env/bin/bundle"
test -x "$DB_SETUP"
test -x "$DB_BUNDLE"
```

Production sets `vpsadmin.databaseSetup.autoSetup = false`. Inspect the copied
setup script and stop if it contains `db:migrate`, `db:schema:load`, or a seed
task. Then run it as the setup user to prepare the new package's configuration
and database credentials without migrating:

```shell
if grep -Eq 'db:(migrate|schema:load|seed)' "$DB_SETUP"; then
  echo "copied database setup unexpectedly mutates schema or data" >&2
  exit 1
fi

runuser --user vpsadmin-database -- env -C "$DB_WORKDIR" \
  RACK_ENV=production \
  SCHEMA=/var/lib/vpsadmin/database/cache/schema.rb \
  "$DB_SETUP"
```

Run the core and plugin migrations as the privileged setup user:

```shell
runuser --user vpsadmin-database -- env -C "$DB_WORKDIR" \
  RACK_ENV=production \
  SCHEMA=/var/lib/vpsadmin/database/cache/schema.rb \
  "$DB_BUNDLE" exec rake db:migrate

runuser --user vpsadmin-database -- env -C "$DB_WORKDIR" \
  RACK_ENV=production \
  SCHEMA=/var/lib/vpsadmin/database/cache/schema.rb \
  "$DB_BUNDLE" exec rake vpsadmin:plugins:migrate

runuser --user vpsadmin-database -- env -C "$DB_WORKDIR" \
  RACK_ENV=production \
  SCHEMA=/var/lib/vpsadmin/database/cache/schema.rb \
  "$DB_BUNDLE" exec rake db:migrate:status
```

All twelve migrations must report `up`. Stop and investigate any error; do not
run a down migration or hand-mark a migration as complete.

### Activate the application

Now that the schema is ready, recreate `API_RAKE_UNITS` and
`APPLICATION_UNITS` from the stop step in a root shell on api1 and unmask them:

```shell
systemctl unmask --runtime "${API_RAKE_UNITS[@]}" "${APPLICATION_UNITS[@]}"
```

From the approved configuration checkout, switch api1:

```shell
confctl deploy --generation "$API1_GENERATION" \
  cz.vpsfree/vpsadmin/int.api1 switch
```

Back on api1, enable the rake timers:

```shell
systemctl start 'vpsadmin-api-*.timer'
```

Verify the new stack on api1:

- `vpsadmin-api.service`;
- `vpsadmin-supervisor.service`;
- `vpsadmin-scheduler.service` on api1;
- `vpsadmin-console-router.service`;
- `vpsadmin-notification-grouper.service`;
- the email, Telegram, webhook, and SMS dispatcher services; and
- `vpsadmin-telegram-receiver.service`.

Starting the API installs the approved managed notification templates under
their source revision. Do not continue unless all applicable units are healthy
and stable.

Then recreate the two unit arrays in a root shell on api2 and unmask them:

```shell
systemctl unmask --runtime "${API_RAKE_UNITS[@]}" "${APPLICATION_UNITS[@]}"
```

From the configuration checkout, switch api2:

```shell
confctl deploy --generation "$API2_GENERATION" \
  cz.vpsfree/vpsadmin/int.api2 switch
```

Back on api2, enable the rake timers:

```shell
systemctl start 'vpsadmin-api-*.timer'
```

Verify the same applicable services on api2. The scheduler is expected only on
api1.

Switch both WebUI hosts only after both APIs are healthy:

```shell
confctl deploy --generation "$WEBUI1_GENERATION" \
  cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy --generation "$WEBUI2_GENERATION" \
  cz.vpsfree/vpsadmin/int.webui2 switch
```

Keep maintenance mode enabled until all checks below pass.

## Verify the cutover

### Database and converted data

- Confirm migrations `20260722120000` through `20260722121000` are `up`.
- Confirm the old mail recipient tables, `oom_report_rules`,
  `users.mailer_enabled`, and the removed OOM columns no longer exist.
- Confirm every user has the expected default notification receivers, targets,
  and top-level routes.
- Compare disabled e-mail delivery rows with the exported
  `mailer_enabled = 0` count.
- Reconcile each exported global recipient address with its new administrator
  target, receiver, route, and matchers.
- Confirm the number of migrated OOM rule routes equals the exported rule
  count, each has two matchers, and there is one grouped catch-all OOM route
  per user.
- Confirm every mailer-role Node is inactive.
- Confirm managed notification templates report the approved source revision.

Do not accept unexplained count differences.

### RabbitMQ and services

On a RabbitMQ cluster member, verify:

```shell
rabbitmqctl list_permissions --vhost vpsadmin_prod
rabbitmqctl list_exchanges --vhost vpsadmin_prod name type
rabbitmqctl list_queues --vhost vpsadmin_prod name consumers messages
rabbitmqctl list_connections user vhost name state channels
```

The `vpsadmin.notifications` exchange and the `.email`, `.telegram`, `.sms`,
`.webhook`, and `.grouping` queues must exist. The notification services must
have live `notification` connections, and logs must contain no permission,
schema, template, or retry-loop errors.

On both API hosts, verify all applicable units listed in the activation step
are active with no restart loop. Confirm API and WebUI health checks pass on
both frontends. Verify the public Telegram webhook
`https://api.vpsfree.cz/_telegram/webhook` and the internal SMS callback
`/internal/notifications/sms/callback` are routed and authenticated without
displaying their secrets.

Verify every Node/storage/DNS `nodectld` still processes ordinary transactions
and that no handle `9002` chain is stranded. Confirm both SMS gateways remain
healthy.

Finally, generate controlled events that exercise e-mail, Telegram, webhook,
grouping, and SMS delivery. External messages are real: use approved recipients
and an approved test phone number. Confirm event, route-match, delivery, and
delivery-attempt audit rows agree with the observed messages.

Reopen production traffic only after all database, RabbitMQ, service,
protocol, and end-to-end checks pass.

## Rollback

If validation fails before traffic reopens:

1. stop and runtime-mask every new API, supervisor, scheduler, notification,
   Telegram, and WebUI writer;
2. restore the authoritative pre-migration database snapshot;
3. switch api2, api1, both WebUIs, the database, and all RabbitMQ brokers to
   their previous generations;
4. power on `int.vpsadmin1` and start its old `vpsadmin-nodectld.service`;
5. verify old mail transactions, API reads/writes, RabbitMQ connections, and
   WebUI operation; and
6. restore production traffic.

The snapshot restores the original mailer Node state. Do not rely on migration
downs to recreate recipient or OOM data. If the old mailer had been inactive
before the snapshot, preserve that operator state rather than enabling it
blindly.

After traffic has reopened, keep the new system stopped while deciding between
a forward repair and an explicitly approved restore with data reconciliation.
Never restore the old snapshot silently over post-cutover writes.

## Post-deployment work

Keep the old mailer container powered off until the acceptance period ends,
then decommission it through a separate reviewed operation. Keep the database
snapshot and targeted logical export for the agreed recovery-retention period.

Publish the matching generated Go client and update any Terraform or automation
consumer after the server release is accepted. The legacy OOM-rule resource is
removed, so old clients that call it are no longer compatible.

Publish the prepared Czech and English knowledge-base changes only after the
runtime rollout succeeds and a user gives the separate production KB approval.

Monitor API, supervisor, notification, Telegram, SMS gateway, RabbitMQ, mail,
and transaction-chain error rates through the acceptance period. Record the
exact deployed revisions, snapshot and export identifiers, count
reconciliation, smoke-test results, and the decision to retire the mailer.
