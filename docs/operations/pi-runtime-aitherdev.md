# Pi runtime on Aitherdev

Pi needs matching host support and a workspace application package. The
configuration's `dev-workspace` channel, role `devWorkspace`, must select the
same reviewed runtime as the workspace's nested
`vpsfree-dev-workspace/dev-workspace` input. Preserve the existing native Codex
package, providers and session identities. Compare effective per-machine inputs
and package outputs before changing a channel; root lock names and reported
revision labels alone do not establish that identity.

## Host and workspace configuration

`services.dev-workspaces.piRuntime` uses the stable `aither` UID 1000 and state
root `/home/aither/.local/state/dev-workspaces/pi-runtime-host`. It installs the
`workspace-pi-session@` template without starting an instance, the immutable
helper and session entry, and sudo permission for that exact helper. The
wrappers set both `NIX_SSL_CERT_FILE` and `SSL_CERT_FILE` to
`/etc/ssl/certs/ca-certificates.crt` in their sanitized environment.

The `workspace-portal@vpsfree-cz` drop-in sets only
`DEV_WORKSPACES_PI_HOST_STATE_ROOT` and `DEV_WORKSPACES_PI_AUTH_DIR`. It preserves
`ExecStart`. The auth variable names the canonical Pi directory selected by the
owner; configuration does not create or copy credentials. The workspace's
private Codex home and other workspaces retain their own configuration.

A custom Pi endpoint requires the selected application's model and endpoint
configuration. A provider catalog and login alone do not configure that route.

## Installation and trial

Use the repository's declared shell and channel tools to select the reviewed
runtime. After final review, build the system with
`confctl build cz.vpsfree/machines/aitherdev` and build the matching workspace
application separately. A successful application build does not install the
host helper or activate either configuration.

Follow the installed coordination guide for the machine reservation. Use the
normal confctl dry activation and system switch, then select the workspace
application through `workspace-host switch` under the same reservation.

Verify the installed host helper, sudo rule and session entry, and the helper
selected by the newly initialized portal runtime. Check the actual worker's PID,
process start time and both CA variables, portal health, and existing Codex
settings and native identity before the separately authorized Pi UI trial.
Preserve the original Accepted receipts and native history across reconnects and
follow-ups. If an outcome is Unknown, reconcile the original request before
continuing; do not submit it again, click again or create a replacement session.

## Recovery and ownership

Keep retained package generations and the original recovery records. Older
packages may not read Pi state. Recover forward with a compatible corrected
package and the original operation; selecting an old system or application is
not a safe rollback of that state.

An unmerged deployed trial retains its machine reservation until effects are
settled, deployment is verified, and the complete deployed feature lineage is
integrated into approved remote defaults. Session lifecycle actions require
separate authorization.

The selected runtime's `docs/pi-runtime-host.md` defines helper, namespace,
locking, invocation and recovery behavior. Keep exact trial revisions, build
results and activation evidence in the session records.
