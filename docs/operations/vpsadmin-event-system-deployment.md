# Deploying the vpsAdmin event system

This runbook deploys the first production release of the vpsAdmin event system.
It covers the vpsAdmin API and WebUI, all `nodectld` consumers, RabbitMQ,
managed notification templates, Telegram and retirement of the old mailer
container. The physical SMS gateways, Alertmanager and Prometheus are deployed
first through the separate
[event infrastructure runbook](vpsadmin-event-infrastructure-deployment.md).

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
- convert supported, active per-user advanced template and role recipients to
  event routes, while deliberately skipping several legacy row classes that
  must be accounted for before deployment;
- convert global template-recipient address rules to administrator event
  routes;
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

1. keep the prepared proxy maintenance generation active and stop all new
   writers;
2. restore the pre-migration database snapshot and the previous database and
   RabbitMQ generations;
3. remove the runtime masks, switch the API and WebUI hosts to their previous
   generations, and verify them through the restricted frontends;
4. start the retained legacy mailer container; and
5. switch the proxy to its recorded pre-release generation to restore traffic.

After traffic is reopened, restoring the snapshot loses all writes made after
the cutover. Prefer a forward fix. Any later snapshot restore needs a separate
operator decision that accounts for the write-loss interval.

The new `nodectld` is backward-compatible with the old API and can remain
deployed during an application rollback. The widened RabbitMQ permissions and
the new SMS gateways can remain as well. No vpsAdminOS reboot is required, but
every running Node, storage host, backup host, and DNS `nodectld` must have the
new transaction handler before the API emits event-delivery release
transactions with handle `9002`.

## Infrastructure gate

Complete
[Deploying vpsAdmin event infrastructure](vpsadmin-event-infrastructure-deployment.md)
before preparing this maintenance cutover. Require its recorded approved
revisions, six active and rollback generation IDs, healthy Prometheus targets,
gateway queue checks and the confirmed `sms-aither` proof delivery.

This is a manual gate. Do not infer approval from elapsed time or healthy
metrics, and do not redeploy the APUs, Alertmanagers or Prometheus containers
from this runbook. The operator decides when the infrastructure evidence is
sufficient to continue.

## Prepare the exact release

Obtain all approved revisions through the normal review channel. Do not derive
them from whichever worktree happens to be present during deployment.

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
APPROVED_VPSADMIN_CHECKOUT=/PATH/TO/APPROVED/VPSADMIN/SOURCE
RECIPIENT_AUDIT_DIR=/RESTRICTED/PATH/FOR/DEPLOYMENT/RECORDS
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
test "$(git -C "$APPROVED_VPSADMIN_CHECKOUT" rev-parse HEAD)" = \
  "$VPSADMIN_REVISION"
test -z "$(
  git -C "$APPROVED_VPSADMIN_CHECKOUT" status \
    --porcelain --untracked-files=no
)"

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

The production proxy is also a vpsAdmin module consumer. It currently
overrides the `vpsadmin` channel with `proxyVpsadminBaseline`, whose revision
predates the `telegramWebhook` frontend option used by this release. Before
building the release, make a separate reviewed proxy change that removes the
`vpsadmin = "proxyVpsadminBaseline"` override so the proxy consumes the
approved `vpsadminServices` revision. Keep or remove the proxy's temporary
Nixpkgs and vpsAdminOS overrides according to the separately owned proxy
migration; do not change those baselines incidentally in this rollout. Stop if
the resulting proxy does not evaluate and build with the approved vpsAdmin
revision.

Verify the stale override is absent from the approved configuration:

```shell
if rg -q 'vpsadmin = "proxyVpsadminBaseline"' \
  cluster/cz.vpsfree/containers/prg/proxy/module.nix; then
  echo "proxy still uses the pre-event vpsAdmin baseline" >&2
  exit 1
fi
```

### Prepare the proxy maintenance generations

The proxy owns the production maintenance switch. Prepare and review two proxy
generations before the window:

1. a maintenance generation with the reconciled vpsAdmin input and
   `vpsadmin.frontend.maintenance.enable = true`; and
2. a release generation with the same configuration except
   `vpsadmin.frontend.maintenance.enable = false`.

Keep these as two reviewable configuration commits so the final approved
configuration has maintenance disabled. Build each commit, record its proxy
generation, and copy both closures to the proxy without activation:

