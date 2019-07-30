vpsFree.cz cluster configuration
================================

This repository contains Nix configuration of vpsFree.cz infrastructure, i.e.
vpsAdminOS-powered nodes, machines and related services run in containers.

## Requirements

- [Nix](https://nixos.org/nix/)

## Usage
Clone this repository:

```bash
git clone https://github.com/vpsfreecz/vpsfree-cz-configuration/
```

Change into its directory and run `nix-shell`:

```bash
cd vpsfree-cz-configuration
nix-shell
```

Hosts can be built and deployed using `confctl`:

```bash
confctl
NAME
    confctl - Manage vpsFree.cz cluster configuration and deployments

SYNOPSIS
    confctl [global options] command [command options] [arguments...]

GLOBAL OPTIONS
    --help - Show this message

COMMANDS
    build  - Build target systems
    deploy - Deploy target systems
    help   - Shows a list of commands or help for one command
    ls     - List configured deployments
    swpins - Manage software pins
```

## Examples

```bash
# List available hosts
confctl ls

# Build all hosts
confctl build

# Build selected hosts
confctl build "*.stg.vpsfree.cz"

# Deploy all hosts
confctl deploy

# Try to deploy configuration of selected hosts
confctl deploy "*.stg.vpsfree.cz" dry-activate
```

## Documentation

This configuration is documented using mkdocs. HTTP server with rendered
documentation can be started using `confctl docs start`.
