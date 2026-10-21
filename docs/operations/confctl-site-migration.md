# Confctl site migration

The site enables runtime-kernel collection and netboot inventory generation in
`configs/confctl.nix`. Use these settings with a matching confctl input that
provides both typed options and selects the Rust CLI and remote helpers. The
former `scripts/runtime_kernels.rb` and `scripts/discover_netbootable.rb` must
remain absent from the migrated checkout. Keep the site's Gemfile, Overcommit
hooks and Ruby service tooling.

## Runtime kernel state

`confctl runtime-kernels update [machine-pattern]` writes the existing ignored
`configs/node/kernels.json`. The JSON object uses full configuration machine
names as keys and kernel strings as values, without a schema wrapper. Successful
queries replace selected entries; ordinary failed queries delete their selected
entries. Unselected keys survive, including stale names after a rename. The
command still completes after ordinary host failures; invocation or file errors
remain failures.

With `refreshBeforeDeploy = true`, deploy refreshes kernel data for the confirmed,
managed, non-carried vpsAdminOS hosts before generation lookup or build evaluation. It
skips an empty eligible subset and does not repeat the initial confirmation.
The explicit update command also permits selected unmanaged and carried
vpsAdminOS entries. Neither refresh path adds a runnable-target filter.

`configs/node/kernels.nix` continues to read the live checkout's ignored JSON
through `PWD` during impure evaluation. Its manual runtime overrides take
precedence over JSON values, then the default kernel. The site's
`settings.nix.impureEval = true` override and the separate PXE boot-kernel
selection remain unchanged. Keep existing kernel state when switching tools;
both writers and the Nix reader use the same file format.

## Netboot inventory

After `add`, `rename` or `rediscover` replaces `cluster/cluster.nix`, confctl reads
fresh settings and inventory before replacing `cluster/netbootable.nix`. The
generated header and Nix string-list format remain unchanged. Entries follow
inventory order and include netboot-enabled, non-carried machines of either
spin, including unmanaged machines. An empty result produces an empty list.

`lib/netboot-machines.nix` still consumes this list for the build, Brno APU and
Prague APU carriers. Aliases, tags, retention settings, PXE modules and
`configs/node/pxe-only.nix` machine-image JSON remain unchanged. Core changes
survive a later settings, inventory or output failure. When netboot publication
has not completed, the previous list remains. Inspect that partial result before
explicitly running rediscover again.

Git-flake evaluation excludes new untracked files, even during impure
evaluation. After `add` or `rename`, the core edit can therefore succeed while
the netboot update fails to import a new or moved module. Inspect the retained
edits, stage only the intended old/new configuration paths and
`cluster/cluster.nix`, then run `confctl rediscover`. Use `git add -A --` with
explicit old and new paths for a rename. Do not repeat the completed add or
rename. This source-inclusion prerequisite also applied to the Ruby hook;
confctl does not stage files automatically.

## Tool pin and recovery

Switch the confctl tool/module pin, typed settings and removal of both scripts
together. Reenter the site's development shell after selecting the matching
pin so its packaged CLI and manuals agree. The `tools` shell mode continues to
provide the site's independent Ruby tooling. Changing the operator tool does
not itself deploy helper packages or require a simultaneous fleet update.

The confctl input has no site channel mapping. When the exact reviewed Rust
revision is published and selected for this configuration, use the public root
input-set command in a separate pin commit. Preserve its generated changelog
and update only that input and any required transitive lock nodes; do not edit
`flake.lock` by hand.

For rollback, stop using the new writer and restore the matched old confctl
pin, former settings and both Ruby scripts together. Reenter the old shell
before invoking the restored tool. Preserve `configs/node/kernels.json`, the
generated Nix lists and existing generations: old and new readers accept their
formats. If reverting generated remote-helper packages too, restore each old
wrapper with its matching helper JSON, including the old Ruby interpreter
field. Do not combine an old Ruby wrapper with a new JSON record that omits
that field.

Run only one writer version against a checkout at a time. The Rust mutation
lock does not coordinate Ruby writers or external editors. Tool rollback does
not undo completed file updates, restore kernel entries deleted after failed
queries, or revert deployed systems; those effects need separate inspection.
