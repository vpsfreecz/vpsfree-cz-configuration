# Aitherdev disk retention

Aitherdev runs `nix-store-cleanup.service` daily, with seven days of retention and
at least two generations through the selected profile generation. The existing
pressure timer runs Nix GC above 75% filesystem usage. Both paths share
`/run/lock/nix-store-cleanup.lock`; pressure GC skips a busy cleanup.

The configuration packages `nix-store-cleanup` with its Python/Nix dependencies.
Home Manager links `~/bin/nix-store-cleanup` to that package. Initial activation
moves the old regular executable to `nix-store-cleanup.pre-declarative`, retaining
numbered older backups instead of overwriting them.

## Inspect and apply

```sh
sudo nix-store-cleanup --dry-run --verbose
sudo nix-store-cleanup --apply --gc
systemctl status nix-store-cleanup.service nix-store-gc-on-pressure.service
journalctl -u nix-store-cleanup.service
```

Dry-run is the default. `--days`, `--keep`, `--no-test-roots` and `--verbose` remain
available. Only `--apply --gc` also collects the store. The daemon socket is
selected explicitly regardless of an inherited `NIX_REMOTE`. An incomplete scan
or a changed profile/root stops application before GC.

Standard profile pruning preserves the selected minimum through current, all
newer generations following a rollback, and running/booted system targets.
Workspace package history, clusters, confctl deployments and other live roots
remain under their owning tool's policy. Older removed generations cease to be
rollback choices; ordinary system rebuilds refresh boot entries.

## Local syslog rotation

Rsyslog's local `messages`, `warn`, `mail`, and `dhcpd` files under `/var/log`
rotate daily or when they exceed 100 MiB. The existing logrotate timer checks
hourly, so a burst can take a file beyond that threshold between checks.
Missing and empty files are skipped.

Each file retains 14 numbered archives. Size-triggered rotations can occur
several times a day, so this is an archive count rather than a 14-day guarantee.
Older archives are compressed; the newest remains uncompressed until the next
rotation. Rotation renames the old file, recreates it with its existing owner
and permissions, and sends HUP to the main process of `syslog.service` so rsyslog
reopens its files without a restart.

Inspect the timer, generated configuration path, and service logs with:

```sh
systemctl status logrotate.timer logrotate.service syslog.service
systemctl cat logrotate.service
journalctl -u logrotate.service -u syslog.service
```

An existing oversized file rotates on the next hourly run after activation.
Renaming it preserves its disk usage until a later rotation compresses it or
expires the archive. Activation does not force rotation or truncate logs.
Restoring an older configuration does not restore expired archives.

## Temporary tests

Recognized `/tmp/**/os-test-*` runs are eligible after seven inactive days only
when their result is terminal, their `.lock` is available, and no process uses
the tree. A `.keep` marker in the run or an enclosing temporary directory holds
it. Cleanup removes the whole eligible tree, including writable guest disks;
it does not follow symlinks into other data. Unknown layouts remain untouched.
Unprivileged previews may preserve runs when process inspection is incomplete.

The creator of ad hoc test/benchmark data must retire it explicitly. A dated
filename and absent process alone are not ownership proof. In particular,
active initiatives must identify reusable fixtures and pending evidence before
requesting cleanup. Do not sweep another initiative's temporary directories by
name. Long-lived cluster state and private verification campaigns require exact
ordinary stop/reset before manual retirement.

## Coordination payloads

The user-profile workspace runtime owns its collection policy and command:

```sh
workspace-host coordination gc --dry-run --json --sizes
workspace-host coordination gc --apply --json
# Explicit one-time expiration of legacy unused leases:
workspace-host coordination gc --dry-run --json --expire-unused
```

It releases finished disposable source/target checkouts and dedicated roots when
their final required reference ends, and expires unused preparations after 24
hours. It preserves compact receipts/history and live deployment recovery. Use the
installed `workspace-host coordination guide` for the authoritative contract.
The application is selected through its user profile, independently of system
configuration; configuration only selects the matching host module contract.

## Rollout and recovery

Build the aitherdev configuration, review the helper preview and activate through
the workspace coordinator's exact machine reservation. Verify the compatibility
link, both timers and an applied cleanup result. Measure `df` before/after ordinary
Nix GC; root removal alone does not reclaim store paths.

For a policy fault, stop `nix-store-cleanup.timer` and restore a reviewed
configuration. A software rollback cannot restore deleted test disks or removed
profile generations. Active runs, explicit holds and uncertain recovery data
must survive every sweep. Never remove store directories manually.

The workspace also provides explicit archive maintenance in its source repository
at `bin/compact-session-storage`. Deploy a runtime with archiveRecoveryPolicy 3
before applying it. Use `--recovery-only` to compact completed private checkout
backups without changing tracked archive records. Preview first and retain the
reported reasons for skipped sessions. The script's workspace operations guide
owns arguments, locks and interruption recovery. New archives discard checkout
changes and raw tracking artifacts; committed Git heads and Markdown summaries
remain available.
