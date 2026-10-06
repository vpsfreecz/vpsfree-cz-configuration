# Mobile and localized transaction release — 2026-10-06

The maintainer authorized merging, deploying and testing WebUI PR20 (BFF
proxy-addr patch), PR21 (mobile interaction/forms) and PR22 (localized API
transaction labels). Integration PR23 preserves their original commits.
Unrelated network PR19 is excluded. The complete three-site receipt and test
scope are in the [application work log](https://github.com/vpsfreecz/vpsadmin-webui/blob/main/docs/work-log/2026-10-06-three-site-release.md).

## Deployed outcome

- Target: `cz.vpsfree/vpsadmin/int.vpsadmin-webui1`, `newadmin.vpsfree.cz`.
- Clean paired frontend/BFF: `78a723f7d8c609e05f9de7189ff35416747bafdc`.
- One generated WebUI input commit: `ddf51c27ac8dc8b9b55d1e78bf67830c8e6a8a56`,
  published to configuration master after successful activation.
- NixOS generation 8 at 22:10 CEST, 2026-10-06:
  `/nix/store/17djsaqvchg53b3aq3h14k7rvbq3iqp2-nixos-system-vpsadmin-webui1-26.05.20261006.b253099`.
- Existing site baseline closure changes were reviewed: cpupower 6.18.54 to
  6.18.55, perf-linux 7.2.8 to 7.2.9, NixOS version/date, nginx/BFF restart and
  dbus reload. Deployment was scoped to the WebUI VPS, with no API host deploy.
- API, database, OAuth client, credentials and live sessions were preserved.
  The effective `vpsadminServices` input remains
  `b4ef8535a629ee8c9cd753afecdb05e0895d0eea`.

## Verification

Exact-revision application CI passed before merge and activation: required
nonbrowser checks, build, script regression, 423 desktop Chromium, 364 mobile
Chrome and 28 mobile WebKit cases. One desktop-only case was skipped on WebKit.
Scoped Nix build and provenance/source/package checks passed. Dry activation
passed after using the existing forwarded SSH agent for confctl's self-copy;
no private key was installed. Activation used `--dry-activate-first` and
`--enable-auto-rollback`, followed by seven successful health checks.

Running BFF package metadata and public frontend metadata both report the exact
clean release. Auth endpoint smoke passed. The dev and clankerdev hosts also
received matching frontend/BFF releases through their separate procedure.
61 focused tests passed against deployed dev JavaScript with synthetic API
responses; they do not certify authenticated production workflows.

## Recovery

Retained rollback is generation 7 and paired application revision
`02ac0c7de1a588dbb14a18e652fe3f7e9b45cc51`:
`/nix/store/rxpz18f4b8g7a188azrw9062nx90a76n-nixos-system-vpsadmin-webui1-26.05.20261002.774debe`.
Follow the site runbook and inspect live state before rollback. Preserve the
current session store; do not restore spent refresh tokens from old backups.
This receipt is a documentation-only follow-up to the generated input commit.

Public desktop Chromium, mobile Chrome and mobile WebKit checks passed on all
three hosts. Newadmin's real CZ/SK QR images decoded at 740 x 740 under its live
CSP in all three browsers with synthetic payment parameters. Public language
switching, deep routes and absence of document overflow/page errors passed.
No production login or authenticated mutation was performed by these probes.
