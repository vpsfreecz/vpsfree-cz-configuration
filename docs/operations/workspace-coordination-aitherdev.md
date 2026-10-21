# Coordinated workspace deployment on aitherdev

Aitherdev is `cz.vpsfree/machines/aitherdev`, canonically reserved as
`vpsfree:aitherdev` in the consuming workspace catalog. System activation and
workspace application profile selection share this physical machine. Keep its
reservation during UI review, feedback, idle periods and repeated deployment.

Read the selected runtime's installed guides with
`workspace-host coordination guide`. Its
[resource claim contract](https://github.com/aither64/dev-workspace/blob/master/docs/coordination.md)
and [operations guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination-operations.md)
own request formats, ownership, notifications and recovery. A predecessor without
resource claims retains its installed snapshot-based workflow.

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

Complete source commits, quick checks, independent review and applicable longer
verification before activation. Build and copy the exact named configuration and
application generations outside execution locks when the tools support that
separation. Retain their source revisions, prepared artifacts and recovery roots.
Confctl embeds the configuration revision, so prepare the final committed source
even when its Git tree matches an earlier tested tree.

## Deployments under resource claims

Sessions own commands, hooks, environments, logs and effect verification. The
coordinator records exclusive ownership and notifies waiting sessions. Acquire
`vpsfree:aitherdev` near the first prepared activation using `coordination acquire`
with an empty repositories list and the configured machine in its machines list.
Use the generic claim guide for the exact request format. Wait for `held`; a
queued request owns no resources. Read authoritative status on notification.

Run ordinary confctl dry activation and a no-reboot switch of the prepared system
generation while holding that claim. Verify both `/run/current-system` and
`/nix/var/nix/profiles/system`; a live switch can precede failed profile publication.
Preserve configured confctl auto-rollback and retained generation metadata.

After successful system activation, run ordinary `workspace-host switch --source`
for the composed workspace feature checkout. Pass `DEV_WORKSPACE_CLAIM_ID` with
the held claim UUID and the exact `DEV_SESSION_SLUG`/`DEV_SESSION_WORKSPACE`
identity. Keep the same physical machine claim, without repository claims. Development,
feature publication, build preparation and tests need no repository ownership.
Shared-branch merges use separate brief claims after preparation and approval.
Workspace-host checks ownership
and retains package compatibility, activation journals and forward recovery.
System activation precedes application selection. Deployment approval grants no
reboot authorization.

Verify system/profile identities, runtime composition, portal/router/coordinator
health and Codex/tmux continuity. Read tool diagnostics and verify effects; zero
exit alone does not prove every required hook or intended effect succeeded.
Follow the generic [machine retention rule](https://github.com/aither64/dev-workspace/blob/master/docs/coordination.md#machine-retention)
for every deployed physical machine. Keep aitherdev ownership until its deployed
feature lineage is integrated into approved remote defaults, the user accepts
the resulting UI/behavior on aitherdev and explicitly directs its release.
Review, CI, idle periods, feedback, disconnects, repeated deployment and turn
completion do not authorize release or establish user acceptance.

Keep exact resolved store paths for `/run/current-system`,
`/nix/var/nix/profiles/system`, the selected workspace user profile and package
generation in the initiative's rollout receipt. Bind them to the complete source
and input graph, canonical repository/target and machine aliases, exact deployed
and final feature heads, fresh remote ancestry proofs, and the user's accepted
environment/result and release direction. Refreshed history also needs reviewed
old/new base/head ranges, equivalence and migration evidence. A substantive
successor requires redeployment and renewed user acceptance; a nonancestor
deployed commit must not be described as literally merged.

Before release, inspect authoritative status for the exact claim owned by this
session, reconcile the original local/remote operation and verify all retention
conditions. Then use `coordination release` with that claim ID and verify the
resulting state.
The cooperative API does not enforce acceptance or integration evidence. Release
grants no merge approval. Held claims block lifecycle cleanup until explicitly
released. The initiative remains active until its final feature heads are
integrated and all work is complete.

## Predecessor and retained operations

Before selecting a claims runtime, a snapshot-based predecessor admits approved
`machine_activate` and `profile_activate` jobs with explicit ordering under its
own machine reservation. Build/copy preparation stays outside claims; the confctl
adapter dry-activates immediately before the no-reboot switch. Use that supported
predecessor workflow for a transition, with system activation before profile
selection. Ordinary admission and bootstrap ownership restrictions still apply.

Existing jobs, snapshots, integrations, deployment history and reservations remain
legacy operations after package selection. Continue their original IDs and recovery
interfaces. New resource claims cannot release legacy reservations or replace
uncertain jobs. The selected claims runtime refuses new independent automatic
integration runs and prepare/approve/submit workflows; retained runs can resume,
and retained jobs can prepare and approve replacement snapshots for refresh.

Legacy release still requires exact final integration of every owned feature,
integrated deployed dependencies, settled jobs and explicit deployment/review
completion. Keep its original reservation during review and recovery. Informational
notification delivery does not hold otherwise completed work. Legacy archival
automatically releases reservations after cleanup; this implementation behavior
does not authorize archival or bypass the machine retention rule. Failed archives
retain recovery holds.
Revival does not reacquire released machines or resume canceled jobs.

For interrupted legacy execution, reconcile the exact original attempt. Verify
both live-system and system-profile identities, retain confctl auto-rollback and
preserve its generation metadata. Unknown effects keep the claim and reservation.
Do not activate a different generation or release ownership merely because SSH
or a worker exited. Application selection remains forward-only: recover the
original admitted candidate or a reviewed compatible successor through the
supported recovery path. Never edit receipts or manufacture an owner to clear a
refusal. There is no force release or implicit integration authorization.

## Initial installation

For a selected pre-contract runtime, the reviewed candidate's bounded initial
bootstrap binds the predecessor profile token, workspace/session incarnation,
user deployment direction and prepared source/artifacts. It refuses unexplained
existing coordination owners. It is not a general deployment route around an
existing ledger or ordinary owner admission.

The bootstrap activates the prepared system, then selects the application user
profile. It creates no agent conversation. Keep its exact original jobs and
threadless owner/reservation for retry. Retained maintenance uses explicit
`--bootstrap-owner UUID` selection for the same active incarnation. Its original
recovery and legacy completion requirements remain in force.

## Agent continuation

A waiting resource request returns immediately. Continue independent work or end
the turn while waiting. The coordinator grants the request and notifies its retained
conversation without running commands. Read claim-status before acting on a notice;
old notices do not restore released ownership or supply deployment/merge approval.

For retained integration runs, background continuation verifies the retained
managed lead. An external conversation supervises foreground continuation or
explicitly hands responsibility to that lead. The
[agent pickup contract](https://github.com/aither64/dev-workspace/blob/master/docs/integration.md#agent-pickup)
owns acknowledgement and reminders. A delivered notice alone does not establish
pickup, waive live-state proof or release machine ownership.

Deployment authorization does not authorize configuration or application master
integration. Keep development pins on their feature branches until that direction.
Keep exact rollout revisions, logs and acceptance evidence in the initiative's
rollout record, outside this configuration repository.
