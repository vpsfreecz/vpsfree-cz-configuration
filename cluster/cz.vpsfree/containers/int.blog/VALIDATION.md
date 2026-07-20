# `blog.vpsfree.cz` backend validation

Validation snapshot: 2026-07-20. These results are offline candidate evidence,
not repository-integration, deployment, publication, or cutover evidence.

## Source identity

The candidate runtime modules were evaluated against nixpkgs source
`/nix/store/np2w09kxd4hy2qw4swcnxnm77axim29k-source`, revision
`293d6abedf0478e681a4dfcfcb35b30fc796a32f`.

The exact 74-file runtime allowlist is defined in `README.md`. It contains
2,925,390 bytes and its sorted relative-path `sha256sum` manifest digest is:

`2ad532dfe49145f30f21a3037b3d7dc982c705914da947fce4617b3682c87311`

From the machine directory, reproduce that digest without creating a
manifest file:

```bash
{
  printf '%s\0' \
    module.nix config.nix wordpress.nix recovery-export.nix \
    packages/default.nix packages/vpsfree-policy.php \
    packages/flat-cs_CZ.mo
  find packages/flat -xdev -type f -print0
} | LC_ALL=C sort -z | xargs -0 -r sha256sum -- | sha256sum
```

Reviewed complete source hashes are:

- `module.nix`:
  `c50651c5ffa8ab5eed8c5fda9effc223e9191d0ba46363c9fa70ea33180e20ba`;
- `config.nix`:
  `bc20c8dc2e0ddb9c3013ab5396c8e3ab3f801a81025c2e644f354528bd543e06`;
- `wordpress.nix`:
  `432c398b7fbd0aa72733d727d6fc5433414931d2d2ee630057f03c8ba983ac53`;
- `recovery-export.nix`:
  `0111363c904ecc95c5dbc8b7b03b7e364be2f8adebb1aad903b72b60a18817ef`;
- `packages/default.nix`:
  `5010e662c53b1ea463571a6b3c0596af59ec389cc57c64f2e0f788e2a89cc712`;
  and
- `packages/vpsfree-policy.php`:
  `046bddb40ec12b629150597e27a5bed1081122c90b25c448c3a789ec3c840979`.

Recompute and compare these hashes after copying the source. Any change to an
evaluated runtime input invalidates the corresponding closure and test
evidence below.

## Completed offline evidence

All candidate Nix files parse and pass pinned nixfmt 1.4.0. Direct evaluation
of `module.nix` returns VPS `29942`, `172.16.8.4/32`, and only the reviewed
`monitor`, `vpsadmin`, and `blog-migration` tags.

Three closures of the source-matched blog runtime modules were built:

- rehearsal:
  `/nix/store/xa72i43x9xbhsw1a2qpb8rnm7pv78xm2-nixos-system-blog-candidate-26.05pre-git`;
- production with both timers disabled:
  `/nix/store/q7qd805y6wgwwg93gzr0gbnikvzm49wz-nixos-system-blog-candidate-26.05pre-git`;
- production with production cron, accepted recovery timer, synthetic
  `firstExpectedDate = "2026-07-22"`, and the Akismet host enabled:
  `/nix/store/ml8526p9fkijvf4c90bl2bvis3p4kvip-nixos-system-blog-candidate-26.05pre-git`.

The date above exists only to exercise the offline full-production
configuration. The live transition must pin a newly reviewed future date
after rechecking the managed-snapshot schedule; it must not copy this value.
Expected evaluation failures were observed for production cron in rehearsal
mode and for an accepted timer without `firstExpectedDate`.

A consistent read-only inspection of all three closures established:

- target systemd 260.2 verifies all relevant units in isolated mount
  namespaces, and every nginx configuration passes isolated `nginx -t`;
- rehearsal enables only loopback Mailpit and its sendmail path; staged
  production has no mail and neither WordPress timer is enabled; full
  production has no mail and enables exactly the cron and accepted-export
  timers;
- production cron runs every five minutes, and recovery runs at 00:30
  Europe/Prague with `Persistent=false`, `RandomizedDelaySec=0`, and
  `AccuracySec=1s`;
- the accepted service has `RefuseManualStart`, `TimeoutStartSec=15min`, and no
  `RuntimeMaxSec`; the manual path cannot write an accepted marker;
- recovery core, accepted, and manual executables are identical across all
  three closures; only full production embeds its synthetic first expected
  date, while timer-disabled monitoring remains intentionally absent;
- production contains no Mailpit, msmtp configuration, system-profile
  sendmail binary, or sendmail wrapper, so PHP mail fails closed; and
- MariaDB has `skip-networking=true` in every mode.

Generated and isolated runtime checks also established:

- nginx has one `0.0.0.0:80` listener and no IPv6, TLS, or ACME listener;
- dotfile denial precedes writable-tree PHP denial, which precedes the generic
  PHP handler;
- nginx 1.30.4 contains `http_realip_module`, and FastCGI derives
  `REMOTE_ADDR` from rewritten `$remote_addr`;
- the isolated nginx runtime test passed all expected 403/404 paths, trusted
  IPv4/IPv6 real-IP cases, and untrusted spoof-attribution cases;
- PHP 8.4.23 linted 1,491 regular runtime PHP files plus generated
  `wp-config.php`;
- policy tests passed with and without the exact Akismet allowlist;
- the guarded WP-CLI wrapper rejected all 24 target-override forms and ignored
  hostile environment configuration;
- the firewall evaluates enabled with the iptables backend, no broad TCP
  port/range opening, one synthetic proxy `/32` HTTP rule, no IPv6 HTTP rule,
  and symmetric SMTP-chain cleanup; and
- rehearsal alone adds the noindex response header, while full production
  alone adds `WP_ACCESSIBLE_HOSTS=rest.akismet.com`.

For the offline WP-CLI isolation probe run as root, use `--allow-root cli info`;
an invocation without `--allow-root` is expected to be rejected by WP-CLI and
does not test target isolation.

The pre-integration candidate ran recovery fault injection with the generated
core exporter, accepted wrapper, and health checker, adapted to task-owned
operator-host paths with controlled PATH shims, all under
`/root/ai/tmp/wp-recovery-faults-20260720-YVkmWt`. Its cases passed:

- previous `current` present with post-rename sync failure;
- previous `current` absent with post-publication verification failure;
- failed final stdout publication through `/dev/full`;
- unexpected replacement of the published symlink inode; and
- accepted-wrapper failure after a successful core export.

Every failed accepted run produced zero dated accepted markers. Safe cases
restored the previous pointer state; the unexpected-inode case refused to
overwrite the replacement and reported `current` as non-authoritative. The
wrapper-failure case left a complete core generation but no accepted marker,
and the actual health checker rejected it. The health checker contains no
`current` selector, so only the dated accepted marker can select an accepted
generation. Final review subsequently added pre-publication identity checking
for the previous `current` link and no-follow-style creation, metadata, and
open-identity validation for `export.lock`. Those source changes supersede the
old fault-injection result; rerun the focused publication, replacement, and
lock cases from the current exact-target output before activation.

Theme/package evidence:

- final theme source Nix hash:
  `sha256-MJ0mpnwUtXNgKuhCDZT3DMj+GAbx2naE/VbYb3rRpXU=`;
- the prior offline built-theme hash
  `sha256-emt4yii+2+PBEMUqBwtIPCBvROQLrpzyooJ+Y7erJOU=` predates the final
  repository-style trailing-whitespace normalization and is superseded;
  record the replacement from the current exact-target build;
- injected Bootstrap SHA-256:
  `9ee2fcff6709e4d0d24b09ca0fc56aade12b4961ed9c43fd13b03248bfb57afe`;
- exact three-phase theme reconstruction, JavaScript syntax, PHP syntax, and
  gettext validation passed;
- the recovered global Czech theme catalogue contains 205 translated
  messages; and
- plugin, theme, and language outputs match their source derivations exactly.

## Harness limitations

`eval-harness.nix` supplies RFC 5737 proxy metadata `192.0.2.140`; it does not
import `module.nix`, `config.nix`, repository base or container profiles, real
cluster metadata, generated inventory, or `confctl`. Consequently, the
closures above do not prove repository integration, exact machine selection,
or the real proxy address. The isolated nginx test also cannot prove the
actual proxy overwrites client headers or that traffic reaches the backend
only through the production firewall.

Do not integrate the harness or its two PHP test programs. They remain
scratch-only validation inputs.

## Current repository drift

A read-only build-host recheck on 2026-07-20 found current master at
`4ef31ca84c09392a98fc8979fa4f24d6326a61a9`, a linear 15-commit fast-forward
from the prior `5aa82621` base. The existing migration worktree still contains
the task commit directly on the old base and must not be built or published.
The upstream range has no path or content overlap with the task paths,
generated inventories, proxy files, environments, or profiles, but it changes
`flake.lock` materially. Recreate the task commits on a freshly reviewed
current base and regenerate every integration result.

The current stable nixpkgs pin is
`fd1462031fdee08f65fd0b4c6b64e22239a77870`. Exact source inspection shows
that its default WordPress remains 6.9.4 and its separate versioned package is
7.0; it does not export 7.0.2. The generic derivation still accepts the
reviewed version/hash override, but now uses structured attributes and strict
dependencies. The NixOS WordPress module is byte-identical across the pins.
The blog-local 7.0.2 package remains necessary, while the three closures above
prove only the recorded `293d6abe` source and must not be treated as current
build-host evidence.

