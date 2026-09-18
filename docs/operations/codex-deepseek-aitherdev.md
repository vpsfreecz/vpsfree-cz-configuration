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
