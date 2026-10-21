# Prometheus query access

The Prague HTTPS proxy exposes a dedicated authenticated API at:

- `https://mon1.prg.vpsfree.cz/codex/api/v1`
- `https://mon2.prg.vpsfree.cz/codex/api/v1`

Each address queries its own Prometheus instance. Mon1 retains up to 365 days
or 500 GB; mon2 retains up to 30 days or 60 GB. Actual history depends on ingestion
and the first retention limit reached. Public HTTPS routing needs no private
address mapping or change to aitherdev. Raw port 9090 remains restricted.

The dedicated Basic username is `codex-aitherdev`. Its password is a separately
generated 32-byte random value encoded as 64 hexadecimal characters. Human
credentials remain in `/private/nginx/mon.htpasswd`: they do not authenticate
dedicated routes, and the dedicated credential does not unlock the human UI or
other API routes. This separation applies on both monitors.

## API boundary and limits

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

### Provision or rotate

This is an operator procedure, separate from source builds and deployment.
Run it as `aither` on aitherdev, from a private terminal with shell tracing,
session recording and command-output capture disabled. Verify the proxy SSH host
key first. The proxy needs `python3` and `htpasswd` in the root SSH command's
PATH; `htpasswd` is supplied by its configured Apache package. Prepare any
temporary Python environment separately if needed.

The following example replaces the whole dedicated password file. It generates
the password in memory, passes it over SSH stdin to `htpasswd -i -B -C 8`, and
stages both files in their destination directories before atomic replacement.
It never prints the password or hash. Existing paths must already have the
documented ownership and modes. A failure after the server replacement can leave
the previous client credential invalid; rerun the procedure to recover with a
fresh credential. It does not change the human password file.

```sh
umask 077
python3 - <<'PY'
import grp
import os
from pathlib import Path
import pwd
import secrets
import shlex
import stat
import subprocess
import tempfile

remote = r'''
import grp
import os
from pathlib import Path
import re
import stat
import subprocess
import sys
import tempfile

def check(path, uid, gid, mode, directory):
    s = path.lstat()
    kind = stat.S_ISDIR if directory else stat.S_ISREG
    if not kind(s.st_mode) or (s.st_uid, s.st_gid, stat.S_IMODE(s.st_mode)) != (uid, gid, mode):
        raise RuntimeError("Unexpected credential path metadata: " + str(path))

if os.geteuid() != 0:
    raise RuntimeError("Proxy provisioning requires root")
for ancestor in [Path("/var"), Path("/var/lib")]:
    s = ancestor.lstat()
    if not stat.S_ISDIR(s.st_mode) or s.st_uid != 0 or s.st_mode & 0o022:
        raise RuntimeError("Unexpected server ancestor metadata")
gid = grp.getgrnam("nginx").gr_gid
parent = Path("/var/lib/nginx-auth")
if not parent.exists() and not parent.is_symlink():
    parent.mkdir(mode=0o750)
    os.chown(parent, 0, gid)
check(parent, 0, gid, 0o750, True)
target = parent / "prometheus-codex.htpasswd"
if target.exists() or target.is_symlink():
    check(target, 0, gid, 0o640, False)
password = sys.stdin.readline().rstrip("\n")
if re.fullmatch(r"[0-9a-f]{64}", password) is None:
    raise RuntimeError("Invalid generated password format")
hashed = subprocess.run(
    ["htpasswd", "-niBC", "8", "codex-aitherdev"],
    input=password + "\n", text=True, capture_output=True, check=True,
).stdout.strip() + "\n"
if re.fullmatch(r"codex-aitherdev:\$2[aby]\$08\$[./A-Za-z0-9]{53}\n", hashed) is None:
    raise RuntimeError("Unexpected htpasswd output format")
fd, temporary = tempfile.mkstemp(prefix=".prometheus-", dir=parent)
try:
    with os.fdopen(fd, "w") as output:
        os.fchown(output.fileno(), 0, gid)
        os.fchmod(output.fileno(), 0o640)
        output.write(hashed)
        output.flush()
        os.fsync(output.fileno())
    os.replace(temporary, target)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
'''

uid = pwd.getpwnam("aither").pw_uid
gid = grp.getgrnam("users").gr_gid
if os.geteuid() != uid:
    raise RuntimeError("Run this procedure as aither")
for ancestor in [Path("/home"), Path("/home/aither"), Path("/home/aither/.config")]:
    s = ancestor.lstat()
    owner = 0 if ancestor == Path("/home") else uid
    if not stat.S_ISDIR(s.st_mode) or s.st_uid != owner or s.st_mode & 0o022:
        raise RuntimeError("Unexpected client ancestor metadata")
parent = Path("/home/aither/.config/vpsfree-observability")
if not parent.exists() and not parent.is_symlink():
    parent.mkdir(mode=0o700)
    os.chown(parent, uid, gid)
target = parent / "prometheus.curlrc"
for path, mode, directory in [(parent, 0o700, True), (target, 0o600, False)]:
    if path.exists() or path.is_symlink():
        s = path.lstat()
        kind = stat.S_ISDIR if directory else stat.S_ISREG
        if not kind(s.st_mode) or (s.st_uid, s.st_gid, stat.S_IMODE(s.st_mode)) != (uid, gid, mode):
            raise RuntimeError("Unexpected client credential metadata")
password = secrets.token_hex(32)
client = (
    'user = "codex-aitherdev:' + password + '"\n'
    'basic\nfail\nsilent\nshow-error\nproto = "=https"\n'
    'proto-redir = "=https"\nconnect-timeout = 5\nmax-time = 45\n'
)
fd, temporary = tempfile.mkstemp(prefix=".prometheus-", dir=parent)
try:
    with os.fdopen(fd, "w") as output:
        os.fchown(output.fileno(), uid, gid)
        os.fchmod(output.fileno(), 0o600)
        output.write(client)
        output.flush()
        os.fsync(output.fileno())
    subprocess.run(
        ["ssh", "-T", "root@proxy.prg.vpsfree.cz", "python3 -c " + shlex.quote(remote)],
        input=password + "\n", text=True, check=True,
    )
    os.replace(temporary, target)
finally:
    if os.path.exists(temporary):
        os.unlink(temporary)
PY
```

