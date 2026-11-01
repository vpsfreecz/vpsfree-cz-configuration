# OAuth sign-in for vpsFree.cz API documentation

This procedure enables sign-in for the HTML documentation at
`https://api.vpsfree.cz`, served by `api1.int.vpsfree.cz` (`172.16.9.128`) and
`api2.int.vpsfree.cz` (`172.16.9.129`) through `proxy.prg`. A dedicated OAuth
client lets the documentation show the API descriptions available to the
signed-in user. Its cookie does not authenticate ordinary API, JSON or OPTIONS
requests. Without the private configuration below, documentation remains
anonymous.

## Before setup

Before enabling this setup, select a published, reviewed HaveAPI release that
supports `switch_user_revoke_params` and a matching vpsAdmin package and site
hook. The hook must pass `switch_user_revoke_params: { 'close_sso' => '1' }` to
`documentation_oauth`, alongside its client, session and switch settings. Deploy the package and hook together; older HaveAPI packages reject the new
option.

For an existing installation, retain its dedicated client, secret, JSON and
binary session key. Verify the settings and ownership against this procedure.
Skip generation and client creation on ordinary upgrades. Reconcile any setting
changes with the existing client and JSON without rotating the secret or key or
creating a second client. Keep the PHP/React credentials and default client
unchanged.

Prepare the private files and register the client before enabling documentation
sign-in. Activate the proxy's persistent-log protections and the matching API
package and hook before installing the OAuth JSON. The API can run with
anonymous documentation while that file is absent.

## Generate once on API1

For first setup, connect from the operator's local machine in a private,
unrecorded terminal:

```bash
ssh root@api1.int.vpsfree.cz
```

On API1, enter the installed API shell:

```bash
vpsadmin-api-shell
```

The shell runs as `vpsadmin-api` in the installed package's `api/` directory.
Use the packaged Ruby from that initial directory:

```bash
../ruby-env-wrapped/bin/ruby -rsecurerandom -rjson <<'RUBY'
File.umask(0o077)
bootstrap = '/var/lib/vpsadmin/api/documentation-oauth-bootstrap'
Dir.mkdir(bootstrap, 0o700)
Dir.chdir(bootstrap) do
  settings = {
    'client_id' => 'api.vpsfree.cz',
    'client_secret' => SecureRandom.hex(32),
    'redirect_uri' => 'https://api.vpsfree.cz/_documentation/oauth/callback',
    'switch_user' => true
  }
  File.write('client-secret', settings.fetch('client_secret'))
  File.binwrite('documentation-session.key', SecureRandom.random_bytes(64))
  File.write('documentation-oauth.json', JSON.pretty_generate(settings) + "\n")
end
RUBY
```

This creates a new mode-`0700` bootstrap directory and mode-`0600` files without
printing their contents. It refuses an existing directory; inspect an existing
or partially prepared directory before continuing. The client secret is 64 hex
characters with no newline, within BCrypt's input limit. The separate session
key contains 64 raw random bytes. Preserve those exact bytes on both API hosts;
do not encode, decode or generate a key for each host. Exit the API shell and
SSH session to return to the local machine.

## Relay the files through the local machine

For first setup, create a private local directory for the registration secret:

```bash
(
  set -eu
  umask 077
  mkdir -m 0700 -- "$HOME/vpsadmin-documentation-oauth"
  scp root@api1.int.vpsfree.cz:/var/lib/vpsadmin/api/documentation-oauth-bootstrap/client-secret \
    "$HOME/vpsadmin-documentation-oauth/client-secret"
  chmod 0600 -- "$HOME/vpsadmin-documentation-oauth/client-secret"
)
```

Create root-only staging on API2 from the local machine:

```bash
ssh root@api2.int.vpsfree.cz \
  'umask 077; mkdir -m 0700 -- /root/vpsadmin-documentation-oauth'
```

Both directory-creation commands refuse existing directories. Inspect retained
files instead of rerunning first setup over an existing installation. Relay
each named JSON/key file from API1 to API2 through the local machine:

```bash
scp -3 \
  root@api1.int.vpsfree.cz:/var/lib/vpsadmin/api/documentation-oauth-bootstrap/documentation-session.key \
  root@api2.int.vpsfree.cz:/root/vpsadmin-documentation-oauth/documentation-session.key
scp -3 \
  root@api1.int.vpsfree.cz:/var/lib/vpsadmin/api/documentation-oauth-bootstrap/documentation-oauth.json \
  root@api2.int.vpsfree.cz:/root/vpsadmin-documentation-oauth/documentation-oauth.json
```

