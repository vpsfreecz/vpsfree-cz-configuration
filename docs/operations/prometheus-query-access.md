# Prometheus query access

Set the password on the proxy, save it in aither’s private curl config, then
deploy the proxy configuration. Use the same unique random password in both
places. Choose 32 to 64 random letters and digits from your password manager;
this fits bcrypt and needs no escaping in the curl config.

## Set the password on the proxy

Run on `proxy.prg.vpsfree.cz` as `root`. These commands create the dedicated
password file. If it already exists, omit `-c` to preserve its other entries:

```sh
install -d -o root -g nginx -m 0750 /var/lib/nginx-auth
umask 077
htpasswd -c -B -C 8 /var/lib/nginx-auth/prometheus-codex.htpasswd codex-aitherdev
chown root:nginx /var/lib/nginx-auth/prometheus-codex.htpasswd
chmod 0640 /var/lib/nginx-auth/prometheus-codex.htpasswd
```

Enter the password twice when prompted. The proxy already provides `htpasswd`.
This file is separate from the human monitoring password file.

## Save the credential on aitherdev

Run on aitherdev as `aither`. Create the private file before opening your editor
(`vi` below):

```sh
install -d -m 0700 /home/aither/.config/vpsfree-observability
umask 077
touch /home/aither/.config/vpsfree-observability/prometheus.curlrc
chmod 0600 /home/aither/.config/vpsfree-observability/prometheus.curlrc
vi /home/aither/.config/vpsfree-observability/prometheus.curlrc
```

Save this content, replacing `SAME_PASSWORD` with the password entered at the
proxy's prompts:

```text
user = "codex-aitherdev:SAME_PASSWORD"
basic
fail
silent
show-error
proto = "=https"
proto-redir = "=https"
connect-timeout = 5
max-time = 45
```

Keep the password out of Git, Nix, shell commands and chat. Enter it through
`htpasswd` and the editor rather than pasting it into a command line.

## Deploy or roll back the proxy

Provision the server hash and aitherdev curl configuration above before activating
the proxy policy. Run these commands from the root of your
`vpsfree-cz-configuration` checkout, inside `nix develop`.
Before building, record the deployed generation and its matching retained local
build `NAME`; retain that build and closure for rollback:

```sh
confctl generation ls --local --remote 'cz.vpsfree/containers/prg/proxy'
confctl build 'cz.vpsfree/containers/prg/proxy'
confctl generation ls --local 'cz.vpsfree/containers/prg/proxy'
```

Set `PROXY_ACCESS_GENERATION` to the new local build name and
`PROXY_PREVIOUS_GENERATION` to the recorded prior name. Deploy that exact build:

```sh
confctl deploy --generation "$PROXY_ACCESS_GENERATION" \
  'cz.vpsfree/containers/prg/proxy' dry-activate
```

Build and copy the candidate while the running proxy serves traffic. Keep the
running generation for rollback. Before switching, compare the full candidate
with the running system: nginx configuration, packages, activation scripts and
affected services. Validate the candidate nginx configuration. Use a reload when
possible; do not deliberately stop nginx. Abort deployment if it would cause
unexpected service disruption or more than a brief nginx reload or restart.
A reload-capable unit can still be restarted during system activation.

```sh
confctl deploy --generation "$PROXY_ACCESS_GENERATION" \
  'cz.vpsfree/containers/prg/proxy' switch
```

Then perform the bounded HTTPS and human-access checks below. Mon1, mon2 and
aitherdev need no system deployment. The logger account can be deployed
independently.

To restore the recorded proxy configuration:

```sh
confctl deploy --generation "$PROXY_PREVIOUS_GENERATION" \
  'cz.vpsfree/containers/prg/proxy' switch
```

`--generation` selects a retained local build name, not a remote numeric profile
ID. Stop before deployment if the previous deployed configuration has no matching
retained local build. Credential files are independent of configuration
generations; use the separate revocation and recovery guidance below.

## Query from aitherdev

