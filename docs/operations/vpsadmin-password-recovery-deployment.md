# Deploying vpsAdmin password recovery and password history

This runbook deploys self-service password recovery through the vpsAdmin OAuth
server and the password change history in the API and WebUI. Recovery links are
sent only for ordinary member accounts with TOTP or a passkey. Support and
administrator accounts receive an email directing them to another
administrator. The public form gives the same response for every submitted
login or email address.

This is a release-specific runbook. Use the reviewed revisions below for this
rollout only.

## Reviewed revisions

```shell
VPSADMIN_REVISION=227dab2f6ee83749eee47382b36d6d602648b1c3
NOTIFICATION_TEMPLATES_REVISION=f944ba03eba5d0d6b58b7eb856f251d1c96f2c11
```

The configuration commits for this release pin `vpsadminServices` and
`vpsfreeNotificationTemplates` to the revisions above. The staging and
production Node channels are unchanged because the feature does not change the
vpsAdminOS protocol or Node software.

Before building, obtain the exact configuration commit approved for rollout
through the normal review process. Set `APPROVED_CONFIGURATION_REVISION` to
that value and verify the checkout and service pin:

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMIN_REVISION=227dab2f6ee83749eee47382b36d6d602648b1c3
NOTIFICATION_TEMPLATES_REVISION=f944ba03eba5d0d6b58b7eb856f251d1c96f2c11

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
test "$(jq -r '.nodes.vpsfreeNotificationTemplates.locked.rev' flake.lock)" = \
  "$NOTIFICATION_TEMPLATES_REVISION"
```

## Compatibility and ordering

The release adds five migrations:

- `20260818115900 Add authentication generation` adds a defaulted user
  generation used to reject credentials issued concurrently with a password
  change.
- `20260818120000 Add password recovery` adds the recovery queue and state,
  OAuth client start URLs and completion behavior, WebAuthn recovery context,
  and a user email index. Each recovery can record the exact TOTP device or
  passkey that completed MFA. These nullable snapshots let factor revocation
  invalidate only the recoveries authorized by that factor.
- `20260821120000 Add password event counters` adds aggregate counters and
  timestamps for recovery admission and password changes. The table contains
  fixed event names and no account identifiers.
- `20260821210000 Add password change logs` adds the detailed password change
  history. Each row records the affected user, change source, time, client IP
  address, server-resolved PTR, normalized user agent, and the exact initiating
  session when one exists. A pending OAuth authorization can carry the row
  until code exchange creates the real session. The migration does not backfill
  earlier password changes or client details.
- `20260823100000 Add default OAuth2 client` adds a nullable default-client
  flag and a unique index that permits at most one selected client. Existing
  clients remain unselected until the operator chooses the default.

The MFA revocation, bounded passkey challenge, and OAuth client deletion
hardening uses this schema and does not add a sixth migration.

All five migrations are additive. Old API processes can read the expanded
schema, and a rollback can leave it in place. New and old API processes may
overlap briefly while the feature remains disabled, but update both API hosts
and both recovery workers before enabling recovery. That keeps password
changes, credential issuance, MFA factor revocation, and recovery processing
on the same implementation.

An old process cannot populate the new client snapshot fields and, depending on
its revision, can omit the detailed history row entirely. These details cannot
be reconstructed. Keep this accepted audit gap as short as possible by
switching api2 immediately after api1 is healthy. If a new process creates a
pending required-reset authorization and an old process exchanges its code, the
authorization retains enough information for the authentication maintenance
task to attach the exact session later.

The feature flag defaults to off. `int.api1` treats the reviewed external
package as the complete notification-template source. The effective package
does not add bundled core or plugin defaults, and database setup does not
install those defaults. `vpsadmin-notification-templates.service` reconciles
the external package into the shared database. The API and supervisor require
this one-shot service, so neither can start on api1 with missing or invalid
template content. Keep recovery disabled until the templates, migrations, both
API hosts, both WebUI hosts, the auth frontend, and OAuth client start URLs are
in place. No Node update or reboot is required.

## Build the affected hosts

Build both API hosts, both WebUI hosts, the frontend host, and both Prometheus
hosts before the rollout:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/vpsadmin/int.webui1
confctl build cz.vpsfree/vpsadmin/int.webui2
confctl build cz.vpsfree/containers/prg/proxy
confctl build cz.vpsfree/containers/prg/int.mon1
confctl build cz.vpsfree/containers/prg/int.mon2
```

