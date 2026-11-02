# Log reader access

Deploy the logger, run the permission fix below once as root, then connect
from aitherdev as `log-reader`. New logs and rotations get their permissions
automatically; existing logs need this one-time fix.

## Deploy the logger

Run these commands from the root of your `vpsfree-cz-configuration` checkout,
inside `nix develop`.
Before building, record the deployed generation and its matching retained local
build `NAME`; retain that build and closure for rollback:

```sh
confctl generation ls --local --remote 'cz.vpsfree/containers/prg/int.log'
confctl build 'cz.vpsfree/containers/prg/int.log'
confctl generation ls --local 'cz.vpsfree/containers/prg/int.log'
```

Set `LOG_ACCESS_GENERATION` to the new local build name and
`LOG_PREVIOUS_GENERATION` to the recorded prior name. Deploy that exact build:

```sh
confctl deploy --generation "$LOG_ACCESS_GENERATION" \
  'cz.vpsfree/containers/prg/int.log' dry-activate
confctl deploy --generation "$LOG_ACCESS_GENERATION" \
  'cz.vpsfree/containers/prg/int.log' switch
```

Then fix existing log permissions and check reader access below. The
logger and proxy packages can be deployed independently; no monitor or aitherdev
system deployment is needed.

## Fix existing log permissions

Run in Bash on `log.int.prg.vpsfree.cz` as `root`, after deploying the logger.
First account for existing group/ACL readers, review any unusual paths, and
schedule a short logging maintenance window. Preserve required readers through
membership in `log-readers`; see the refusal details below. Senders may queue or
lose messages while ingestion is stopped.

Use a fresh, unused inventory filename for each attempt. The exit/signal traps
attempt both ingestion and timer restart on success, refusal, failure or
interruption. Review the inventory in `less`, press `q` to return, then enter
`apply` to confirm:

```bash
(
  set -eu
  restore_logging() {
    restore_status=$?
    trap - EXIT HUP INT TERM
    systemctl start syslog.socket syslog.service || restore_status=1
    systemctl start logrotate.timer || restore_status=1
    exit "$restore_status"
  }
  trap restore_logging EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM

  systemctl stop logrotate.timer logrotate.service
  systemctl stop syslog.socket syslog.service
  install -d -m 0700 /root/log-reader-recovery
  inventory=/root/log-reader-recovery/before.json
  log-reader-reconcile --inventory "$inventory"
  less "$inventory"
  read -r -p "Review $inventory; type apply to continue: " confirmation
  test "$confirmation" = apply
  log-reader-reconcile --apply "$inventory"
)
```

Directories become `root:log-readers 0750` and log files `root:log-readers 0640`.
The helper preserves log contents and leaves unrelated log trees alone.

## Read logs from aitherdev

The Prague logger provides the `log-reader` SSH account for inspecting collected
logs with ordinary commands such as `grep` and `tail`. Its root-managed public
key is the existing aitherdev machine key. There is no source-address restriction.

```sh
ssh -T log-reader@log.int.prg.vpsfree.cz \
  'tail -n 100 /var/log/remote/cz.vpsfree/nodes/prg/node1/log'
ssh -T log-reader@log.int.prg.vpsfree.cz \
  'grep -F "search text" /var/log/messages'
```

Use the normal SSH identity selection on aitherdev if the machine key is not
selected automatically. Bound searches by host, date or output size where
possible. All selected log contents are readable without redaction.

## Historical permission refusals and recovery

Configuration activation leaves historical metadata unchanged. Reconciliation
is an operator action with no automatic activation hook.

`log-reader-reconcile` handles only `/var/log/remote` and its descendants, plus
`/var/log/messages` and its date-suffixed or numbered archives (optional `.gz`).
It inventories directories and regular files without reading log contents. It
does not change `/var/log` itself, the exporter pipe or unrelated log trees.
The default bounds are 100,000 entries and 32 directory levels. Exceeding either
refuses the operation; choose a larger explicit bound only after inspecting why
the tree exceeds the expected size.

The helper refuses symlinks, special files, hard-linked files, mount points
inside the scope (including bind mounts), foreign filesystems, non-root owners,
groups other than `root`/`log-readers`, extended/default POSIX ACLs, special mode
bits and group/other write permissions. It opens paths relative to directory
descriptors with no symlink following. `/var/log` and its parents must already be
root-owned and protected from group/other writes; `/var/log` must permit reader
traversal. These refusals require inspection rather than a recursive chmod.

Before taking the inventory:

1. Identify every service or operator that needs the old group/ACL/world-read
   access. Preserve required non-root readers with declarative membership in
   `log-readers`, under the usual configuration review process. Broader existing
   access is intentionally removed by the new modes.
