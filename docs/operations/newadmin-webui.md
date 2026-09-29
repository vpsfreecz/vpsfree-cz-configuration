# New vpsAdmin WebUI service

`newadmin.vpsfree.cz` is a single React frontend and OAuth BFF on
`cz.vpsfree/vpsadmin/int.vpsadmin-webui1` (VPS 30431,
`172.16.9.170`). `proxy.prg` terminates public TLS and forwards to the private
nginx listener on port 80. The BFF listens only on loopback port 3001. The
legacy UI remains at `vpsadmin.vpsfree.cz`.

## Source and host prerequisites

The `vpsadmin-webui` channel maps to the `vpsadminWebui` flake input. Its
`vpsadmin` input follows the site's `vpsadminServices` pin; the NixOS module and
the matching frontend/BFF packages come from one WebUI revision. Pin a
published, reviewed revision with `confctl inputs channel set --commit
vpsadmin-webui vpsadmin-webui FULL_COMMIT` inside `nix develop`, then inspect
the generated lock diff. A local `--override-input vpsadminWebui path:...`
supports development evaluation only and is not a deployable lock pin.

The host configuration sets `system.stateVersion = "26.05"` for this newly
provisioned container, allowing development builds. Before first activation,
verify its first-installed state version against the original provisioning
record, along with its architecture, container boot and network settings,
interfaces and routes, current generation, and SSH host identity. The current
NixOS channel or `nixos-version` alone does not establish the first-installed
value. If it differs from `26.05`, stop, correct the host configuration and
rebuild before activation. Inspect ownership of the reserved
`/var/lib/vpsadmin-webui` state path.
The console router uses `https://console.vpsfree.cz`; the public WebUI
`goresheat_url` setting returned `https://goresheat.vpsfree.cz`. Both are iframe
targets, so these two exact HTTPS origins belong in `security.frameOrigins`.
Keep `security.consoleOrigins` empty: the parent UI does not connect directly
to the console origin. The map origins remain in the reusable module.

## Private runtime settings

Before activating the matching credential-capable WebUI revision, the operator
supplies three raw UTF-8 files on the UI VPS:

| File under `/private/vpsadmin-webui/` | Contents |
| --- | --- |
| `oauth-client-id` | Currently deployed newadmin OAuth client ID |
| `oauth-client-secret` | Currently deployed newadmin OAuth client secret |
| `session-secret` | Existing session signing secret |

Inspect `/private` and `/private/vpsadmin-webui` before preparation: both must
be root-owned private directories at mode `0700`, with no unexpected symlink
or mount. Stop on foreign ownership or state rather than automatically changing
an existing directory. Each source must be a regular `root:root` file at mode
`0600`.
Use the same effective values as the currently deployed BFF, especially the
session signing secret; do not rotate it or recreate the session store during
this cutover. The files contain the values alone, not shell assignments,
quotes or `KEY=` prefixes. One terminal LF or CRLF is accepted. Do not put
values in Nix, command arguments, logs or a deployment receipt, and do not
grant the BFF account access to `/private`; systemd loads private copies.
Missing or invalid files stop the new BFF before it listens. Retain the
separately registered nondefault OAuth client with callback
`https://newadmin.vpsfree.cz/oauth/callback` and refresh-token issuance.
The module supplies all public URLs and `BFF_RUNTIME_MODE=production`.

The module owns user `vpsadmin-webui-bff`, private persistent
`/var/lib/vpsadmin-webui/sessions`, host-only cookie name, loopback BFF and
private static/BFF nginx routes. Keep the signing secret stable across
ordinary upgrades. The edge forwards one canonical Host, HTTPS scheme and
original client IP, and drops alternate forwarding headers. Only the edge is
trusted to supply them. Routed OAuth requests suppress access and error logs
at the TLS edge and private backend, including upstream failures. The separate
HTTP redirect server suppresses both logs while preserving the ACME HTTP-01
challenge and the callback query in its redirect. Other vhosts and non-OAuth
backend routes retain their logs. OAuth-specific nginx errors are deliberately
unavailable; this policy cannot cover malformed requests rejected before a
vhost or location is selected. The edge owns TLS/HSTS; the backend owns static
CSP, while BFF HTML responses keep their response-specific fixed CSP. Port 80
accepts only the edge and local health sources. Monitoring uses node exporter
rather than backend HTTP access.

## Monitoring and recovery

Public probes check `/build-info.json` for schema and a full source SHA and
`/healthz` for `ok`. The certificate warning begins with 14 days remaining.
Host checks cover nginx, BFF unit state, private static content, liveness and
anonymous `/session.json` fields without printing response bodies. Infra
alerts cover an inactive or missing BFF unit series and failed or absent host
scrapes. These checks do not certify interactive login. Confirm OAuth,
recovery, console, locale, and important read-only API paths in a controlled
operator acceptance session after activation.

After activation, inspect the top-level document's Content-Security-Policy
response header. `frame-src` must include the exact console and heatmap origins
above alongside the existing map origin; `connect-src` must not add the console
origin. Open both frames in a controlled authenticated session and confirm that
neither triggers a `frame-src` violation. Record only the blocked origin and
directive when diagnosing a failure, never a session token, frame path or query.

The credential interface is a direct cutover: the new BFF does not read the
old `/private/vpsadmin-webui.env` file or accept its secret variables. Keep
that root-only file solely for rollback to a pre-cutover generation until the
new generation has been verified. Before such a rollback, confirm the old file
is still available to that generation. If it is removed later, restoring that
generation also requires restoring its input first. Prefer correcting prepared
credential files and restarting the new generation when only file loading
failed. Activation and rollback are operator actions, not part of this source
change.

For a bad software generation, restore the recorded paired frontend/BFF and
host generation while retaining compatible live sessions and the signing
secret. Do not restore stale refresh-token session files. If an already-open
tab requests an asset missing from the restored immutable package, preserve
unsaved work and reload deliberately. A first-install rollback disables the
new service/vhost while leaving legacy UI, API and auth routes intact. Revert
DNS content only with a new serial higher than the last published serial, and
verify both DNS views and secondary propagation.
