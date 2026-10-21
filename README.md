vpsFree.cz cluster configuration
================================

This repository contains Nix configuration of vpsFree.cz infrastructure, i.e.
vpsAdminOS-powered nodes, machines and related services run in containers.

## Requirements

- [Nix](https://nixos.org/nix/)
- [confctl](https://github.com/vpsfreecz/confctl)

## Development environment

Enter the development environment:

```bash
nix develop
```

The shell provides `confctl` from the pinned flake input (see `flake.lock`) and
installs the repository's Ruby gems into `./.gems`. It adds confctl's packaged
manuals to `MANPATH`, so `man confctl` works.

## Common tasks

List machines:

```bash
confctl ls
```

Build a machine:

```bash
confctl build <machine>
```

Update flake inputs:

```bash
confctl inputs ls
confctl inputs channel ls
confctl inputs channel update --commit '{production,staging}' vpsadminos
```

Hosts can be built and deployed using `confctl`, see
[confctl](https://github.com/vpsfreecz/confctl) or `man confctl` for more
information.

See [confctl site migration](docs/operations/confctl-site-migration.md) for the
runtime-kernel and netboot settings, compatible tool pin and rollback procedure.

## Examples

```bash
# List available hosts
confctl ls

# Build all hosts
confctl build

# Build selected hosts
confctl build "cz.vpsfree/nodes/stg/*"

# Deploy all hosts
confctl deploy

# Try to deploy configuration of selected hosts
confctl deploy "cz.vpsfree/nodes/stg/*" dry-activate
```

## vpsAdmin configuration

See [API configuration and abuse notice processing](configs/vpsadmin/api/README.md).

## Aitherdev operations

See [disk cleanup and retention](docs/operations/aitherdev-disk-retention.md) for
Nix profile/test retention, coordination collection, and rollout/recovery.