2. Inspect any refusal with `stat` and `getfacl -p -- EXACT_PATH`. Save its original
   owner, group, mode and ACL in a private recovery record. Resolve only the
   inspected paths: for example, after preserving an existing reader's access,
   replace its old group with `log-readers` using `chgrp`, or remove a redundant
   ACL with `setfacl -b` (and `setfacl -k` for a default directory ACL). Do not
   remove an ACL or change a group until its readers are accounted for. Unknown
   owners, links, special files or mounts need their own diagnosis.
3. Schedule a brief logging maintenance window and ensure no other root process
   rotates or changes the selected tree. Remote senders may queue or lose messages
   according to their transport. Review the expected scope beforehand so the
   final inventory review can finish promptly.

The inventory is created exclusively with mode `0600`; an existing output file
causes refusal. It records the path, device/inode, owner/group, mode and file kind
for each selected entry. Review it before applying. Keep it on the logger or in
private operator storage, outside this repository.

Apply rescans the full bounded scope and requires the reviewed metadata and
identities to match before writing. It changes only group/mode, retaining root
ownership and log contents. Reapplying the same inventory after a successful
application is supported when the scope and identities are unchanged. New files,
rotation or other metadata changes require a fresh inventory and review. A
failure before apply writes nothing; a failure during apply can leave some
entries reconciled. Inspect them against the retained inventory before retrying,
and restore ingestion promptly even when reconciliation fails. Once ingestion
resumes, take and review a fresh inventory for another attempt. If review takes
too long, interrupt the block and reschedule the maintenance window. After an
uncatchable termination or failed restart, restore service manually:

```sh
systemctl start syslog.socket syslog.service
systemctl start logrotate.timer
```

## Access boundary

The account belongs only to `log-readers`. Remote log directories are owned by
`root:log-readers` with mode `0750`; regular logs and messages archives use
`0640`. The remote RainerScript `omfile` action sets its creation policy explicitly;
legacy defaults apply to the local messages selector. These settings apply to
newly created files and directories and leave existing metadata unchanged.
Logrotate creates replacements as `0640 root log-readers`, retaining the existing
daily/monthly schedules, retention, date suffixes, uncompressed files and rsyslog
HUP. The exporter pipe retains its own group and mode.

The reader cannot directly overwrite, truncate, delete or rename those logs or
change production configuration. It has no sudo, wheel membership, Nix trust or
service-control grant. SSH permits public-key authentication only and disables
PTYs, TCP/Unix-socket/agent/X11 forwarding, tunnels and user rc execution. Only
`/etc/ssh/authorized_keys.d/log-reader` supplies authorized keys; keys in the
writable home cannot override these restrictions.

This is an ordinary unprivileged shell. It can write its home and `/tmp`, run
programs, create sockets, connect outbound and generate ordinary log messages.
It has no resource sandbox or per-session isolation. Other processes using the
same Unix account share its access.

## Roll back the logger configuration

To restore the recorded logger configuration:

```sh
confctl deploy --generation "$LOG_PREVIOUS_GENERATION" \
  'cz.vpsfree/containers/prg/int.log' switch
```

`--generation` selects a retained local build name, not a remote numeric profile
ID. Stop before deployment if the previous deployed configuration has no matching
retained local build. Configuration rollback does not restore historical metadata
or remove a manual root-key grant; follow the separate recovery steps below.

## Acceptance, revocation and recovery

After deployment and reconciliation, verify bounded reads from current remote
logs, historical remote logs, `/var/log/messages` and its archives through the
reader account. Observe normal ingestion and exporter health, a newly appearing
host directory, and an ordinary scheduled rotation. Confirm the resulting
files/directories use the expected owner/group/modes. Test destructive denials
only in a disposable fixture; do not probe production by truncating or deleting
logs.

The aitherdev machine key was installed manually in `/root/.ssh/authorized_keys`
on the logger. Deploying this account does not remove that entry. After reader
acceptance, remove it yourself if it is still present. The configuration and
reconciliation helper never edit root's authorized keys.

Revoke reader access by removing its configured public key and deploying the
change; end already-open sessions separately if immediate revocation is needed.
Reverting configuration does not undo historical group/mode changes. For a
metadata rollback, first disable reader access, quiesce rotation/ingestion, then
restore only reviewed paths whose device/inode still match the saved inventory,
using their recorded owner/group/mode and any separately saved ACLs. Do not apply
old metadata to replacements created by rotation. The helper does not automate
rollback. Retain logs and the exporter pipe; never restore root key access as a
side effect of recovery.

## Disposable verification

The `log-reader-access` flake check evaluates the account, key, log creation and
rotation policy and checks rsyslog/Python syntax. Its `vmTest` attribute runs
the production logger rules with a synthetic public key and exporter consumer:

```sh
nix build .#checks.x86_64-linux.log-reader-access
nix build .#checks.x86_64-linux.log-reader-access.vmTest
```

The VM covers historical reconciliation/refusals, new-host ingestion, exporter
output, SSH restrictions and home-key rejection, protected-file denials, and
current/archive access across rotation.
Disposable tests do not establish production ownership, ACLs or reader lists;
those remain rollout checks.
