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

The default shell provides the Go `confctl` from the pinned flake input, its
manual pages, and the configuration-owned
[executable site handlers](extensions/README.md). `nix develop .#confctl-go`
selects the same shell. Run the CLI from this checkout: the shell binds the site
registry to its source files and sets the checkout's physical path as its root.

The shell also provides Go, nixfmt and the packaged `confctl-hooks` tools.
Entering it does not install or trust Git hooks. Review the
[hook setup and trust procedure](https://github.com/vpsfreecz/confctl/blob/b8a8f4bc8c0e156f284e0009c460270cd5247ceb/docs/development-hooks.md)
before installing a policy.

### Ruby tasks and existing Git hooks

Use the explicit Ruby environment for service Gemfiles and scripts, and for
commits or pushes that invoke the repository's existing Overcommit hooks.
It also provides the normal Go `confctl`:

```bash
nix develop .#service-ruby
```

This provides Ruby 3.4, Bundler, bundix and bundler-audit, with Bundler's local
paths set to `./.gems` and `./.bundle`. In a fresh checkout, install the locked
root bundle inside this shell before Ruby checks or Overcommit operations:

```bash
BUNDLE_FROZEN=true bundle install
```

The normal Go shell does not bootstrap gems or replace an existing hook
installation. Review and install Go hooks through the linked hook procedure
when making that transition.

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

## vpsAdmin configuration

See [API configuration and abuse notice processing](configs/vpsadmin/api/README.md).
