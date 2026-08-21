# Deploying vpsAdmin password recovery

This runbook deploys self-service password recovery through the vpsAdmin OAuth
server. Recovery links are sent only for accounts with TOTP or a passkey. The
public form gives the same response for every submitted login or email address.

This is a release-specific runbook. Use the reviewed revisions below for this
rollout only.

## Reviewed revisions

```shell
VPSADMIN_REVISION=00674913d112dd6a4ad3ae87a749f8da383e3aab
MAIL_TEMPLATES_REVISION=2f6c657321e43d39fa1d464bff78048bb5279573
```

The configuration commit for this release pins `vpsadminServices` to the
vpsAdmin revision above. The staging and production Node channels are
unchanged because the feature does not change the vpsAdminOS protocol or Node
software.

Before building, obtain the exact configuration commit approved for rollout
through the normal review process. Set `APPROVED_CONFIGURATION_REVISION` to
that value and verify the checkout and service pin:

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_ROLLOUT
VPSADMIN_REVISION=00674913d112dd6a4ad3ae87a749f8da383e3aab

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.vpsadminServices.locked.rev' flake.lock)" = \
  "$VPSADMIN_REVISION"
```

## Compatibility and ordering

The release adds three migrations:

- `20260818115900 Add authentication generation` adds a defaulted user
  generation used to reject credentials issued concurrently with a password
  change.
- `20260818120000 Add password recovery` adds the recovery queue and state,
  OAuth client start URLs and completion behavior, WebAuthn recovery context,
  and a user email index.
- `20260821120000 Add password event counters` adds aggregate counters and
  timestamps for recovery admission and password changes. The table contains
  fixed event names and no account identifiers.

All three migrations are additive. Old API processes can read the expanded
schema, and a rollback can leave it in place. New and old API processes may
overlap briefly while the feature remains disabled, but update both API hosts
before enabling recovery. That keeps password changes and credential issuance
on the same generation-aware implementation.

The feature flag defaults to off. Install the mail templates before starting
new API code, then keep recovery disabled until the migrations, both API hosts,
the auth frontend, and OAuth client start URLs are in place. No Node update or
reboot is required.

## Build the affected hosts

Build both API hosts, the frontend host, and both Prometheus hosts before the
rollout:

```shell
confctl build cz.vpsfree/vpsadmin/int.api1
confctl build cz.vpsfree/vpsadmin/int.api2
confctl build cz.vpsfree/containers/prg/proxy
confctl build cz.vpsfree/containers/prg/int.mon1
confctl build cz.vpsfree/containers/prg/int.mon2
```

The WebUI hosts do not need to switch for this release. Their existing
configuration already trusts `https://auth.vpsfree.cz` for OAuth responses.

## Install the mail templates

Install the templates before starting either upgraded API. Password-change
notifications are active independently of the recovery feature flag, so a new
API process requires `user_password_changed` from the outset.

Use a clean checkout of `vpsfree-mail-templates` at the reviewed revision:

```shell
MAIL_TEMPLATES_REVISION=2f6c657321e43d39fa1d464bff78048bb5279573

test "$(git rev-parse HEAD)" = "$MAIL_TEMPLATES_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
nix develop
bundle exec rake test API=https://api.vpsfree.cz
bundle exec rake install API=https://api.vpsfree.cz
```

The installer prompts for an API user and password unless they are supplied by
the operator's existing environment. Do not put credentials in this repository
or in a shell history entry.

Confirm that `password_recovery` has Czech and English plain-text and HTML
variants. Confirm that `user_password_changed` has both plain-text languages.
The standard automated-mail footer must match other member-facing templates.

## Deploy and migrate the API

Keep api1 out of service while the new migrations run. The runtime masks
survive the configuration switch:

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
  systemctl start vpsadmin-api-migrate-db.service
confctl ssh --yes cz.vpsfree/vpsadmin/int.api1 \
  systemctl show --property Result vpsadmin-api-migrate-db.service
```

The migration service must report `Result=success`. From
`vpsadmin-api-shell`, confirm that all three migrations report `up`:

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
    vpsadmin-password-recovery.service
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

Edit the existing OAuth clients in vpsAdmin. Set **Authorization start URI**
and **Authorization start requires user action** to these values:

| Client | Authorization start URI | Requires user action |
| --- | --- | --- |
| vpsAdmin WebUI | `https://vpsadmin.vpsfree.cz/?page=login&action=login` | No |
| Czech DokuWiki | `https://kb.vpsfree.cz/start?oauthlogin=generic` | No |
| English DokuWiki | `https://kb.vpsfree.org/home?oauthlogin=generic` | No |
| Discourse | `https://discourse.vpsfree.cz/auth/oauth2_basic` | Yes |

Do not use the OAuth callback URL as the start URI. The start URL must begin a
new authorization request.

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
  :authorization_start_requires_user_action
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

Repeat the request with a controlled account without MFA. Its email should
direct the user to support and must not contain a reset link. The browser must
still show the same neutral response.

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

Roll the proxy frontend and both API hosts back to the approved preceding
configuration. The additive columns and tables can remain in place; old
processes ignore them. Leaving the schema in place is the preferred rollback
because migrating down deletes recovery records and removes the authentication
generation used by the new application.

If the migrations must be reversed, first verify that every API and worker
process runs the old release and that no recovery work remains. Treat the down
migration as destructive and take the normal database backup before running
it.
