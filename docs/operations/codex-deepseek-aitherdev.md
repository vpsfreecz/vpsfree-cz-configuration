# DeepSeek Codex on aitherdev

Use the [aitherdev update skill](../../skills/update-aitherdev-codex/SKILL.md)
for Codex upgrades. It links the runtime and protocol-library update processes;
the coordination workspace owns the combined system/application rollout.

The `codex-ds` command uses DeepSeek's native Responses API through the `ds`
Codex profile. The wrapper reads the API key from:

```text
/home/aither/.codex/deepseek-key
```

The file must be readable only by `aither` (`0600`) and contain the DeepSeek
API key. The key is exported to Codex as `DEEPSEEK_API_KEY`; it is not stored
in the Nix configuration or Codex profile.

The profile and model catalog are installed by the `aitherdev` configuration.
The former localhost Responses proxy and its state directory are removed during
activation.

After deployment, run one small request from a private temporary directory to
validate profile loading and the provider end to end:

```bash
codex-ds --strict-config --ask-for-approval never exec --ephemeral \
  --sandbox read-only --skip-git-repo-check \
  "Reply only CODEX_UPDATE_OK. Do not call tools."
```

`--help` exits before configuration loading and cannot establish profile
compatibility. The request above consumes provider usage.
Authentication uses the provider's `DEEPSEEK_API_KEY` environment variable.
Do not set `forced_login_method` in this profile: it restricts the shared OpenAI
login and can remove an existing ChatGPT credential before provider startup.
Reasoning capabilities use Codex's model information. The removed
`preferred_auth_method` and
`model_supports_reasoning_summaries` settings are invalid in Codex 0.163.0.

## Runtime package and retention

Aitherdev uses `dev-workspace.lib.mkCodexPackage` to assemble its selected
llm-agents Codex output. The system `codex` command and `codex-ds` share that
assembled package. The wrapper uses the DeepSeek key and profile described
above. The workspace application has a separate user-profile installation.

The [generic Codex package contract](https://github.com/aither64/dev-workspace/blob/master/docs/codex-package.md)
owns the runtime layout and dependency rules. The selected llm-agents package
patches fresh daemon installation to execute its immutable Nix-store runtime and
attempts a native GC root. Retained older daemon copies under `CODEX_HOME` still
depend on Nix-store closures and are not themselves GC roots. Retained system
generations protect the system package closure; retained workspace Codex roots
protect the workspace package closure. Keep both while a daemon may need them.
Equal version strings do not establish equal closures.

Before pruning a system generation or workspace Codex root, establish that no
remaining daemon copy needs its dependencies, or retain the exact assembled
output through another GC root. Do not remove retained roots as part of a
package update.

After an update, check the system command and workspace runtime:

```bash
/run/current-system/sw/bin/codex --version
workspace-host status
```

Then run the single provider check above.

Also check the native daemon's selected executable separately. Retained native
state and running daemons can still use a previous selection; the public
command's version alone does not identify what is running. The current patched
store selection does not use upstream release updates.
Use a private disposable `CODEX_HOME` for package-copy and startup probes,
without production authentication or model requests.

Keep the previous system generation for system recovery. Workspace switches
remain forward-only: retry the supported switch or select a corrected newer
package. Preserve transition journals and Codex roots. Validate old/new state
readers on disposable state before relying on an older Codex for recovery.
