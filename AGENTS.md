# Repository Guidelines

## Project Structure & Module Organization
- `cluster/` holds host and service trees (e.g., `cz.vpsfree/nodes/{stg,prg,...}`) plus module lists; add nodes in matching region/env paths.
- `modules/` provides reusable Nix modules; `profiles/` captures role presets; `configs/` stores shared service fragments; `data/` carries datasets and key lists consumed by modules.
- `packages/` contains custom packages and `overlays/` for nixpkgs tweaks; flake inputs are managed via `confctl inputs`, not manual edits.
- `health-checks/`, `network-config/`, `support/`, `tools/`, and `scripts/` host ops tooling and network plans; `docs/` and `mkdocs.yml` drive user docs.

## Build, Test, and Development Commands
- Enter the dev shell with `nix develop` from the repo root.
- Inventory: `confctl ls`.
- Evaluate without deploy: `confctl build "cz.vpsfree/nodes/stg/*"` (scope as needed).
- Dry-run deploy: `confctl deploy "cz.vpsfree/nodes/stg/*" dry-activate`.
- Update inputs when required: `confctl inputs channel update --commit <channels> <source>`.

## Coding Style & Naming Conventions
- `.editorconfig` enforces UTF-8, LF, and 2-space indents for Nix/Ruby/ERB; trim trailing whitespace.
- Format Nix with `nixfmt` (RFC style); Overcommit hooks run `Nixfmt` and `RuboCop`.
- Ruby scripts target 3.1; lint via `bundle exec rubocop` when touching Ruby files.
- Use hyphenated filenames mirroring services/hosts; mirror attribute names/order seen in neighbors.

## Testing Guidelines
- For node or module changes, run `confctl build <path>` on the nodes you touched.
- For deployments, prefer `confctl deploy <path> dry-activate` to surface runtime issues early.
- When changing Gem-based packages, refresh pins via `nix-shell -p bundix --run "bundix -l"` and reformat generated `gemset.nix`.

## Commit & Pull Request Guidelines
- Commit messages follow `scope: action` (e.g., `inputs: update nixpkgs`, `cluster: remove ...`); use imperative, lower-case verbs.
- Commit messages must explain what is being changed, why it is needed,
  and how it is implemented.
- Wrap commit message lines at 80 characters or fewer.
- Write commit messages using a temporary file passed to `git commit -F`.
- Explain which hosts/services are affected when relevant; link tickets.
- Record validation commands and dry-run results in PRs; add screenshots/logs only when clarifying behavior.

## Security & Configuration Tips
- Do not commit secrets; reference keys from `data/` or GPG-managed content under `gpg/`.
- Keep input bumps isolated from functional changes.
- For network plans or sensitive data, follow patterns in `network-config/` and keep scopes minimal.
