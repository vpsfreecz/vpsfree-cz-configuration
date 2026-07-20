# `blog.vpsfree.cz` NixOS backend

This directory is the machine-local source for the dedicated
`cz.vpsfree/containers/int.blog` WordPress backend. It is a migration
candidate, not deployment or cutover authorization. The controlling runbook
and execution ledger are on the operator host under
`~/ai/docs/projects/vpsfree-cz-configuration/state/`.

The source is intentionally isolated from shared modules, overlays, inputs,
DNS, and proxy configuration. `module.nix` records verified VPS `29942` and
private address `172.16.8.4/32`; `config.nix` starts in disposable rehearsal
mode.

## Runtime integration boundary

The exact runtime-source allowlist is 74 regular files totaling 2,925,486
bytes:

- `module.nix`, `config.nix`, `wordpress.nix`, and `recovery-export.nix`;
- `packages/default.nix`, `packages/vpsfree-policy.php`, and
  `packages/flat-cs_CZ.mo`; and
- all 67 regular files below `packages/flat/`.

A sorted `sha256sum` manifest of those relative paths has SHA-256:

`5e8786f83d39eef241a20983e1364d32ee8bd7276e6bc02613d23c16af9feb49`

`README.md` and `VALIDATION.md` accompany the integration as documentation;
they are not runtime inputs and are not included in that 74-file manifest.
Do not integrate `eval-harness.nix`, `policy-test.php`,
`core-http-policy-test.php`, or `packages/provenance/`. The latter contains
raw archives and duplicate audit phase trees. The final 67-file theme tree
and the concise provenance recorded here and in `VALIDATION.md` are the
runtime/integration artifacts.

## Runtime design

- WordPress 7.0.2, the three reviewed plugins, the custom `flat` theme,
  Bootstrap 3.4.1, and Czech language files are immutable Nix outputs.
- MariaDB accepts only its local Unix socket. Backend TCP/80 is admitted only
  from the metadata-resolved production proxy IPv4 `/32`; there is no backend
  IPv6 HTTP rule, TLS listener, ACME, or broad HTTP firewall opening.
- The proxy must overwrite `X-Real-IP` with its observed client address. The
  backend trusts that header only from the proxy `/32`, does not trust
  `X-Forwarded-For`, and passes nginx's rewritten `$remote_addr` to PHP as
  `REMOTE_ADDR`.
- HTTP WP-Cron and in-application code updates are disabled. Production cron
  is a separately enabled systemd timer. Production has no MTA, sendmail
  wrapper, or Mailpit; rehearsal mail is loopback-only.
- WordPress HTTP egress is blocked by default. The exact
  `rest.akismet.com` HTTPS exception is optional and remains disabled until a
  fresh key and focused rehearsal pass.
- Writable PHP, dotfiles, XML-RPC, trackback, stale backup paths, and archive
  suffixes are denied before the generic PHP location.

## Reviewed phase transitions

Every phase is a separate reviewed commit, exact-target build, recorded named
generation, and dry activation. Activation and publication retain the live
gates in the migration runbook.

1. The checked-in initial state is `mode = "rehearsal"`, with loopback
   Mailpit, `enableProductionCron = false`, and
   `recovery.enableAcceptedTimer = false`. It remains disposable and outside
   both broad update selectors.
2. After import, add the local WordPress health check to cluster metadata only
   after the database, policy state, and denial checks pass.
3. Build the production runtime with `mode = "production"` while production
   cron and the accepted timer remain disabled. This removes Mailpit and the
   sendmail wrapper and is the final-import/read-only candidate.
4. In an independently reviewed transition, enable the accepted recovery
   timer only after rechecking the live managed-snapshot schedule and its
   monitoring consumer, and before relying on the managed restore rehearsal.
   Pin a then-future `recovery.firstExpectedDate` in that transition and add
   the timer and recovery-health checks to cluster metadata.
5. Enable the Akismet host exception only with a fresh non-Git key and accepted
   HTTPS-only focused rehearsal.
6. Enable production cron only after the final `P` route and controlled
   write-enable gate have passed.

## Mutable state and recovery

The persistent application state is the MariaDB database,
`secret-keys.php`, and the uploads tree. `fontsDir` is deliberately nested at
`uploads/fonts`, so every upload import, replacement, and restore staging tree
must create or preserve that real directory as `wordpress:nginx` mode `0750`.
Directory manifests must include `./fonts`; never atomically install an
uploads tree that omits it.

Recovery exports are immutable directories below `generations/`. `current`
is only a convenience pointer to the most recent complete core export. It can
legitimately point at an unaccepted generation after a wrapper failure and is
never restore or backup-health authority. Only the dated marker below
`accepted/YYYY-MM-DD.marker`, after complete validation, names the accepted
generation for restore and health checks. The manual exporter cannot create
or advance that marker.

## Integration gate

The scratch harness does not import `module.nix`, `config.nix`, repository
profiles, cluster metadata, or `confctl`. Before integration can be accepted,
copy only the allowlisted runtime files plus these two documentation files
into the machine directory. Repository integration, inventory generation,
builds, and dry activation are performed as root on `build.vpsfree.cz` from a
clean linked worktree based on `/root/vpsfree-cz-configuration`, inside its
`nix develop` shell. Run `confctl rediscover`, review both generated inventory
files, and build/dry-activate only
`cz.vpsfree/containers/int.blog` from the clean build-host worktree and pinned
flake environment. The actual-target build must resolve the proxy to
`172.16.9.140/32`; see `VALIDATION.md` for the remaining gates.

The integrated task series is rebased onto reviewed master `fa8de8a8` in the
isolated build-host worktree. Its only untracked content is the accounted
flake-shell state below `.bin/` and `.bundle/`; the dirty canonical checkout
and all unrelated work remain excluded. See `VALIDATION.md` for the exact task
commits, generation, and closure evidence. Current stable nixpkgs is
`fd146203`; the recorded offline closures still use the older `293d6abe` pin
and are not repository-integration evidence.
