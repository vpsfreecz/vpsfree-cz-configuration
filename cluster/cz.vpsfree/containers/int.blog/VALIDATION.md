# `blog.vpsfree.cz` backend validation

Validation snapshot: 2026-07-20. The offline candidate sections below are not
repository-integration, deployment, publication, or cutover evidence. Later
sections explicitly record the current exact-target repository integration.

## Source identity

The candidate runtime modules were evaluated against nixpkgs source
`/nix/store/np2w09kxd4hy2qw4swcnxnm77axim29k-source`, revision
`293d6abedf0478e681a4dfcfcb35b30fc796a32f`.

The exact 74-file runtime allowlist is defined in `README.md`. It contains
2,925,712 bytes and its sorted relative-path `sha256sum` manifest digest is:

`ed08fa0c02b804d45937181a5c33e6bbe33316ae617c677cd834389b9e62b53e`

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
  `b8cc49f754bfe0078a4937514dcccdd06e11941d6a676884f5413d96908983de`;
- `config.nix`:
  `bc20c8dc2e0ddb9c3013ab5396c8e3ab3f801a81025c2e644f354528bd543e06`;
- `wordpress.nix`:
  `432c398b7fbd0aa72733d727d6fc5433414931d2d2ee630057f03c8ba983ac53`;
- `recovery-export.nix`:
  `9839d9c8c75c2050954d6e8a8c997fadf65eb40e90ace1f06c6f9c201b777019`;
- `packages/default.nix`:
  `5010e662c53b1ea463571a6b3c0596af59ec389cc57c64f2e0f788e2a89cc712`;
  and
- `packages/vpsfree-policy.php`:
  `046bddb40ec12b629150597e27a5bed1081122c90b25c448c3a789ec3c840979`.

Recompute and compare these hashes after copying the source. Any change to an
evaluated runtime input invalidates the corresponding closure and test
evidence below.

## Completed offline evidence

All candidate Nix files parse and pass pinned nixfmt 1.4.0. Historical direct
evaluation of the original offline `module.nix` returned VPS `29942`,
`172.16.8.4/32`, and the `monitor`, `vpsadmin`, and `blog-migration` tags.
Repository integration later proved those first two tags and the default
monitoring/logging metadata would affect shared consumers. The current module
keeps the same VPS and address, sets `monitoring.enable = false`, pins its
future monitoring target to `172.16.8.4`, sets `logging.enable = false`, and
uses only the `blog-migration` tag. Fresh repository integration evidence must
replace the historical module evaluation before activation.

Later monitoring enablement must first add or reconcile the verified static
placement `blog.int.vpsfree.cz -> node25.prg.vpsfree.cz` (node ID `126`,
location `prg`) in `data/vpsadmin/containers.nix`. `confctl rediscover` does
not update that file. Revalidate live placement if the transition is not
immediate, then build every affected monitoring and alerting consumer.

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

The superseded pre-integration recovery run is retained in the execution
ledger. Current exact-target recovery evidence is recorded below.

Theme/package evidence:

- final theme source Nix hash:
  `sha256-MJ0mpnwUtXNgKuhCDZT3DMj+GAbx2naE/VbYb3rRpXU=`;
- current exact-target built-theme hash:
  `sha256-7BM4mozy4tkseI2UAmdll5zFD6izXflmpHNWzmSgZlA=`;
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

## Current repository integration

The isolated build-host worktree is based on reviewed master
`fa8de8a889df7ef97890eae9f19df96b9df51379`. Its linear Pavel-authored,
runtime-affecting task commits are `84cf0b94`, `c4e313a9`, `3557ae60`, and
`d6170bdc`; one documentation-only integration-evidence descendant follows
them. The dirty canonical checkout and every unrelated path remain untouched.
Remote master was still `fa8de8a8` at the post-rebase exact-target build gate.

The three upstream commits between the previous reviewed base and this base
updated the vpsAdminOS roles to `702155fb`, the vpsAdmin roles to `08ef5746`,
and vpsfreeWeb to `26e85847`. Rebuilding this target after the clean rebase
changed only the embedded configuration revision and embedded vpsAdminOS input
metadata. Its runtime services, packages, nginx configuration, firewall, and
recovery executables remained unchanged.

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

Final recovery review closed three gaps against the runbook: publication
requires the previous `current` symlink's target and device/inode identity to
remain unchanged; the post-publication check requires the exact symlink inode
created by the exporter; and `export.lock` is noclobber-created, required to
be a real root-owned mode-0600 single-link regular file, opened without
truncation, and matched to the opened descriptor before locking.

