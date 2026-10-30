# OAuth sign-in for vpsFree.cz API documentation

This procedure enables sign-in for the HTML documentation at
`https://api.vpsfree.cz`, served by `int.api1` and `int.api2` through `proxy.prg`.
A dedicated OAuth client lets the documentation show the API descriptions
available to the signed-in user. Its cookie does not authenticate ordinary API,
JSON or OPTIONS requests. Without the private configuration below, documentation
remains anonymous.

Prepare the client and private files before deployment. Activate the proxy
protections before enabling sign-in on either API host.

## Generate the private files

For an existing installation, reuse its dedicated client, JSON and session key.
Check their settings and ownership before proceeding; skip generation and client
creation during an ordinary upgrade.

For first setup, run this block in a private, unrecorded terminal outside the
repository. It creates a private directory, generates the client ID and secret,
writes the JSON configuration and a separate session key, then prints the JSON.
The output contains the client secret; keep it out of tickets, shared transcripts
and Git. If the directory already exists, the block stops without replacing its
files. Inspect an existing or partially prepared directory before continuing.

```bash
(
  set -eu
  umask 077
  mkdir -- "$HOME/vpsadmin-documentation-oauth"
  cd -- "$HOME/vpsadmin-documentation-oauth"
  ruby -rsecurerandom -rjson <<'RUBY'
settings = {
  'client_id' => SecureRandom.hex(16),
  'client_secret' => SecureRandom.hex(32),
  'redirect_uri' => 'https://api.vpsfree.cz/_documentation/oauth/callback',
  'switch_user' => false
}
File.write('client-id', settings.fetch('client_id'))
File.write('client-secret', settings.fetch('client_secret'))
json = JSON.pretty_generate(settings) + "\n"
File.write('documentation-oauth.json', json)
File.binwrite('documentation-session.key', SecureRandom.random_bytes(64))
puts json
RUBY
)
```

The client secret is 64 ASCII characters, within BCrypt's input limit. The
session key is a separate file containing 64 random bytes. Keep that file as
binary data: do not encode, decode or regenerate it separately for each host.
To print the retained JSON again in the same private terminal:

```bash
cat "$HOME/vpsadmin-documentation-oauth/documentation-oauth.json"
```

## Register the client before deployment

Use `vpsfreectl` with an administrator account. Let its normal authentication
flow use saved credentials or prompt for them; keep passwords and tokens out of
command arguments. Client registration uses the existing API and does not
depend on deploying the documentation feature.

```bash
vpsfreectl --api https://api.vpsfree.cz --auth token \
  --token-via header --no-raw-values oauth2_client create -- \
  --name 'vpsFree.cz API documentation' \
  --client-id "@$HOME/vpsadmin-documentation-oauth/client-id" \
  --client-secret "@$HOME/vpsadmin-documentation-oauth/client-secret" \
  --redirect-uri https://api.vpsfree.cz/_documentation/oauth/callback \
  --no-is-default --access-token-lifetime fixed --access-token-seconds 3600 \
  --no-issue-refresh-token --no-allow-single-sign-on
```

The `@file` values load the exact contents of the protected files, so only their
paths appear in the command arguments. The generated ID and secret files have
no trailing newline. `--no-raw-values` keeps file loading enabled.

This creates a dedicated, nondefault confidential client with one-hour access
tokens, no refresh tokens and SSO disabled. Keep the existing default client and
PHP/React credentials unchanged. Scope `all` belongs to the documentation hook,
not the client-create fields.

Retain the returned numeric resource ID and verify the settings with the ordinary
client Show action before deployment. Create and Show do not return the secret;
keep the generated files. If the Create result is uncertain, use the ordinary
client list/show actions to find the retained `client_id` before retrying. Do not
generate a replacement identity or secret to retry an uncertain request.

Check the API's OAuth provider metadata. Its origin comes from
`core.auth_url`, falling back to `core.api_url`; authorize, token and revoke
paths use `/_auth/oauth2/` without an API-version prefix. Browser and API
workers must trust the provider's HTTPS certificate. Do not substitute the
documentation callback origin for the provider origin.

