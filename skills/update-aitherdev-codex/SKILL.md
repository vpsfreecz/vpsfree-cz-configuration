---
name: update-aitherdev-codex
description: Update aitherdev's Codex and matching dev-workspace host module through confctl channels, coordinating with the runtime update skill and the workspace-owned application rollout.
---

# Update aitherdev Codex

Read AGENTS.md and docs/operations/codex-deepseek-aitherdev.md. Follow the
[generic coordination guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination.md)
and [operations and recovery guide](https://github.com/aither64/dev-workspace/blob/master/docs/coordination-operations.md).
The consuming coordination workspace owns session identity, cross-project
orchestration and application profile selection. Building or deploying never
supplies master merge approval.

Read skills/update-dev-workspace-codex/SKILL.md from the explicit runtime
checkout or selected devWorkspace source. Its canonical repository is
git@github.com:aither64/dev-workspace.git. Follow that process, including its
codex-web dependency skill, or reuse its exact completed evidence supplied by
the caller. Obtain the published runtime commit and frozen llm-agents revision
before updating this configuration. Do not repeat completed lower-level work.

## Update through channels

Enter nix develop and inspect the current channel-to-input mapping. The
dev-workspace channel's devWorkspace role owns the runtime input; the llm-agents
channel's llm-agents role owns the system Codex input. For a normal published
upstream update use confctl inputs channel update --commit. For exact feature or
frozen revisions use:

```sh
confctl inputs channel set --commit --no-changelog llm-agents llm-agents LLM_REV
confctl inputs channel set --commit dev-workspace devWorkspace RUNTIME_REV
```

Keep generated messages. Inspect effective versions and semantic lock identities,
including expected transitive changes. Preserve unrelated channels. Do not edit
flake.lock manually. System Codex and codex-ds use the same assembled package;
the workspace application remains a separate user-profile installation.

Return the final configuration commit and input identities so the workspace can
select the same runtime and run its composed deployment-contract check. Keep
repeated pin updates consolidated before final review.

## Prepare and deploy only within authorization

Complete quick checks, commits and independent final review before long builds
and integration tests. The parent may coordinate these gates once across the
whole update. Build the exact committed cz.vpsfree/machines/aitherdev source,
retain its artifact identity and inspect the deployment plan. Stop unexpected
local kernel builds under the workspace verification procedure.

Deployment requires existing user direction and the shared vpsfree:aitherdev
coordinator reservation. Prepare/copy outside claims; use approved machine
activation, with dry activation handled by its adapter. Return to the workspace
for the dependent application profile switch. Never activate directly around
another owner's reservation, reboot implicitly or integrate master to deploy.

After activation verify /run/current-system, the system profile, the system Codex
version, actual native daemon selection and codex-ds strict-config startup.
Validate the complete managed DeepSeek profile against the selected config schema
before building. After activation use the operations guide's one small ephemeral
provider request with --strict-config; --help exits before loading configuration.
Keep custom-provider authentication in its provider env_key. Do not force the
shared OpenAI login method for DeepSeek; Codex may log out a conflicting ChatGPT
credential before it selects provider authentication. For source/provider probes,
use an isolated Codex home without copying production login credentials.
Resolve the Home Manager-installed codex-ds wrapper
and verify that it selects the intended assembled package.
Follow the operations guides for provider and application acceptance. Preserve
system generations and native roots. Reconcile uncertain effects on the original
job; establish old/new state compatibility before relying on system downgrade.
Return check/deployment receipts and remaining work to the workspace parent.
