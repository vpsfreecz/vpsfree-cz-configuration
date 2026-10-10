# Executable confctl extensions

This module owns the netboot and runtime-kernel handlers. It imports the public
`github.com/vpsfreecz/confctl/extension` SDK at the exact version in `go.mod`;
Go module versions and the FD3/4 protocol version 1.0 are independent.

`default.nix { pkgs; configSrc; }` returns three explicit outputs:
`package`, `registry`, and `fixtureRegistryTemplate`. The executable is
`bin/vpsfree-confctl-ext`. The two registry forms share the declarations in
`registry.nix`. The operational registry binds the ten files listed there by
their actual SHA-256 bytes, and the package includes exactly those files and
their ancestor directories. Rebuild deliberately after changing a bound file;
generated inventory, runtime state, and unrelated checkout files are unbound.

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

This package is opt-in. The repository's default shell and production confctl
pin retain their existing Ruby behavior and `scripts/*.rb`. The Go executable
loads only its compiled handlers. Selecting an executable registry does not
load those Ruby scripts or authorize deployment or a default-tool switch.
