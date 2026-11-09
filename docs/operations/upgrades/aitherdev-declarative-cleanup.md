# Aitherdev: declarative cleanup adoption

## Applicability

Use this guide for initial adoption of the packaged cleanup helper when
`~/bin/nix-store-cleanup` is a legacy regular executable, including after restoring
such a home-directory backup. The retirement status of this transition is
unresolved; retain it until the owning maintainer confirms that old state,
backup restoration and rollback no longer need it.

## Initial activation

The configuration packages `nix-store-cleanup` with its Python/Nix dependencies.
Home Manager links `~/bin/nix-store-cleanup` to that package. Initial activation
moves the old regular executable to `nix-store-cleanup.pre-declarative`, retaining
numbered older backups instead of overwriting them. Preserve those backups for
recovery.

Build the aitherdev configuration, review the helper preview and activate through
the workspace coordinator's exact machine reservation. Verify the compatibility
link, both timers and an applied cleanup result. Measure `df` before/after ordinary
Nix GC; root removal alone does not reclaim store paths.

## Recovery and later maintenance

For a policy fault, stop `nix-store-cleanup.timer` and restore a reviewed
configuration. A software rollback cannot restore deleted test disks or removed
profile generations. Active runs, explicit holds and uncertain recovery data
must survive every sweep. Never remove store directories manually.

Use the maintained [disk retention runbook](../aitherdev-disk-retention.md) for
routine inspection, policy and recovery. Archive compaction is a
[separate maintenance procedure](../aitherdev-disk-retention.md#archive-maintenance)
and requires a deployed runtime with archiveRecoveryPolicy 3 before applying it.