## Reconcile the notification templates

The templates are deployed declaratively on api1 in replacement mode. Do not
upload them through the API. Only the external package supplies templates to a
new database, although reconciliation preserves existing database rows that
the package omits. Password-change notifications are active independently of
the recovery feature flag, so `user_password_changed` must be reconciled before
either upgraded API starts.

Keep api1 out of service while switching its configuration. The notification
template service is not masked: it starts from the new configuration and
updates the shared database before the API is allowed to return.

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl mask --runtime --now vpsadmin-api.service \
    vpsadmin-password-recovery.service \
    vpsadmin-api-auth-tokens.timer \
    vpsadmin-api-auth-tokens.service \
    vpsadmin-api-prometheus-export-base.timer \
    vpsadmin-api-prometheus-export-base.service
confctl deploy cz.vpsfree/vpsadmin/int.api1 switch
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Result vpsadmin-notification-templates.service
```

The service must report `Result=success`. If it fails, leave the API masked and
inspect `journalctl --unit vpsadmin-notification-templates.service` before
continuing.

From `vpsadmin-api-shell`, verify the reconciled variants in the shared
database:

```ruby
templates = MailTemplate
  .includes(mail_template_translations: :language)
  .where(name: %w[password_recovery user_password_changed])
  .index_by(&:name)

recovery = templates.fetch('password_recovery')
  .mail_template_translations
  .index_by { |translation| translation.language.code }
changed = templates.fetch('user_password_changed')
  .mail_template_translations
  .index_by { |translation| translation.language.code }

raise 'incomplete password recovery templates' unless %w[cs en].all? do |lang|
  recovery.fetch(lang).text_plain.present? && recovery.fetch(lang).text_html.present?
end
raise 'incomplete password change templates' unless %w[cs en].all? do |lang|
  changed.fetch(lang).text_plain.present?
end
```

This check must pass before migrations or an upgraded API process are started.

## Deploy and migrate the API

Keep api1 out of service while the new migrations run. The runtime masks from
the template reconciliation step survive the configuration switch:

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-api-migrate-db.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Result vpsadmin-api-migrate-db.service
```

The migration service must report `Result=success`. From
`vpsadmin-api-shell`, confirm that all five migrations report `up`:

```shell
bundle exec rake db:migrate:status
```

Then return api1 to service and confirm that the API, recovery worker,
authentication cleanup timer, and base exporter timer are active:

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl unmask --runtime vpsadmin-api.service \
    vpsadmin-password-recovery.service \
    vpsadmin-api-auth-tokens.timer \
    vpsadmin-api-auth-tokens.service \
    vpsadmin-api-prometheus-export-base.timer \
    vpsadmin-api-prometheus-export-base.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-api.service vpsadmin-password-recovery.service \
    vpsadmin-api-auth-tokens.timer vpsadmin-api-prometheus-export-base.timer
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl is-active vpsadmin-api.service \
    vpsadmin-password-recovery.service \
    vpsadmin-api-auth-tokens.timer \
    vpsadmin-api-prometheus-export-base.timer
```

Switch api2 only after api1 is healthy, then check both services there as well:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.api2 switch
confctl ssh --yes cz.vpsfree/vpsadmin/int.api2 \
  systemctl is-active vpsadmin-api.service \
    vpsadmin-password-recovery.service \
    vpsadmin-api-auth-tokens.timer
```

