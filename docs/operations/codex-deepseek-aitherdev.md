# DeepSeek Codex on aitherdev

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

To validate a deployed configuration without spending a model request:

```bash
codex-ds --strict-config --help
```

Use one small `codex-ds exec --ephemeral` request for an end-to-end check after
deployment.

## Runtime package and retention

Aitherdev uses `dev-workspace.lib.mkCodexPackage` to assemble its selected
llm-agents Codex output. The system `codex` command and `codex-ds` share that
assembled package. The wrapper uses the DeepSeek key and profile described
above. The workspace application has a separate user-profile installation.

The [generic Codex package contract](https://github.com/aither64/dev-workspace/blob/master/docs/codex-package.md)
owns the runtime layout and dependency rules. Native daemon copies under
`CODEX_HOME` keep Nix store dependencies and are not GC roots. Retained system
generations protect the system package closure; retained workspace Codex roots
protect the workspace package closure. Keep both while their daemon copies may
still be in use. Equal version strings do not establish equal closures.

Before pruning a system generation or workspace Codex root, establish that no
remaining daemon copy needs its dependencies, or retain the exact assembled
output through another GC root. Do not remove retained roots as part of a
package update.

After an update, check the system command and workspace runtime:

```bash
/run/current-system/sw/bin/codex --version
workspace-host status
codex-ds --strict-config --help
```

Also check the native daemon's selected release separately. Its updater can
select a release independently of the Nix package pin; the public command's
version alone does not identify a daemon already installed in `CODEX_HOME`.
Use a private disposable `CODEX_HOME` for package-copy and startup probes,
without production authentication or model requests.

Keep the previous system generation for system recovery. Workspace switches
remain forward-only: retry the supported switch or select a corrected newer
package. Preserve transition journals and Codex roots. Validate old/new state
readers on disposable state before relying on an older Codex for recovery.