```shell
confctl build cz.vpsfree/containers/prg/proxy
confctl generation ls --local
confctl deploy --generation PROXY_GENERATION --copy-only \
  cz.vpsfree/containers/prg/proxy
```

Also record the proxy generation that was active before either preparation
commit. The three immutable identifiers are
`PROXY_MAINTENANCE_GENERATION`, `PROXY_RELEASE_GENERATION`, and
`PROXY_ROLLBACK_GENERATION`. Confirm that the maintenance and release
generations both contain the exact Telegram webhook route and differ only in
the intended maintenance response behavior.

Build all affected machines before the maintenance window. Keep the generation
identifiers printed by `confctl`; deployment commands later in this runbook
must use those exact reviewed generations.

```shell
confctl build 'cz.vpsfree/vpsadmin/int.api*'
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build 'cz.vpsfree/vpsadmin/int.rabbitmq*'
confctl build cz.vpsfree/vpsadmin/int.db
confctl build cz.vpsfree/containers/prg/proxy
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

Also copy the selected Node and DNS generations before their preparatory
deployments. The proxy's two prepared closures were copied separately above.
Confirm normal rollback generations remain available everywhere.

Resolve and record the api1 toplevel from the selected local generation:

```shell
API1_GENERATION=REVIEWED_API1_GENERATION
API2_GENERATION=REVIEWED_API2_GENERATION
WEBUI1_GENERATION=REVIEWED_WEBUI1_GENERATION
WEBUI2_GENERATION=REVIEWED_WEBUI2_GENERATION
PROXY_MAINTENANCE_GENERATION=REVIEWED_MAINTENANCE_PROXY_GENERATION
PROXY_RELEASE_GENERATION=REVIEWED_RELEASE_PROXY_GENERATION
PROXY_ROLLBACK_GENERATION=PREVIOUS_PROXY_GENERATION
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

- `/private/vpsadmin-api-rabbitmq.pw`;
- `/private/vpsadmin-notification-rabbitmq.pw`;
- `/private/vpsadmin-telegram-bot-token`;
- `/private/vpsadmin-telegram-webhook-secret`;
- `/private/vpsadmin-sms-callback-token`; and
- `/private/vpsadmin-sms-gateway-token`.

The infrastructure runbook has already provisioned the APU copies of the SMS
gateway and callback tokens. The API and both APUs must have identical values.
Both API hosts must also have identical Telegram bot tokens and webhook
secrets. The API RabbitMQ password must be identical on both API hosts and for
the broker's `api` user. The notification RabbitMQ password must be identical
on both API hosts and for the broker's `notification` user used by the grouper
and dispatchers. Compare secrets through the approved secret-management
tooling or their protected checksums; never print their values. Check file
ownership and mode without displaying file contents.

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

### Reconcile per-user legacy recipients

The two per-user legacy recipient tables need a separate, complete audit.
Migration `20260722120100` converts only supported rows that satisfy its
conditions; migration `20260722120500` then drops both source tables. Generate
the authoritative supported template list and per-role route counts from the
approved source, not from this runbook. Store them with the restricted
deployment record:

```shell
umask 077
install -d -m 0700 "$RECIPIENT_AUDIT_DIR"

(
  cd "$APPROVED_VPSADMIN_CHECKOUT"
  nix develop .#api -c bundle exec ruby \
    -ractive_record \
    -r./db/migrate/20260722120100_add_events.rb \
    -e '
      values = AddEvents::ADVANCED_NOTIFICATION_EVENT_TEMPLATES.flat_map do |cfg|
        cfg.fetch(:legacy_template_names, [cfg.fetch(:template_name)])
      end
      File.write(ARGV.fetch(0), "#{values.uniq.sort.join("\n")}\n")
    ' \
    "$RECIPIENT_AUDIT_DIR/supported-template-names.txt"
)

(
  cd "$APPROVED_VPSADMIN_CHECKOUT"
  nix develop .#api -c bundle exec ruby \
    -ractive_record \
    -r./db/migrate/20260722120100_add_events.rb \
    -e '
      configs = AddEvents::ADVANCED_NOTIFICATION_EVENT_TEMPLATES
      roles = configs.flat_map { |cfg| cfg.fetch(:roles) }.uniq.sort
      rows = roles.map do |role|
        "#{role}\t#{configs.count { |cfg| cfg.fetch(:roles).include?(role) }}"
      end
      File.write(ARGV.fetch(0), "#{rows.join("\n")}\n")
    ' \
    "$RECIPIENT_AUDIT_DIR/supported-role-route-counts.tsv"
)
```

