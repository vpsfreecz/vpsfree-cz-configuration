# Operations

## Mail

- [mx2 backup mail relay](mx2.md): mail policy, isolated checks, deployment
  prerequisites and queue recovery.
- [mx2: CentOS to NixOS](upgrades/mx2-centos-to-nixos.md): transition and recovery
  requirements for installations with CentOS state.

## Aitherdev

- [Disk cleanup and retention](aitherdev-disk-retention.md): Nix profile and test
  retention, local log rotation, coordination collection and recovery limits.
- [Declarative cleanup adoption](upgrades/aitherdev-declarative-cleanup.md):
  initial activation with a legacy cleanup executable and its recovery backups.

## vpsAdmin API

- [Abuse notice operations](vpsadmin-abuse-notices.md): parser checks, rejected
  entries, reprocessing and rollback limits.
- [API documentation OAuth](vpsadmin-documentation-oauth.md): optional sign-in
  hook, first setup, ordinary upgrades, private files and rollback.