## Install the private API files

Check the effective `vpsadmin.api.stateDirectory`, `user` and `group` in the
reviewed configuration. The normal directory on both API hosts is
`/var/lib/vpsadmin/api/config`, owned by `vpsadmin-api:vpsadmin-api` at mode
`0750`. Install these protected regular files there:

| File | Contents |
| --- | --- |
| `documentation-oauth.json` | The generated client ID, secret, exact callback and `switch_user: false` |
| `documentation-session.key` | The generated 64-byte session key |

Install the same JSON and the same stable session-key file on both hosts for
all workers. Inspect existing ownership, file types and contents privately
before replacement; retain an existing valid key on upgrade. Install both files
atomically with owner `vpsadmin-api:vpsadmin-api` and mode `0600` through the
normal protected deployment route. The `client-id` and `client-secret` helper
files stay in the operator's private directory.

Keep these values out of command arguments, logs, Git and the Nix store. Do not
put the private files in the authored `configs/vpsadmin/api` tree or the
supervisor's persistent configuration directory.

The API setup preserves these regular files and links its runtime
`/run/vpsadmin/api/config` to the persistent directory. The authored `api.rb`
hook is a store symlink, so it resolves private files through
`VpsAdmin::API.root/config`, not through the hook's source directory. The
supervisor shares the authored hook but receives no documentation credentials.
ExceptionMailer remains enabled. Missing OAuth JSON leaves documentation
anonymous. If the JSON exists but is malformed, has invalid fields or refers to
a missing or invalid key, startup fails with an error that omits secret values.

The hook requests scope `all` and limits the documentation session to 3600
seconds. Keep `switch_user` false until a fresh authorization for this client
offers editable account credentials. Disabling SSO is necessary but
does not alone prove that behavior. No `prompt` or `select_account` parameter
is required or added. Keep enough API concurrency for token and revoke calls.

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
rollback. Build and review the proxy and both API configurations before an
operator activates them.

Activate the proxy routing and logging protections before enabling documentation
OAuth on either API host. The production and maintenance API/auth routes go
directly to the existing HAProxy Unix backend, bypassing Varnish request/response
logging. These routes do not use the API metrics endpoint's 60-second Varnish
cache. TLS, ACME, DDNS aliases, maintenance responses, private API binds
and unrelated PHP/React/console routes remain in place.

Verify generated nginx configuration for trusted edge forwarding, access logs
without query strings, headers or bodies, and disabled sensitive error logging
on both HTTPS and HTTP redirects, including maintenance responses. Verify API
HAProxy request logging is disabled. These protections must apply before values
reach the application's callback checks; rejected requests can contain secrets
too. Errors rejected before nginx selects a virtual host are outside these
per-host logging controls.

Then activate the matching API package and hook on both hosts with the prepared
private files. Rolling instances can temporarily show different documentation;
verify the final source, hook, private-file readability and shared key on both
before accepting the rollout. A missing-file anonymous fallback is not proof
that credentialed sign-in was enabled correctly.

## Acceptance and rollback

After deployment, verify the installed package and configuration on both API
hosts, anonymous documentation and logs that omit secrets. Exercise real HTTPS
sign-in, callback, sign-out/revoke and expiry/relogin with a controlled account.
Check account entry and Switch user only if enabled. Development fixtures do
not certify the production provider, CA trust, routing or credentials. Preserve
only results and safe identifiers, never callback queries, cookies or tokens.

For software rollback, restore the preceding API bundle and authored hook
together: an older server cannot load documentation options it does not support.
Retain the client and private files/key for recovery. Keep direct protected
proxy routing while documentation OAuth is enabled. Removing the JSON from
the API runtime configuration makes documentation anonymous but does not revoke
already-issued tokens; revocation is a separate normal operator action.
This configuration introduces no database migration or coordinated node upgrade.