The local machine must be able to SSH to both hosts; API1 does not need SSH
access to API2. Keep API2's staging directory at `root:root`, mode `0700`, and
its regular files at mode `0600`. Keep the local secret helper private for
registration and recovery. Do not print any of these files or put their contents
in command arguments, logs, tickets, Git or the Nix store.

## Register the client locally

Use the local `vpsfreectl` with an administrator account. Let its normal
authentication use saved credentials or prompt for them; keep passwords and
tokens out of command arguments. Client registration uses the existing API and
does not depend on enabling documentation sign-in.

```bash
vpsfreectl --api https://api.vpsfree.cz --auth token \
  --token-via header --no-raw-values oauth2_client create -- \
  --name 'vpsFree.cz API documentation' \
  --client-id api.vpsfree.cz \
  --client-secret "@$HOME/vpsadmin-documentation-oauth/client-secret" \
  --redirect-uri https://api.vpsfree.cz/_documentation/oauth/callback \
  --no-is-default --access-token-lifetime renewable_auto --access-token-seconds 900 \
  --no-issue-refresh-token --allow-single-sign-on
```

The `@file` value loads the secret from the protected local file, so only its
path appears in the command arguments. `--no-raw-values` keeps file loading
enabled. This creates a dedicated, nondefault confidential client with SSO
enabled, automatically renewable 900-second access tokens and no refresh token.
Scope `all` belongs to the documentation hook, not the client-create fields.

Retain the returned numeric resource ID and verify the settings with the ordinary
client Show action before deployment. Create and Show do not return the secret;
keep the generated files. If the Create result is uncertain, use the ordinary
client list/show actions to find `api.vpsfree.cz` before retrying. Do not generate
a replacement identity or secret to retry an uncertain request.

Check the API's OAuth provider metadata. Its origin comes from
`core.auth_url`, falling back to `core.api_url`; authorize, token and revoke
paths use `/_auth/oauth2/` without an API-version prefix. Browser and API
workers must trust the provider's HTTPS certificate. Do not substitute the
documentation callback origin for the provider origin.

## Prepare and activate the matching configuration

From this configuration repository's `nix develop` shell, pin the exact
published, reviewed vpsAdmin revision through its existing channel:

```shell
confctl inputs channel set --commit vpsadmin vpsadmin APPROVED_CONSUMER_REVISION
```

The channel maps to `vpsadminServices`. Inspect the generated lock and changelog,
including the WebUI and notification-template inputs that follow this source.
Keep their own pins and the staging/production node channels unchanged. Retain
the preceding configuration, channel and system-generation identities for
rollback. Build and review the proxy and both API configurations before
activation. Deploy the matching API package and hook together; an older
HaveAPI package rejects the new hook option.

Activate the proxy logging protections before enabling documentation OAuth on
either API host. The production and maintenance API/auth routes retain the
existing nginx → Varnish → HAProxy path and the API metrics endpoint's
60-second cache. Varnish's runtime shared-memory records are outside the
persistent-log protection; this configuration does not enable a request-log
collector that persists them. TLS, ACME, DDNS aliases, maintenance responses,
private API binds and unrelated PHP/React/console routes remain in place.

