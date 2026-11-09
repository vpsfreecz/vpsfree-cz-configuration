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

This provides `confctl` from the **pinned flake input** (see `flake.lock`), installs Ruby gems into `./.gems`,
and generates man pages into `./.man` so `man confctl` works.

If you prefer `nix-shell`, `shell.nix` is a compatibility shim:

```bash
nix-shell
```

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

## Documentation

### Configuration

<a id="vpsadmin-configuration"></a>

- [vpsAdmin API configuration](configs/vpsadmin/api/README.md), including abuse
  notice processing and the documentation sign-in hook.

### Operations

<a id="mail-operations"></a>
<a id="aitherdev-operations"></a>

- [Operations index](docs/operations/README.md): mx2 relay checks and queue
  recovery, Aitherdev disk retention, vpsAdmin abuse notices and API documentation
  OAuth setup and recovery.