Record the complete source counts and rows before migration:

```sql
SELECT COUNT(*) AS user_template_recipient_count
FROM user_mail_template_recipients;
SELECT COUNT(*) AS user_role_recipient_count
FROM user_mail_role_recipients;

SELECT
  recipients.id,
  recipients.user_id,
  users.login,
  users.mailer_enabled,
  recipients.mail_template_id,
  mail_templates.name AS template_name,
  recipients.enabled,
  recipients.to
FROM user_mail_template_recipients AS recipients
LEFT JOIN users ON users.id = recipients.user_id
LEFT JOIN mail_templates ON mail_templates.id = recipients.mail_template_id
ORDER BY recipients.id;

SELECT
  recipients.id,
  recipients.user_id,
  users.login,
  users.mailer_enabled,
  recipients.role,
  recipients.to
FROM user_mail_role_recipients AS recipients
LEFT JOIN users ON users.id = recipients.user_id
ORDER BY recipients.id;
```

Classify every row against migration `20260722120100`:

- a template-recipient row is migrated only when its user exists, its template
  exists and is in `supported-template-names.txt`, the user's mailer is
  enabled, and either the row is disabled or `to` is non-empty;
- a disabled template-recipient row becomes one muted receiver and one route;
- an enabled template-recipient row becomes one receiver, one custom target,
  and one route;
- a role-recipient row is migrated only when its user exists, its role is in
  `supported-role-route-counts.tsv`, the user's mailer is enabled, and `to` is
  non-empty; it becomes one receiver, one custom target, and the number of
  routes recorded for that role in the second TSV column.

Run and retain explicit exception reports:

```sql
SELECT recipients.*
FROM user_mail_template_recipients AS recipients
LEFT JOIN users ON users.id = recipients.user_id
LEFT JOIN mail_templates ON mail_templates.id = recipients.mail_template_id
WHERE users.id IS NULL OR mail_templates.id IS NULL;

SELECT recipients.*
FROM user_mail_role_recipients AS recipients
LEFT JOIN users ON users.id = recipients.user_id
WHERE users.id IS NULL;

SELECT
  recipients.id,
  recipients.user_id,
  users.login,
  users.mailer_enabled,
  mail_templates.name AS template_name,
  recipients.enabled,
  recipients.to
FROM user_mail_template_recipients AS recipients
JOIN users ON users.id = recipients.user_id
JOIN mail_templates ON mail_templates.id = recipients.mail_template_id
WHERE users.mailer_enabled = 0
   OR (recipients.enabled <> 0 AND TRIM(COALESCE(recipients.to, '')) = '')
ORDER BY recipients.id;

SELECT
  recipients.id,
  recipients.user_id,
  users.login,
  users.mailer_enabled,
  recipients.role,
  recipients.to
FROM user_mail_role_recipients AS recipients
JOIN users ON users.id = recipients.user_id
WHERE users.mailer_enabled = 0
   OR TRIM(COALESCE(recipients.to, '')) = ''
ORDER BY recipients.id;
```

The two orphan reports must be empty. Compare every distinct source template
name and role with the generated support lists; unsupported values are a
separate skipped class and must be listed even if the SQL exception reports are
otherwise empty. Create a reconciliation matrix that assigns every source row
either its exact expected receiver, target, and route count or one of these
skipped classes:

- disabled user mailer;
- enabled template row with an empty target;
- role row with an empty target; or
- unsupported template or role.

Obtain an explicit operator/product decision for every non-empty skipped
class. Stop and revise the migration or prepare a separately reviewed manual
conversion if any loss is not accepted. The pre-migration snapshot and export
make loss recoverable; they do not make silent loss acceptable.

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

Audit the existing identities on a cluster member before reusing or rotating
them. RabbitMQ replicates its internal user database across the cluster:

```shell
confctl ssh cz.vpsfree/vpsadmin/int.rabbitmq1 \
  rabbitmqctl list_users
confctl ssh cz.vpsfree/vpsadmin/int.rabbitmq1 \
  rabbitmqctl list_connections user vhost name peer_host peer_port state
confctl ssh cz.vpsfree/vpsadmin/int.rabbitmq1 \
  rabbitmqctl list_user_permissions api
```

If `api` is absent, record that and skip `list_user_permissions` until after it
is created. If it exists, require no live connection and identify the owner of
every historical or observed use before changing it. Record all tags and every
vhost permission row, not only `vpsadmin_prod`.