## Current exact-target integration evidence

Runtime-equivalent evidence commit
`d6170bdc24e9e0e37eb5b15eed6edf2b62c3f71d` built only
`cz.vpsfree/containers/int.blog` as generation
`2026-07-20--14-06-45`, with toplevel:

`/nix/store/24p8bazh9cc199wjk4i8017adyp8ds2q-nixos-system-blog-26.05.20260719.fd14620`

Relative to the pre-rebase tested generation `2026-07-20--13-42-56`, this
generation changes only the embedded configuration revision and the embedded
vpsAdminOS input metadata from `37d87632` to `702155fb`. The executable hashes
and complete generated runtime audit below are unchanged.

The generated recovery executable SHA-256 values are:

- core: `0c9b8ab4eb7c79682ba3137c8e17bee66c423bb7aeb648b1e87a016d2b8da8ef`;
- accepted wrapper:
  `54df85d501211c17ec090d1580e0013711b9dae3f0a6bc4d956c55882807b484`;
- manual wrapper:
  `4fc619f1c2737e9788a0b6c3f4534037ba5fde06a899ade07e2f31bb8b3d553c`;
  and
- health checker:
  `110dc6d4b5d6119ab896045e0328731a9b3780ffcea55accda013993b811946b`.

The accepted and manual wrappers both reference that exact core. The
current-source harness at
`/root/ai/tmp/wp-recovery-faults-current-20260720-qklQsiMP` passed 12 cases:

- successful publication with prior `current` present and absent;
- safe rollback after final-output failure with prior `current` present and
  absent;
- same-target replacement of the prior link before publication;
- same-target replacement of the published link before final verification;
- unsafe lock symlink, directory, mode, and hard-link count;
- a competing task-owned lock holder; and
- accepted-wrapper failure after a successful core export, followed by the
  actual health checker rejecting the unaccepted generation.

All failure cases produced no dated accepted marker. Safe rollback restored
the prior state. Externally replaced links were not overwritten; the
post-publication replacement was reported non-authoritative. The results TSV
SHA-256 is
`6e46d540574f6b0c33b47a7fcb07ed2f3a26d37c3d754937f7414893ebd78aaf`.

Generated closure review also passed: nginx syntax, the exact proxy real-IP
trust and FastCGI `REMOTE_ADDR`, one proxy `/32` IPv4 HTTP accept and no IPv6
HTTP accept, symmetric SMTP cleanup, socket-only MariaDB, immutable package
versions and contents, source hashes, and 1,492 PHP lint checks.

## Pending candidate and integration gates

Activation evidence must use a generation built from the documentation-only
descendant containing this validation update. Require that rebuild to differ
from runtime-equivalent commit `d6170bdc` only in the embedded configuration
revision, then dry-activate only that newly named generation. Retain these live
gates:

1. Through the real proxy canary, prove an injected `X-Real-IP` is overwritten,
   `X-Forwarded-For` cannot alter attribution, PHP/WordPress sees the real
   tester address from IPv4 and a genuine external IPv6 client, and a direct
   unauthorized backend source remains blocked with spoofed headers.
2. Rehearse the full 5.8.13 to 7.0.2 import/upgrade, plugins, custom theme,
   login/comment behavior, mail/HTTP confinement, controlled reboot, upload
   replacement, and accepted-marker restore. Every staging and restored
   uploads tree must contain real `uploads/fonts` with
   `wordpress:nginx` ownership and mode `0750`, represented in the directory
   manifest.

## Pending live gates

The execution ledger records end-to-end execution, guarded publication,
blog-only credential response, task-owned `SnapshotDownload`, one-time nginx
transitions, technical go/no-go, and cutover authorization. A genuine external
IPv6 containment vantage has also passed. The remaining gates are factual:

- compare the `int.web` candidate with its exact active generation so the
  blog-only transition cannot roll an unrelated shared site backward; the
  vpsfreeWeb revision now matches active `26e85847`, while the nixpkgs and
  vpsAdminOS differences still require explicit proof or narrow alignment;
- prove the narrow automation exclusion/hold before an `int.web` or proxy
  generation can diverge from active and published state;
- dry-activate and review each exact named generation before activation;
- verify the live managed-backup schedule and monitoring consumer before
  enabling the accepted timer; and
- pass the real-proxy canary, migration, restore, rollback, and cutover gates.

Do not run a broad selector, internal DNS change, production mail transition,
retained-state destruction, or another `vpsfreectl` provisioning mutation.

For recovery and restore decisions, `current` is non-authoritative. Only a
valid dated accepted marker may select its immutable generation.
