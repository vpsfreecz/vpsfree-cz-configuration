# Codex providers on aitherdev

Aitherdev supplies the workspace portal with the built-in Codex subscription
and Snajpa's `codex-lb` instance. The catalog is declared in
`cluster/cz.vpsfree/machines/aitherdev/config.nix`; the host module generates
`/etc/dev-workspaces/codex-providers.json`. The initial provider is
`codex-lb`, matching the existing managed threads.

The load balancer uses `http://172.16.106.12:2455/v1` and reads its key from
`/home/aither/.codex/aither-on-snajpa-codex-lb.token`. Keep that file private
and readable by `aither`. Store only its path in configuration. The subscription
uses the retained Codex login. Global config and authentication backups remain
available for unmanaged Codex use.

The [generic provider contract](https://github.com/aither64/dev-workspace/blob/master/docs/codex-providers.md)
owns selection, limits, transition safety and recovery. The portal's info popup
previews each provider separately; its Switch button changes the whole registered
workspace after active work finishes. Additional instances need separate catalog
IDs and token files. Catalog edits do not replace a saved active selection.

## Deploying a change

The workspace catalog identifies `cz.vpsfree/machines/aitherdev` as
`vpsfree:aitherdev`. Follow the
[generic coordination guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination.md)
and [operations and recovery guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination-operations.md).

Publish the tested runtime and select that exact revision through the
`dev-workspace` channel's `devWorkspace` role:

```sh
confctl inputs channel set --commit dev-workspace devWorkspace REVISION
```

Run channel and host commands in the configuration development shell. The role
maps to flake input `devWorkspace`, which selects the matching host module and
runtime contract.

The application comes from the workspace user profile. Select the same runtime
revision in the workspace's nested `vpsfree-dev-workspace/dev-workspace` input,
and verify the composed locks with `bin/check-dev-workspace-deployment`.
Keep the extension, native Codex and unrelated inputs unchanged.

When the host configuration needs updating, build and copy the exact committed
configuration and retain its generation metadata:

```sh
confctl build cz.vpsfree/machines/aitherdev
```

Use ordinary confctl dry activation followed by a no-reboot switch. Preserve
configured confctl auto-rollback. Verify both `/run/current-system` and
`/nix/var/nix/profiles/system`; a live switch can precede failed profile
publication.

When both the system and application need updating, verify system activation
before selecting the application. For application-only changes, use the workspace
profile without system activation. Build and select the composed package through
`workspace-host switch --source PATH`.

Before application selection, check the existing package-transition policy:
active threads and guest processes must not be interrupted. Provider switching
has its own guarded daemon restart and leaves portal and tmux running.
Keep retained system generations, workspace package roots and private journals.
Verify both previews and an idle switch in each direction after rollout.

## Recovery

Check `workspace-host provider status vpsfree-cz`. A waiting request can be
canceled in the popup. For `recovery-required`, run
`workspace-host provider recover vpsfree-cz` and check status again. Do not
delete state, rewrite native history or force a service restart around a refusal.
A terminal restoration notice requires `dev-session sync SLUG --as-is`.

Return to the subscription using the popup selector. Package recovery is
forward-only: select a corrected compatible application package. If the host
catalog needs correction, restore its definitions before retrying recovery.