After both API hosts run the new revision, run authentication maintenance once
on api1. This immediately reconciles a password-change session if an old api2
process exchanged its OAuth code during the rolling switch:

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-api-auth-tokens.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Result vpsadmin-api-auth-tokens.service
```

The maintenance service must report `Result=success`. Later timer runs are
idempotent and keep the same reconciliation in place.

After both API hosts run the new revision, deploy both WebUI hosts:

```shell
confctl deploy cz.vpsfree/vpsadmin/int.webui1 switch
confctl deploy cz.vpsfree/vpsadmin/int.webui2 switch
```

Finally, deploy the frontend route on the production proxy:

```shell
confctl deploy cz.vpsfree/containers/prg/proxy switch
confctl ssh --yes cz.vpsfree/containers/prg/proxy \
  nginx -T 2>&1 | grep -F 'location /oauth2/password-reset {'
curl --silent --show-error --output /dev/null --write-out '%{http_code}\n' \
  https://auth.vpsfree.cz/oauth2/password-reset
```

The nginx configuration check must print the route. The HTTP request should
then return `404` while the API feature flag is off. Both checks are required:
the status alone cannot distinguish a disabled API route from a missing proxy
location.

Deploy both monitoring hosts after the new API metrics are available:

```shell
confctl deploy cz.vpsfree/containers/prg/int.mon1 switch
confctl deploy cz.vpsfree/containers/prg/int.mon2 switch
```

The `VpsAdminPasswordRecoveryQueueFull` rule has warning severity, so the
existing Alertmanager routing sends it by email without Telegram or SMS. It
fires when the unfinished queue is at its limit or when the queue reached the
limit during the preceding ten minutes.

## Configure OAuth client start URLs

Edit the existing OAuth clients in vpsAdmin. Set **Authorization start URI**,
**Authorization start requires user action**, and **Default client** to these
values:

| Client | Authorization start URI | Requires user action | Default client |
| --- | --- | --- | --- |
| vpsAdmin WebUI | `https://vpsadmin.vpsfree.cz/?page=login&action=login` | No | Yes |
| Czech DokuWiki | `https://kb.vpsfree.cz/start?oauthlogin=generic` | No | No |
| English DokuWiki | `https://kb.vpsfree.org/home?oauthlogin=generic` | No | No |
| Discourse | `https://discourse.vpsfree.cz/auth/oauth2_basic` | Yes | No |

Do not use the OAuth callback URL as the start URI. The start URL must begin a
new authorization request.

Select exactly one default client. It supplies the sign-in destination when a
member opens password recovery directly instead of arriving from an OAuth
client. The default client must have an authorization start URI. Selecting a
new default clears the previous selection atomically.

WebUI and DokuWiki restart authorization immediately. Their vpsAdmin credential
form shows **Password changed.** Discourse normally shows its CSRF-protected
**Continue** page before redirecting to vpsAdmin. Its enabled user-action setting
first shows the password-change confirmation and a button to Discourse. After
the user continues from Discourse, vpsAdmin shows the credential form without
repeating the confirmation.

From `vpsadmin-api-shell`, the following read-only query shows the saved values
for review:

```shell
bundle exec irb -r ./lib/vpsadmin
```

```ruby
Oauth2Client.order(:name).pluck(
  :name,
  :client_id,
  :redirect_uri,
  :authorization_start_uri,
  :authorization_start_requires_user_action,
  :is_default
)
```

Also confirm that `core.auth_url` is `https://auth.vpsfree.cz` and that
`core.logo_url` is a reachable HTTP(S) image. Recovery pages omit an invalid
logo URL rather than loading it.

## Enable and verify recovery

Enable `core.password_recovery_enabled` in vpsAdmin system configuration only
after every preceding check passes. Both recovery workers should remain
active.

Use a controlled account with MFA to verify the complete flow:

1. Start from each OAuth client and open **Forgot your password?**.
2. Submit the account login or primary email and confirm that the neutral
   response is shown.
3. Open the delivered one-hour link, complete TOTP or passkey verification,
   and set a new password.
4. For WebUI and both DokuWiki clients, confirm that the client starts a new
   authorization request. The normal vpsAdmin login fields must be visible with
   **Password changed.** above them.
5. For Discourse, confirm that vpsAdmin first shows the password-change
   confirmation and a button to `discourse.vpsfree.cz`. Follow the button,
   continue from Discourse, and confirm that the normal vpsAdmin login fields
   appear without a repeated password-change confirmation.