The selected vpsAdmin modules provide the reusable logging and forwarding-header
protection. Read the [product logging contract](https://github.com/vpsfreecz/vpsadmin/blob/0f450b89a5e39c203db0bbdfe0df86b386275343/docs/http-log-protection.md)
for the defaults required by this configuration and their TLS/customization
limits. Site configuration retains its routing and additional edge trust rules;
inspect the combined result before activation.

Verify generated nginx configuration for trusted edge forwarding, access logs
without query strings, headers or bodies, and disabled sensitive error logging
on both HTTPS and HTTP redirects, including maintenance responses. Verify API
HAProxy request logging is disabled. These protections must apply before values
reach the application's callback checks; rejected requests can contain secrets
too. Errors rejected before nginx selects a virtual host are outside these
per-host logging controls.

Activate the matching API package and hook on both hosts before installing the
first OAuth JSON. Rolling instances can temporarily show different
documentation. Verify the final package, hook and private-file handling on both;
an anonymous fallback is not proof that credentialed sign-in works.

## Install the private files on API1 and API2

Check the effective `vpsadmin.api.stateDirectory`, `user` and `group` in the
reviewed configuration. On both hosts, the normal persistent directory is
`/var/lib/vpsadmin/api/config`, owned by `vpsadmin-api:vpsadmin-api`, mode `0750`.
Inspect its ownership and file types before installation. The JSON and key must
be regular files with that owner/group and mode `0600`. Keep them out of the
authored `configs/vpsadmin/api` tree and the supervisor's configuration directory.

For first setup, connect to API1 as root and select its bootstrap directory:

```bash
ssh root@api1.int.vpsfree.cz
```

In that root shell:

```bash
source_dir=/var/lib/vpsadmin/api/documentation-oauth-bootstrap
```

For API2, open a separate root shell from the local machine:

```bash
ssh root@api2.int.vpsfree.cz
```

In the API2 root shell:

```bash
source_dir=/root/vpsadmin-documentation-oauth
```

Run this first-install block in each root shell with its selected `source_dir`.
It refuses existing destination files, including partial staging files. The key
is installed before the JSON can enable sign-in on the next API start:

```bash
(
  set -eu
  config_dir=/var/lib/vpsadmin/api/config
  test -d "$config_dir"
  test ! -L "$config_dir"
  for name in documentation-session.key documentation-oauth.json; do
    test -f "$source_dir/$name"
    test ! -L "$source_dir/$name"
    test ! -e "$config_dir/$name"
    test ! -L "$config_dir/$name"
    test ! -e "$config_dir/.$name.new"
    test ! -L "$config_dir/.$name.new"
  done
  install -o vpsadmin-api -g vpsadmin-api -m 0600 -- \
    "$source_dir/documentation-session.key" "$config_dir/.documentation-session.key.new"
  mv -T -- "$config_dir/.documentation-session.key.new" "$config_dir/documentation-session.key"
  install -o vpsadmin-api -g vpsadmin-api -m 0600 -- \
    "$source_dir/documentation-oauth.json" "$config_dir/.documentation-oauth.json.new"
  mv -T -- "$config_dir/.documentation-oauth.json.new" "$config_dir/documentation-oauth.json"
)
```

Both hosts must use the same JSON and binary session key for all workers. During
an upgrade, preserve existing private contents and the valid key; inspect them
privately instead of running the first-install block. If an interrupted first
installation left a key but no JSON, inspect that state and retain the key
before completing installation.

The API's own preStart setup preserves regular private files and links
`/run/vpsadmin/api/config` to the persistent configuration directory. There is no
separate `vpsadmin-api-setup.service` to run. The authored `api.rb` is a store
symlink and reads private files through `VpsAdmin::API.root/config`. The
supervisor shares the hook but receives no documentation credentials.
ExceptionMailer remains enabled. Missing JSON leaves documentation anonymous;
malformed JSON, invalid fields or a missing/invalid key stop startup with an
error that omits secret values.

## Restart and session behavior

After installing the files and matching software, restart the API and its
password-recovery companion on each host from the local machine:

```bash
ssh root@api1.int.vpsfree.cz \
  systemctl restart vpsadmin-api.service vpsadmin-password-recovery.service
ssh root@api2.int.vpsfree.cz \
  systemctl restart vpsadmin-api.service vpsadmin-password-recovery.service
```

Restarting both units lets systemd apply the companion's Requires/After
ordering. The API runs its setup before starting its workers. Keep enough API
concurrency for token and revoke calls.

The hook requests scope `all` and uses `session_lifetime: 3600` as a ceiling.
At the callback, the cookie's expiry is fixed to the shorter token expiry,
about 900 seconds from sign-in for this client. API activity can renew the access
token but does not extend the documentation cookie. Sign in again when that
cookie expires; this setup uses neither a sliding cookie nor a refresh token.

The JSON enables `switch_user: true`. With the supporting HaveAPI release and
matching consumer hook, Switch user adds `close_sso=1` to token revocation so
the provider closes SSO before the next authorization, as in the legacy PHP
client. Ordinary logout keeps its existing revocation behavior. No `prompt` or
`select_account` parameter is added.

## Acceptance and rollback

After deployment, verify the installed package and hook
on both hosts, private-file readability and the shared key, anonymous
documentation, and logs that omit secrets. Exercise HTTPS sign-in, callback,
ordinary logout, Switch user and expiry/relogin with a controlled account.
Development fixtures and these instructions do not certify the real provider,
CA trust, routing or credentials. Retain only safe identifiers and results,
never callback queries, cookies or tokens.

For software rollback, restore the preceding API bundle and authored hook
together: an older server cannot load documentation options it does not support.
Retain the same client, private files and key for recovery. The preceding pair
also restores its earlier Switch user limitation. Keep the proxy's persistent-log
protections while documentation OAuth is enabled. To disable documentation sign-in, remove `documentation-oauth.json` from both
API hosts, then run the paired API and password-recovery restart documented
above on each host. Running workers retain the OAuth configuration until they
restart. Keep the session key and private recovery material. This does not
revoke already-issued tokens; revocation is a separate normal operator action. This configuration introduces no database
migration or coordinated node upgrade.