The same continuation independently rechecked the candidate boundary: 239
regular files, 38 directories, no links or special entries, exactly 74 runtime
files, two documentation files, three excluded root harness/test files, and
160 excluded provenance files. Runtime count, byte total, manifest digest, and
all recorded source hashes match. A bounded secret and host-literal scan found
no credential or forbidden runtime literal.

The first current-repository `confctl rediscover` evaluation then exposed one
cluster-metadata type mismatch that the offline harness could not see because
it deliberately did not import `module.nix`: both `ExecMainStatus` health-check
values were integers, while the pinned confctl schema requires strings. They
are now the semantically equivalent string `"0"`. No NixOS runtime module or
package source changed; the candidate manifest and `module.nix` identities
above include this integration correction. The repository review also removed
seven trailing-whitespace findings from the packaged theme. Those edits are
non-semantic, and the final manifest, byte total, and theme source hash above
include them; current exact-target build evidence replaces the superseded
offline built-theme hash.

The first exact `confctl test-connection` also proved that the new internal
hostname is intentionally absent from DNS. The machine metadata now sets
`host.target` to the same asserted `172.16.8.4` private address recorded in
`addresses.v4`; this keeps deployment on the verified address without a
global hosts-file or DNS change. The module identity and manifest above include
that metadata-only correction.

Final recovery review also closed two gaps against the runbook: publication
now requires the previous `current` symlink's target and device/inode identity
to remain unchanged, and `export.lock` is noclobber-created, required to be a
real root-owned mode-0600 single-link regular file, opened without truncation,
and matched to the opened descriptor before locking. The manifest and recovery
source identity above include these changes. Their current-source focused
fault-injection rerun remains an activation gate.

## Pending candidate and integration gates

Before the candidate is ready for any activation:

1. Copy only the 74 runtime files plus `README.md` and `VALIDATION.md` into the
   clean build-host worktree, make them visible to Git, and confirm no
   provenance, harness, test, or unrelated file enters the diff.
2. Run `confctl rediscover`; require one sorted `int.blog` addition in
   `cluster/cluster.nix` and no change to `cluster/netbootable.nix`.
3. Resolve the exact selector to one machine, pass `confctl test-connection`,
   and build/dry-activate only `cz.vpsfree/containers/int.blog` by recorded
   named generation.
4. Re-run the focused recovery publication, unexpected-current-replacement,
   lock-path, accepted-wrapper, and health-authority fault cases from the
   current exact-target output.
5. In the actual-target generated nginx and firewall configuration, require
   exactly `set_real_ip_from 172.16.9.140/32`, `real_ip_header X-Real-IP`,
   `real_ip_recursive off`, no trusted `X-Forwarded-For`, and one HTTP accept
   rule from that same `/32`.
6. Through the real proxy canary, prove an injected `X-Real-IP` is overwritten,
   `X-Forwarded-For` cannot alter attribution, PHP/WordPress sees the real
   tester address from IPv4 and a genuine external IPv6 client, and a direct
   unauthorized backend source remains blocked with spoofed headers.
7. Rehearse the full 5.8.13 to 7.0.2 import/upgrade, plugins, custom theme,
   login/comment behavior, mail/HTTP confinement, controlled reboot, upload
   replacement, and accepted-marker restore. Every staging and restored
   uploads tree must contain real `uploads/fonts` with
   `wordpress:nginx` ownership and mode `0750`, represented in the directory
   manifest.

## Pending live authorization and coordination

The execution ledger remains authoritative. At this snapshot the unresolved
live gates include:

- the real `tools/deploy-infra.sh` invocation path, owner, checkout, and exact
  target exclusion/hold;
- authorization for the task-owned restore `SnapshotDownload` lifecycle;
- separate one-time nginx restart authorization for `int.web` and the shared
  proxy, including their rollback restarts and unaffected-vhost checks;
- guarded publication to `origin/master` as
  `Pavel Snajdr <snajpa@snajpa.net>` through GitHub account `snajpa`;
- a genuine external IPv6 validation vantage;
- the remaining legacy credential, session, user-password, and compromised
  Akismet response;
- public cutover timing and the write-enable owner or delegation; and
- the 60-minute `origin/master` write-coordination window before state `M`.

Until the gate for a particular phase is satisfied, do not run a shared-target
build, deploy, reload/restart, push, write freeze, DNS change, or traffic
switch. The VPS is already provisioned as `29942`; do not perform another
`vpsfreectl` mutation.

For recovery and restore decisions, `current` is non-authoritative. Only a
valid dated accepted marker may select its immutable generation.
