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

Before the portal first starts with Pi enabled, prepare its owner-managed host
state directory as `aither` (UID 1000, primary group `users`, GID 100). Check
that `/home/aither/.local/state/dev-workspaces` is an existing directory owned
by UID 1000, grants its owner read, write and search access, and resolves to
that exact canonical path. Check the target with `lstat`, which also detects a
dangling symlink. If `pi-runtime-host` is absent, create it with umask `077` and
`mkdir -m 0700 -- /home/aither/.local/state/dev-workspaces/pi-runtime-host`,
without `-p`. Verify that the result is a real directory at that canonical path,
owned by UID 1000 and GID 100 with mode `0700`, before starting the portal.
Stop on an existing entry, a race or any metadata mismatch; do not adopt the
entry or change its owner or permissions as part of this first-use procedure.
The host module installs the helper and service template but does not create
this directory. The helper cannot bootstrap a missing host state root. If the
portal has already refused the missing root during startup, restart only
`workspace-portal@vpsfree-cz.service` after the directory checks pass, then
verify portal and existing Codex access before a trial.

Use the repository's declared shell and channel tools to select the reviewed
runtime. After final review, build the system with
`confctl build cz.vpsfree/machines/aitherdev` and build the matching workspace
application separately. A successful application build does not install the
host helper or activate either configuration.

Follow the installed coordination guide for the machine reservation. Use the
normal confctl dry activation and system switch, then select the workspace
application through `workspace-host switch` under the same reservation.

Check the generated sudo policy in order: the default wheel rule and the site's
wheel rule must precede the exact helper's `NOPASSWD` grant. Sudo uses the last
matching specification, so finding the helper grant alone does not prove
noninteractive access. The site's rule has module order `900`, between the
default wheel rule at `600` and the helper grant at `1000`. Keep ordinary wheel
commands password-protected.

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
