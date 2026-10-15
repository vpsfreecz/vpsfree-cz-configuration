# Executable confctl extensions

This module owns the netboot and runtime-kernel handlers. It imports the public
`github.com/vpsfreecz/confctl/extension` SDK at the exact version in `go.mod`;
Go module versions and the FD3/4 protocol version 1.0 are independent.
The module and SDK require Go 1.26 or newer. The configuration shell provides
the caller's Go toolchain.

The package installs this repository's MIT license at
`share/doc/vpsfree-confctl-ext/LICENSE.txt`. The binary includes the
GPL-3.0-only confctl SDK, whose license is installed at
`share/doc/vpsfree-confctl-ext/licenses/confctl/LICENSE.txt`.

`default.nix { pkgs; configSrc; }` returns `package`, `registry`,
`fixtureRegistryTemplate`, `moduleSource`, and `goModuleProxy`. The executable is
`bin/vpsfree-confctl-ext`. The two registry forms share the declarations in
`registry.nix`. The operational registry binds the ten files listed there by
their actual SHA-256 bytes, and the package includes exactly those files and
their ancestor directories. Rebuild deliberately after changing a bound file;
generated inventory, runtime state, and unrelated checkout files are unbound.

`moduleSource` supplies the filtered extension module to configuration hooks.
`goModuleProxy` supplies its dependencies as an immutable file proxy, using a
separate hash from the application's vendored dependencies. After changing the
SDK manifests, rebuild the dependency outputs and the hook tools, then review
and explicitly trust the new hook configuration. Shell entry does not grant
that trust.

The operational registry requires both `CONFCTL_EXTENSION_REGISTRY` (its immutable
JSON path) and `CONFCTL_EXTENSION_ROOT` (the live checkout's `pwd -P`), with the
CLI running in that root. A matching clone can use its own explicit root.
Partial authority, changed bound bytes, and symlinked bound sources fail before
help or execution. The private fixture template has empty bindings and an
`@SITE@` executable placeholder. Only the compatibility driver's existing
candidate preparation binds it to an individual fixture; it is not operational
configuration authority.

`netboot.rediscover` writes inventory-ordered non-carried netboot nodes to
`cluster/netbootable.nix`. `runtime.update` retains manual selection, confirmation,
carried machines at their own targets, and zero matches. `runtime.prepare`
excludes carried machines. Both runtime handlers preserve unselected JSON keys,
display successful `error` sentinels without replacing prior state, remove
selected failed keys, and save after handled host failures. Main table rows
follow inventory order; failure details follow worker completion order.
Invocation cancellation fails before saving. State remains in
`configs/node/kernels.json`, with direct file writes and the existing live-PWD
Nix evaluation contract.

Pure state tests and public-SDK protocol tests live in `internal/site`:

```sh
cd extensions
go test ./...
go vet ./...
go test -race ./internal/site
```

The protocol tests run the actual handlers through SDK `Serve` over inherited
FD3/4, with finite fake services. Core-owned executable conformance and
compatibility fixtures separately check the real supervisor and SSH boundary.
The site module imports no private core packages.

The default configuration shell and its `confctl-go` alias load the operational
registry alongside the normal packaged Go CLI. They retain the caller's Go and
hook toolchain. The `service-ruby` shell provides Ruby tools for the existing
service Gemfiles and scripts. The Go CLI loads compiled handlers; it does not
evaluate those Ruby scripts.

Build the matching CLI, site executable and registry with:

```sh
nix build .#confctl .#vpsfree-confctl-ext .#confctl-extension-registry
```

After changing a bound file, rebuild and re-enter `nix develop` to select the
matching registry. When SDK manifests change, also rebuild and review the hook
configuration before explicitly trusting it again. Use the
[core hook procedure](https://github.com/vpsfreecz/confctl/blob/9a66641eb45e5b518232b5b6c8eca1b67311eeb3/docs/development-hooks.md)
for installation and restore; shared or linked-worktree hooks require their own
coordinated transition.

For software recovery, select a retained CLI, site source, package and registry
as one matching set. Keep unrelated fleet channel pins unchanged. Reverting
software does not undo completed writes to `kernels.json` or
`cluster/netbootable.nix`.
