# Log reader access

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

## Historical permissions

Configuration activation does not rewrite historical metadata. Before enabling
routine reader use, an authorized operator must inspect the existing readers and
reconcile the selected files. This is a separate operation from deploying the
configuration; the commands below have no automatic activation hook.

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
3. Schedule a brief logging maintenance window. Stop rotation and quiesce input
   with `systemctl stop logrotate.timer logrotate.service` followed by
   `systemctl stop syslog.service syslog.socket`. Remote senders may queue or
   lose messages according to their transport; do not leave ingestion stopped.
   Ensure no other root process rotates or changes the selected tree.

Then, as root on the logger:

```sh
install -d -m 0700 /root/log-reader-recovery
log-reader-reconcile \
  --inventory /root/log-reader-recovery/before.json
```

The inventory is created exclusively with mode `0600`; an existing output file
causes refusal. It records the path, device/inode, owner/group, mode and file kind
for each selected entry. Review it before applying. Keep it on the logger or in
private operator storage, outside this repository.

```sh
log-reader-reconcile --apply /root/log-reader-recovery/before.json
systemctl start syslog.socket syslog.service
systemctl start logrotate.timer
```

Apply rescans the full bounded scope and requires the reviewed metadata and
identities to match before writing. It changes only group/mode, retaining root
ownership and log contents. Reapplying the same inventory after a successful
application is supported when the scope and identities are unchanged. New files,
rotation or other metadata changes require a fresh inventory and review. A
failure before apply writes nothing; a failure during apply can leave some
entries reconciled. Inspect them against the retained inventory before retrying,
and restore ingestion promptly even when reconciliation fails.

## Acceptance, revocation and recovery

After deployment and reconciliation, verify bounded reads from current remote
logs, historical remote logs, `/var/log/messages` and its archives through the
reader account. Observe normal ingestion and exporter health, a newly appearing
host directory, and an ordinary scheduled rotation. Confirm the resulting
files/directories use the expected owner/group/modes. Test destructive denials
only in a disposable fixture; do not probe production by truncating or deleting
logs.

The aitherdev key may also be manually authorized for root on the logger.
Deploying this account does not revoke that grant. After reader acceptance,
the user removes that manual root authorized-key entry personally. The
configuration and reconciliation helper never edit root's authorized keys.

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
current/archive access across rotation. Run the VM and affected-host builds
through the development session's verification watcher after final review.
Disposable tests do not establish production ownership, ACLs or reader lists;
those remain rollout checks.