Use `-q` as curl's first option to suppress a global/default curlrc, followed
by the explicit private config and a fixed HTTPS URL:

```sh
curl -q --config /home/aither/.config/vpsfree-observability/prometheus.curlrc \
  --get --data-urlencode 'query=up' --data-urlencode 'timeout=20s' \
  https://mon1.prg.vpsfree.cz/codex/api/v1/query

curl -q --config /home/aither/.config/vpsfree-observability/prometheus.curlrc \
  --data-urlencode 'query=sum(up)' --data-urlencode 'timeout=20s' \
  https://mon2.prg.vpsfree.cz/codex/api/v1/query

curl -q --config /home/aither/.config/vpsfree-observability/prometheus.curlrc \
  --get --data-urlencode 'query=up' \
  --data-urlencode 'start=2026-10-20T12:00:00Z' \
  --data-urlencode 'end=2026-10-20T12:10:00Z' \
  --data-urlencode 'step=60s' --data-urlencode 'timeout=20s' \
  https://mon1.prg.vpsfree.cz/codex/api/v1/query_range
```

Choose a recent interval within the selected monitor's retention for range
queries. Keep credentials out of URLs and command arguments. Do not add `-u`,
`-k`/`--insecure`, redirect following, verbose/trace output, or a global curlrc.
The config enforces HTTPS, normal certificate validation, a 5s connection timeout
and a 45s total client timeout. There is no client wrapper or system deployment.

## Rotate or revoke the credential

To rotate, run on `proxy.prg.vpsfree.cz` as `root`, omitting `-c`:

```sh
umask 077
htpasswd -B -C 8 /var/lib/nginx-auth/prometheus-codex.htpasswd codex-aitherdev
chown root:nginx /var/lib/nginx-auth/prometheus-codex.htpasswd
chmod 0640 /var/lib/nginx-auth/prometheus-codex.htpasswd
```

Then edit the private aitherdev curl config with the same new password. A brief
HTTP 401 gap between updates is acceptable; no nginx reload or restart is needed.
The password has no automatic expiry. Rotate after suspected disclosure or an
access ownership change. If overlap is required, use distinct usernames and
explicitly retire the old one; duplicate entries for one username are unreliable.

To revoke, run on the proxy as root:

```sh
htpasswd -D /var/lib/nginx-auth/prometheus-codex.htpasswd codex-aitherdev
```

Remove the unused aitherdev client file. New requests fail authentication,
including on existing keepalive/HTTP/2 connections; requests already executing
are not canceled. Investigate a compromised account separately.

## Runtime credential files

Provision these outside Git and Nix before activating the query policy:

| Host and file | Owner | Mode | Contents |
| --- | --- | --- | --- |
| Proxy: `/var/lib/nginx-auth` | `root:nginx` | `0750` | Dedicated directory |
| Proxy: `/var/lib/nginx-auth/prometheus-codex.htpasswd` | `root:nginx` | `0640` | One username and bcrypt cost-8 hash |
| Aitherdev: `/home/aither/.config/vpsfree-observability` | `aither:users` | `0700` | Dedicated directory |
| Aitherdev: `/home/aither/.config/vpsfree-observability/prometheus.curlrc` | `aither:users` | `0600` | Basic credential and HTTPS curl defaults |

Only the server pathname appears in Nix. Do not use `basicAuth`, `readFile`,
`writeText`, Home Manager content/source, or a Nix-generated credential file.
Neither plaintext nor the hash belongs in Git, the Nix store, command arguments,
environment variables, shell history, logs or chat. A missing runtime hash file
fails closed. Build and activation do not generate a default credential.

Inspect the paths, mounts and ACLs before provisioning. Stop on unexpected
symlinks, foreign ownership, ACL grants or mounts rather than repairing them
blindly. Leave `/private` permissions and the human password file alone. File
permissions protect against other users; processes and sessions running as
`aither`, and root, can read the client credential.

## Endpoints and API boundary