6. Confirm receipt of the password-changed security notice and successful
   login with the new password.
7. Open **Edit profile** -> **Password changes** in WebUI. Confirm that the
   recovery is the newest row, its type is **Password recovery**, and it has no
   initiating session. Its detail row must show the test client's IP address,
   PTR, and user agent.

Change the password once from the signed-in profile. Confirm that the next
history row is **Signed-in change**, links to the exact initiating session, and
shows the same IP address, PTR, and user agent as that session. Check the table
at a narrow browser width and confirm that a long user agent wraps vertically
without creating horizontal page overflow.

As an administrator, change a controlled member's password. Confirm that the
member sees the administrator change and its numeric session ID, but cannot
open the protected session details and sees no administrator client details.
Confirm that an administrator can open the same session link, can list password
changes for other users, and sees the stored IP address, PTR, and user agent.

Also force a password reset on a controlled member. Complete one reset through
token login and one through OAuth code exchange. Each required-password-change
row must link to the session created by that exact completion. A password
recovery row must remain sessionless because its later sign-in is a separate
authentication event.

Repeat the request with a controlled account without MFA. Its email should
direct the user to support and must not contain a reset link. The browser must
still show the same neutral response.

Repeat the request with controlled support and administrator accounts. Each
email should direct the user to another administrator and must not contain a
reset link, even when the account has MFA. The browser must still show the same
neutral response. Confirm that a recovery link issued before an account became
privileged is rejected.

Verify factor revocation with another controlled account. Complete the MFA
step, disable the exact TOTP device or passkey that authorized the recovery,
and confirm that the password form can no longer change the password. Disabling
an unrelated factor must leave the recovery usable. Disabling MFA globally
must cancel every active recovery for that account.

Verify OAuth client removal with a controlled client. Stop both recovery
workers, admit a submission for that client, delete the client, and restart the
workers. The queued submission must be finished and scrubbed without sending a
recovery message. Deleting another controlled client after its recovery message
was created must reject the link instead of continuing without client context.

Check the worker logs and queue after testing:

```shell
confctl ssh --parallel --yes 'cz.vpsfree/vpsadmin/int.api*' \
  journalctl --unit vpsadmin-password-recovery.service --since today
```

From `vpsadmin-api-shell`, unfinished submissions should return to zero after
the worker has processed the tests:

```ruby
PasswordRecoverySubmission.where(finished_at: nil).count
```

Run the base exporter on api1 and check the password metrics published through
node_exporter:

```shell
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl start vpsadmin-api-prometheus-export-base.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  curl --silent --show-error http://127.0.0.1:9100/metrics \
  | grep '^vpsadmin_password_'
```

The output must contain the recovery admission counters, unfinished queue
depth and limit, queue-capacity event, and password-change counters. Confirm
that both Prometheus servers have loaded the alert:

```shell
confctl ssh --parallel --yes \
  'cz.vpsfree/containers/prg/int.mon*' \
  curl --silent --show-error http://127.0.0.1:9090/api/v1/rules \
  | grep -F VpsAdminPasswordRecoveryQueueFull
```

## Rollback

Disable `core.password_recovery_enabled` first. Let the workers finish or
discard already admitted submissions, confirm that the unfinished count is
zero, and stop `vpsadmin-password-recovery.service` on both API hosts.

Roll the proxy frontend, both WebUI hosts, and both API hosts back to the
approved preceding configuration. The additive columns and tables can remain
in place; old processes ignore them. Reverting the configuration also restores
the preceding declarative notification-template source. Reconciliation does
not delete templates omitted by that source, so the password recovery and
password-change rows may remain in the database and are harmless to the old
application. Leaving the schema in place is the preferred rollback because
migrating down deletes recovery records and detailed password history, and
removes the authentication generation used by the new application. Aggregate
password event counters remain independent of detailed history while the
schema stays in place.

If the migrations must be reversed, first verify that every API and worker
process runs the old release and that no recovery work remains. Treat the down
migration as destructive and take the normal database backup before running
it.
