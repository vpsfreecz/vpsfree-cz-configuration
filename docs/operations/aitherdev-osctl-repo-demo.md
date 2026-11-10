# Development image repository on aitherdev

`https://images.aitherdev.int.vpsfree.cz/` serves the optional image repository
demo on one explicitly selected, session-owned development-cluster node. The
dashboard and `/v1/` and `/runs/<key>/v1/` paths share the same origin. Demo data
is synthetic; its verification states do not prove that real image builds passed.

The site module is `cluster/cz.vpsfree/machines/aitherdev/osctl-repo-dev.nix`.
It listens on the existing aitherdev address and private/VPN firewall policy;
it adds no public firewall opening or portal alias. Internal DNS maps the name
to aitherdev. Deploying the DNS change on the internal DNS hosts is separate
from activating aitherdev's nginx configuration.

## Select the backend explicitly

The optional provider addon is disabled in workspace defaults. Enable
`imageRepository` for an explicitly owned cluster and select a node present in
its topology. It uses the selected vpsAdminOS source's `osctl-repo-server`, guest
loopback port **8080**, and persistent dataset `tank/osctl-repo-server-demo` at
`/var/lib/osctl-repo-server-demo`. Native runit owns the guest service. Seed it
only through the explicit `osctl-repo-demo-seed` command on that selected node;
never replace its database with handwritten SQL or wipe it during startup.

The site frontend's sole backend is host loopback port **19485**, configurable
with `services.osctl-repo-dev.backendPort`. This default is an allocation proposal;
availability has not been established by the configuration. Before binding it,
record the exact verified session slug, selected node, port and registered
temporary-service identity. An occupied port is a conflict, not permission to
reuse or stop an unknown process.

After the reviewed package/cluster and activation steps are authorized, run this
foreground command through `dev-session service run` under that verified session:

```sh
vpsadminos-devcluster ssh "$VERIFIED_SLUG" "$SELECTED_NODE" -N \
  -o ExitOnForwardFailure=yes \
  -L "127.0.0.1:$REPO_BACKEND_PORT:127.0.0.1:8080"
```

Keep bridge networking for the cluster. The SSH forward reaches guest loopback;
nginx never discovers a node IP or chooses the latest cluster/session. The shared
hostname remains bound to that recorded backend until an explicit handover.
When it is unavailable, nginx returns an upstream error. There is no production,
portal, static-file or unrelated dashboard fallback.

Nginx forwards the complete path and preserves conditional/range requests and
identity payload bytes. Response and request buffering are disabled, with no
proxy cache. It overwrites `X-Repo-Client-IP` from its socket peer. The guest
server trusts this header only from the loopback peer used by the SSH connection.
Role sockets, private JSONL logs and control operations remain outside HTTP.

## Separate leaf under the existing development CA

The host uses `services.dev-workspaces.tls.caStateDirectory/authority/ca.pem` and
`ca-key.pem`, with the existing `services.dev-workspaces.lockFile`. The script
requires the existing matching CA; it never creates or rotates it. The CA key
stays in private host state and is never a Nix store input or command output.
Browser trust continues to use the normal public development-CA mechanism.

Only the new leaf state is owned by this module:
`/var/lib/osctl-repo-dev/tls/pairs/` and its `current` symlink. Each pair has the
single exact DNS SAN `images.aitherdev.int.vpsfree.cz`, server-auth usage and
CA:FALSE. Chain, hostname/SAN, key correspondence, expiry and file permissions
are checked before selection. A complete pair is selected through one atomic
symlink replacement; existing portal certificates and credentials are untouched.

`osctl-repo-dev-certificate.service` prepares it before nginx starts. The daily
`osctl-repo-dev-certificate-renewal.timer` checks a 90-day leaf and renews within
30 days of expiry, then reloads nginx. Both oneshots have a two-minute limit;
CA-lock acquisition waits at most 30 seconds. Missing/unsafe CA state or an invalid
pair fails explicitly and leaves the previously selected pair available. Repair
the cause through the ordinary host procedure; do not generate a replacement CA.

## Verification and recovery

Before activation, run the focused module evaluation with the configuration's
pinned nixpkgs, the disposable fake-CA test in
`tests/osctl-repo-dev/certificate.py`, and internal-zone validation. These checks
need no live CA, host service, cluster or DNS write. Follow ordinary review,
configuration build/copy and deployment coordination for later activation.

After authorized activation, verify the exact name and trusted certificate,
dashboard HTML/JSON, canonical image/run bytes and hashes, HEAD lengths, ranges
and validators through the frontend. Confirm spoofed requester headers are
overwritten, private requester data is absent from the dashboard, and unavailable
owned forwarding yields an upstream error without another backend. Record actual
closure/source identities and the selected slug/node/port with the rollout.

Rollback restores the previous site/DNS configuration through the normal host
and DNS procedures. Preserve the existing CA, portal and demo dataset. Release
or stop only the explicitly owned tunnel/service when authorized; reverting this
vhost does not authorize deleting a cluster, resetting demo data or closing a
development session. Workspace package changes use their existing compatibility
and recovery procedure, preserving the explicit selected runtime.
