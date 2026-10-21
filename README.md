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

See [log reader access](docs/operations/log-reader-access.md) for SSH access to
central logs and [Prometheus query access](docs/operations/prometheus-query-access.md)
for the dedicated HTTPS API credential and its provisioning procedure.
