# Coordinated workspace deployment on aitherdev

Aitherdev is `cz.vpsfree/machines/aitherdev`, canonically reserved as
`vpsfree:aitherdev` in the consuming workspace catalog. System activation and
workspace application profile selection share that reservation. Keep it during
UI review, feedback, idle periods and repeated deployment.

The generic runtime's
[coordination contract](https://github.com/aither64/dev-workspace/blob/master/docs/coordination.md)
owns admission, approvals, workers, completion and recovery. Its
[operations guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination-operations.md)
owns request formats and first-installation bootstrap. Read both before activation.

## Preparation

Use an initiative configuration feature worktree and its Nix development shell.
Select the exact reviewed published runtime through the existing channel:

```sh
confctl inputs channel set --commit dev-workspace devWorkspace REVISION
```

The role maps to flake input `devWorkspace`. It selects the matching host module
and runtime contract; the system configuration does not install the application.
Preserve the workspace's direct nested runtime override, extension selection and
unrelated inputs. Select the same runtime in the composed workspace lock and run
`bin/check-dev-workspace-deployment --workspace-root PATH --configuration-root PATH`.

Complete source commits, quick checks, independent final review and applicable
longer verification before activation. Preparation builds/copies the exact named
generation outside claims. The confctl adapter performs dry activation under
machine ownership immediately before the no-reboot switch. Agent sessions use
approved `machine_activate` and `profile_activate` jobs with explicit ordering;
they do not run direct confctl deploy around a held reservation.

## Initial installation

For a selected pre-contract runtime, build the reviewed candidate independently
and use its private synchronous bootstrap. Record the exact predecessor profile
token, workspace/session incarnation, user deployment direction and prepared
source/artifacts. Refuse unexplained existing coordination state. The candidate
worker activates the prepared system, then selects the application user profile.
Keep the threadless bootstrap owner/reservation and exact original jobs for retry.
It has no automatic notification destination and creates no agent conversation.

After selection, verify both system/profile identities, runtime composition,
coordinator adoption, portal/router access and Codex/tmux continuity. Confirm
the original reservation still owns aitherdev. Keep rollout revisions, logs and
acceptance evidence in the initiating session's rollout record.

## Review, completion and recovery

Review the deployed interface while the machine stays reserved. Normal managed
sessions can iterate under the same reservation and applicable approval scope.
Other sessions prepare independently and wait for activation ownership. Release
requires exact final integration of every owned feature, integrated deployed
dependencies, settled jobs/deliveries and explicit deployment/review completion.
Deployment authorization does not authorize configuration or application master
integration. Keep development pins on their feature branches until that direction.

For interruption, reconcile the exact original attempt. Check both
`/run/current-system` and `/nix/var/nix/profiles/system`; a successful live switch
can precede failed profile publication. Preserve configured confctl auto-rollback
and retained generation metadata. Unknown effects keep the claim and reservation;
do not activate a different generation or release ownership merely because SSH
or a worker exited.

Application selection is forward-only. Recover the original admitted candidate
or a reviewed compatible successor through the runtime's supported recovery
path. Preserve private journals and roots. A threadless owner uses explicit
`--bootstrap-owner UUID` maintenance of the same active incarnation. There is no
general force release, implicit reboot, session closure or merge authorization.

## Integration driver

After the matching runtime is selected, the workspace integration driver can
prepare dependent merges and system/profile activation from their separate
approvals. The workspace recipe maps channel `dev-workspace`, role `devWorkspace`,
to input `devWorkspace`; it uses `confctl inputs channel set --commit` for exact
feature revisions. Builds and copies stay outside execution claims.

A mechanically refreshed configuration can reuse unchanged runtime checks, but
confctl embeds `self.rev`. Prepare and inspect the artifact from the exact final
configuration commit, even when its Git tree matches an earlier tested tree.
Keep system switch before profile activation and preserve the same reservation.
Use existing reconciliation for uncertain effects; a driver resume does not
authorize replay, rollback, reboot or forced release.