The Prague HTTPS proxy exposes a dedicated authenticated API at:

- `https://mon1.prg.vpsfree.cz/codex/api/v1`
- `https://mon2.prg.vpsfree.cz/codex/api/v1`

Each address queries its own Prometheus instance. Mon1 retains up to 365 days
or 500 GB; mon2 retains up to 30 days or 60 GB. Actual history depends on ingestion
and the first retention limit reached. Public HTTPS routing needs no private
address mapping or change to aitherdev. Raw port 9090 remains restricted.

The dedicated Basic username is `codex-aitherdev`. Human credentials remain in
`/private/nginx/mon.htpasswd` and do not authenticate the dedicated routes.
The dedicated credential does not unlock the human UI or other API routes.
This separation applies on both monitors.

Paths below are relative to `/codex/api/v1`. Only these exact routes are allowed:

| Paths | Methods |
| --- | --- |
| `/query`, `/query_range`, `/series`, `/labels` | GET, POST |
| `/label/<name>/values` | GET |
| `/metadata`, `/targets`, `/targets/metadata`, `/rules`, `/alerts` | GET |
| `/status/buildinfo`, `/status/runtimeinfo` | GET |

HEAD accompanies GET. Label names use `[a-zA-Z_][a-zA-Z0-9_]*` in a single path
segment. Trailing slashes, encoded path spellings and unlisted paths or methods
are rejected. Query strings and form POST bodies pass through unchanged. Nginx
removes `/codex` and the `Authorization` header before contacting Prometheus.
Admin/TSDB mutation, reload/quit, receivers, remote read, config/flags, debugging,
federation and UI routes are unavailable through this credential.

The new routes share one budget across both vhosts: 2 requests/s with a burst
of 5 and at most 4 active requests. Excess requests receive HTTP 429. The fixed
quota key also counts unauthenticated requests; public clients can exhaust the
quota. Human UI and Grafana requests do not use it. Bodies are limited to 64 KiB,
with a 10s body timeout. Upstream connect/send/read timeouts are 5s/15s/30s.
The read timeout measures inactivity, not total execution time or CPU use.

Use bounded ranges and `timeout=20s` in queries. That timeout is client courtesy,
not an enforced proxy CPU budget. The credential can read all metrics and the
listed operational metadata, without tenant isolation or redaction.

## Verification and recovery

The flake check `prometheus-query-access` evaluates the production vhost policy
and checks nginx syntax using disposable runtime paths. Its `integration`
passthru runs both vhosts against permissive local stubs with synthetic
credentials. It covers GET/form POST routing, query/body preservation,
Authorization removal, method/path/normalization denial, separate human auth,
missing/wrong credentials, body/rate/concurrency limits, and rotation/revocation
on existing HTTP/1.1 and HTTP/2 connections. The local listener explicitly enables
cleartext HTTP/2 (h2c); it does not exercise public TLS or ALPN.

```sh
nix build .#checks.x86_64-linux.prometheus-query-access
nix build .#checks.x86_64-linux.prometheus-query-access.integration
```

After activation, use bounded reads to verify
both public HTTPS addresses, the expected separate backends, human UI access,
and failure with missing/wrong dedicated credentials. Confirm old/new credential
behavior after rotation without printing either credential or HTTP headers.
Do not run destructive API probes against production. The local fixture does
not certify public TLS, deployed runtime ownership, or live availability.

Configuration rollback removes the dedicated API only if the selected generation
lacks those routes. A prior deployed generation may already include them;
explicitly revoke the runtime credential if rollback must also remove access.

Credential files are independent of Nix generations; rolling back Nix does
not restore an old password. Retain the intended runtime files or revoke them explicitly. Do not
roll back by adding this credential to the human password file or opening raw
Prometheus access. Logger access and its separate manual root-key removal are
described in [log reader access](log-reader-access.md).

See the upstream [nginx Basic auth](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html),
[proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html),
[htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) and
[curl](https://curl.se/docs/manpage.html) references for the underlying interfaces.
