# Newadmin payment QR release — 2026-10-04

The maintainer explicitly approved merging and deploying the prepared QR fix.
[WebUI PR18](https://github.com/vpsfreecz/vpsadmin-webui/pull/18) supplies the
validated image-source option; [configuration PR2](https://github.com/vpsfreecz/vpsfree-cz-configuration/pull/2)
permits the exact production generator endpoint and records this release.

## Deployed outcome

- Site: `newadmin.vpsfree.cz` only. The older Clankerdev/dev image policies already
  allow the generator; those deployments were not changed by this release.
- Clean paired frontend/BFF revision:
  `02ac0c7de1a588dbb14a18e652fe3f7e9b45cc51`.
- Generated WebUI input commit: `06dff9d6f9a3403ffc184424c5ed89baf78a5b0e`.
  `confctl inputs channel set --commit --no-editor vpsadmin-webui vpsadmin-webui
  02ac0c7de1a588dbb14a18e652fe3f7e9b45cc51` changed only the WebUI lock entry.
- NixOS generation 7, activated at approximately 11:29 CEST on 2026-10-04:
  `/nix/store/rxpz18f4b8g7a188azrw9062nx90a76n-nixos-system-vpsadmin-webui1-26.05.20261002.774debe`.
- The live HTML CSP now includes only `https://vpsfree.cz/nastroje/qr.php` as the
  additional image source. API connect, script and frame allowances stay intact.
- Existing credentials and session storage were retained. No API, database,
  account/payment settings or OAuth client change was performed.

## Verification

All five PR18 GitHub checks passed before merge: required nonbrowser checks,
production build, Chromium script regression and desktop/mobile PR smoke suites.
The merged tree matches the checked PR tree. Earlier focused evidence includes
1,699 unit tests and eight embedded/external QR browser cases in cs/en.

The full scoped `confctl build --yes cz.vpsfree/vpsadmin/int.vpsadmin-webui1`
passed in an isolated release directory on the target host, which has sufficient
space. This avoids the previous builder's full root disk without removing any of
its unrelated files. Nix provenance, source-contents and package-contents checks
passed. Dry activation succeeded and reported only the BFF restart and nginx
restart. Activation used `--dry-activate-first --enable-auto-rollback` and all
seven confctl health checks passed.

Post-activation checks confirmed matching clean frontend/BFF metadata, public
HTTP 200, auth/session endpoint smoke and the exact new image CSP allowance.
A Chromium probe opened the actual public login document and added temporary
browser-local image elements using synthetic payment parameters. No response
headers or document were intercepted. Both actual generator PNGs decoded under
the deployed CSP at 1366×900 and 393×851: CZ 145×145, SK 320×320, with zero CSP
violations. The probe did not use an authenticated member account or make payment
mutations; it does not certify unrelated authenticated workflows.

## Recovery

Retained rollback: NixOS generation 6, paired frontend/BFF revision
`f123a7fb825437034a764a8a5654032a481a8476`, system
`/nix/store/jpwfiwa9b6b6zrp00f72r535n07lpxf9-nixos-system-vpsadmin-webui1-26.05.20261002.774debe`.
Follow the site runbook to restore that generation and corresponding source
configuration if necessary. Preserve live credentials and sessions; do not restore
old refresh-token files. Rolling back also restores the old QR-blocking CSP.