The password has no automatic expiry. Rotate after suspected disclosure or
when access ownership changes. For ordinary rotation, atomically replace the
hash entry and client config as above. A brief HTTP 401 gap is acceptable.
Nginx reads the runtime password file for each request, so routine file rotation
does not need a reload or restart. If overlap is required, use distinct usernames
and explicitly retire the old one; duplicate entries for one username do not
provide reliable overlap.

To revoke access, atomically replace the dedicated file with an empty regular
file at `root:nginx 0640` in the same directory, or remove the old username entry
while preserving separately approved users. Remove the unused client file.
New requests then fail authentication, including on existing keepalive/HTTP/2
connections; requests already executing are not canceled. Do not use credential
rotation as a substitute for investigating a compromised account.

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

## Verification and recovery

The flake check `prometheus-query-access` evaluates the production vhost policy
and checks nginx syntax using disposable runtime paths. Its `integration`
passthru runs both vhosts against permissive local stubs with synthetic
credentials. It covers GET/form POST routing, query/body preservation,
Authorization removal, method/path/normalization denial, separate human auth,
missing/wrong credentials, body/rate/concurrency limits, and rotation/revocation
on existing HTTP/1.1 and HTTP/2 connections. The local listener explicitly enables
cleartext HTTP/2 (h2c); it does not exercise public TLS or ALPN. Run the longer
integration fixture after independent review, through the workspace verification
watcher:

```sh
nix build .#checks.x86_64-linux.prometheus-query-access
nix build .#checks.x86_64-linux.prometheus-query-access.integration
```

Live acceptance needs separate deployment authorization. Prepare the server
file before activating the proxy configuration. Use bounded reads to verify
both public HTTPS addresses, the expected separate backends, human UI access,
and failure with missing/wrong dedicated credentials. Confirm old/new credential
behavior after rotation without printing either credential or HTTP headers.
Do not run destructive API probes against production. The local fixture does
not certify public TLS, deployed runtime ownership, or live availability.

Configuration rollback removes dedicated API access. Credential file changes
are independent of Nix generations; rolling back Nix does not restore an old
password. Retain the intended runtime files or revoke them explicitly. Do not
roll back by adding this credential to the human password file or opening raw
Prometheus access. Logger access and its separate manual root-key removal are
described in [log reader access](log-reader-access.md).

See the upstream [nginx Basic auth](https://nginx.org/en/docs/http/ngx_http_auth_basic_module.html),
[proxy](https://nginx.org/en/docs/http/ngx_http_proxy_module.html),
[htpasswd](https://httpd.apache.org/docs/2.4/programs/htpasswd.html) and
[curl](https://curl.se/docs/manpage.html) references for the underlying interfaces.
