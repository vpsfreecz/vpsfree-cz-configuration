vpsFree.cz cluster configuration
================================

This repository contains Nix configuration of vpsFree.cz infrastructure, i.e.
vpsAdminOS-powered nodes, machines and related services run in containers.

## Requirements

- [Nix](https://nixos.org/nix/)
- [confctl](https://github.com/vpsfreecz/confctl)

## Usage
First, setup [confctl](https://github.com/vpsfreecz/confctl). For now, `confctl`
and `vpsfree-cz-configuration` should be cloned to adjacent directories.

Clone the repositories:

```bash
git clone https://github.com/vpsfreecz/confctl
git clone https://github.com/vpsfreecz/vpsfree-cz-configuration
```

Change into the configuration directory and run `nix-shell`:

```bash
cd vpsfree-cz-configuration
nix-shell
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