The dedicated API identity must have no user tags and no permissions on an
unrelated vhost. Remove unwanted tags with `rabbitmqctl set_user_tags api` and
remove each reviewed, unused vhost row with
`rabbitmqctl clear_permissions -p VHOST api`. If any connection, tag or other
vhost permission belongs to a supported consumer, stop: rotating or narrowing
this account would break that consumer, and a separately reviewed identity
name is required.

Create `api` and `notification` only when absent. Set or rotate their passwords
through the operator-approved secret workflow so they match
`/private/vpsadmin-api-rabbitmq.pw` and
`/private/vpsadmin-notification-rabbitmq.pw`, respectively. Do not include a
password on a shared command line. Repeat the three inventory commands after
the change and retain their redacted output with the deployment record.

The existing `vpsadmin-rabbitmq-setup` service is state-file gated and does not
update existing users. Apply the new permissions explicitly from the approved
vpsAdmin revision:

```shell
ruby tools/rabbitmqcfg.rb user \
  --vhost vpsadmin_prod \
  --perms --execute \
  --host rabbitmq1.int.vpsfree.cz \
  api api

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

The API configure and write patterns are:

```text
^(vpsadmin\.notifications|vpsadmin\.notifications\.(email|telegram|sms|webhook|grouping))$
```

Its read pattern matches only the source exchange needed when binding queues:

```text
^vpsadmin\.notifications$
```

It deliberately does not match any notification queue, so the API cannot
consume delivery work. The API and workers may both idempotently declare the
same durable resources; a declaration with incompatible attributes fails and
must be investigated rather than replaced in place.

The notification worker profile grants configure, write, and read only for:

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
`vpsadmin-event-rabbitmq-permissions.service`, which reconciles the API and
notification profiles on every broker. It assumes that both users already
exist; if either does not, broker activation fails.

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

## Maintenance cutover

Announce the maintenance window. Switch the proxy to its prepared maintenance
generation before stopping any backend:

```shell
confctl deploy --generation "$PROXY_MAINTENANCE_GENERATION" \
  cz.vpsfree/containers/prg/proxy switch
```

Verify that the production API, authentication, console, download, and WebUI
frontends return their intended HTTP 503 maintenance responses while the
restricted `*-admin.vpsfree.cz` operator frontends still reach the old stack.
The exact Telegram webhook location is deliberately outside the generic API
maintenance location; the receiver is stopped with the API stack below and
Telegram will retry failed deliveries. Do not proceed until public API/WebUI
writes are closed. Keep all reviewed generation IDs, the database snapshot
destination, and the rollback operator available throughout the cutover.

### Stop all old writers

On api1, stop timers before their services. Production api2 has no rake timers.
Wait for running oneshots on both API hosts to finish, then stop and
runtime-mask the API stack. Include all discovered `vpsadmin-api-*.service`
units, not only the timers shown by the current configuration.

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
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

if (( ${#API_RAKE_UNITS[@]} > 0 )); then
  systemctl stop "${API_RAKE_UNITS[@]}"
fi
for unit in "${APPLICATION_UNITS[@]}"; do
  if systemctl cat "$unit" >/dev/null 2>&1; then
    systemctl stop "$unit"
  fi
done

MASK_UNITS=("${API_RAKE_UNITS[@]}" "${APPLICATION_UNITS[@]}")
systemctl mask --runtime "${MASK_UNITS[@]}"
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
and starts the event-system permission reconciler:

```shell
confctl deploy --generation GENERATION cz.vpsfree/vpsadmin/int.db switch
confctl deploy --generation GENERATION \
  'cz.vpsfree/vpsadmin/int.rabbitmq*' switch
```

All three brokers must be healthy. Confirm the separate `api` and
`notification` permission rows and the existing console/node permission
changes in `vpsadmin_prod` before continuing. The `api` read pattern must not
match any notification queue.

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

runuser --user vpsadmin-database -- env -C "$DB_WORKDIR" \
  RACK_ENV=production \
  SCHEMA=/var/lib/vpsadmin/database/cache/schema.rb \
  "$DB_BUNDLE" exec rake vpsadmin:plugins:status
```

All twelve core migrations and every plugin migration must report `up`. Stop
and investigate any error; do not run a down migration or hand-mark a
migration as complete.

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

Verify the same applicable services on api2. The scheduler is expected only on
api1. Production api2 has no rake timers, so do not run the api1 timer-start
command there.

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
- Reconcile every row from both per-user recipient source tables with the
  preflight matrix. Each accepted skipped row must remain explicitly accounted
  for; every row expected to migrate must have the exact receiver, target, and
  route count described by migration `20260722120100`.
- Confirm the number of migrated OOM rule routes equals the exported rule
  count, each has two matchers, and there is one grouped catch-all OOM route
  per user.
- Confirm every mailer-role Node is inactive.
- Confirm managed notification templates report the approved source revision.

Do not accept unexplained count differences.

Use the migration-specific receiver descriptions to produce the per-user
reconciliation report:

```sql
SELECT
  notification_receivers.user_id,
  notification_receivers.description,
  notification_receivers.mute,
  COUNT(DISTINCT notification_receiver_targets.notification_target_id)
    AS target_count,
  COUNT(DISTINCT event_routes.id) AS route_count
FROM notification_receivers
LEFT JOIN notification_receiver_targets
  ON notification_receiver_targets.notification_receiver_id =
     notification_receivers.id
LEFT JOIN event_routes
  ON event_routes.notification_receiver_id = notification_receivers.id
WHERE notification_receivers.description IN (
  'Created from an advanced notification template setting',
  'Created from an advanced notification template recipient',
  'Created from an advanced e-email role recipient'
)
GROUP BY
  notification_receivers.id,
  notification_receivers.user_id,
  notification_receivers.description,
  notification_receivers.mute
ORDER BY notification_receivers.user_id, notification_receivers.id;
```

The `e-email` spelling is the literal migration description. Treat the source
counts, accepted skipped counts, migrated receiver counts, target counts, and
role-expanded route counts as one conservation equation; their totals must
match the preflight matrix exactly.

### RabbitMQ and services

On a RabbitMQ cluster member, verify:

```shell
rabbitmqctl list_permissions --vhost vpsadmin_prod
rabbitmqctl list_exchanges --vhost vpsadmin_prod name type
rabbitmqctl list_queues --vhost vpsadmin_prod name consumers messages
rabbitmqctl list_connections user vhost name state channels
```

The `vpsadmin.notifications` exchange and the `.email`, `.telegram`, `.sms`,
`.webhook`, and `.grouping` queues must exist. Generate a controlled API event
so its lazy RabbitMQ connection opens. The API connection must use `api`; the
grouper and dispatchers must use `notification`. Confirm with an authenticated
negative probe that `api` can redeclare the equivalent durable resources and
publish, but receives `access_refused` when attempting to consume a
notification queue. Logs must contain no permission, schema, template, or
retry-loop errors.

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

Only after all database, RabbitMQ, service, protocol, and end-to-end checks
pass, switch the proxy to the prepared release generation:

```shell
confctl deploy --generation "$PROXY_RELEASE_GENERATION" \
  cz.vpsfree/containers/prg/proxy switch
```

Verify normal public API, authentication, console, download, and WebUI access,
plus the exact Telegram webhook route. This switch reopens production traffic.

## Rollback

If validation fails before traffic reopens:

1. keep or switch the proxy to `PROXY_MAINTENANCE_GENERATION` and verify that
   all public frontends remain closed;
2. stop and runtime-mask every new API, supervisor, scheduler, notification,
   and Telegram writer on both API hosts, and stop both WebUIs;
3. restore the authoritative pre-migration database snapshot;
4. switch the database and all RabbitMQ brokers to their previous generations;
5. on each API host, recreate the unit arrays from the cutover step and run
   `systemctl unmask --runtime "${MASK_UNITS[@]}"`; unmasking does not start
   the services while maintenance remains active;
6. switch api2 and api1 to their previous generations, with api1 last so the
   old scheduler and rake timers resume only after the old schema and brokers
   are ready;
7. switch both WebUIs to their previous generations and verify the legacy API,
   scheduler, timers, supervisor, console, and WebUI units;
8. power on `int.vpsadmin1` and start its old `vpsadmin-nodectld.service`;
9. verify old mail transactions, API reads/writes through the restricted admin
   frontend, RabbitMQ connections, and WebUI operation; and
10. switch the proxy to `PROXY_ROLLBACK_GENERATION`, verify public operation,
    and only then declare production traffic restored.

Do not attempt to switch a legacy API generation while its unit names remain
runtime-masked. The mask survives a NixOS switch and prevents both service
startup and successful health checks.

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
