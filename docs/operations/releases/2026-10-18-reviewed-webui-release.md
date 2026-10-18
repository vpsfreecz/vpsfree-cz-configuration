# Reviewed joint release — 2026-10-18

## Approved scope

The maintainer explicitly requested merging and deploying our PRs 61, 62,
64, 65 and 66 together with the reviewed non-draft ETNyx PRs 53, 54 and 57.
Draft 63 is excluded. Integration PR 67 preserves feature commits and authors,
reconciles overlapping files and includes the
[bounded security review](https://github.com/vpsfreecz/vpsadmin-webui/blob/7860521f30826c3886c89c35e8ab6f4e082e0a4b/docs/work-log/2026-10-18-combined-pr-security-review.md).

Candidate: `7860521f30826c3886c89c35e8ab6f4e082e0a4b`.
Previous release on all three sites:
`f2ad625d6b5b5ee1d59d650086173515e2fd0438`. The intervening main commit
`f3202feb` records the previous deployment and contains documentation only.
No API code, database migration or production credentials are changed.

## Build and preparation

The exact clean source was built with its locked Nix dependencies on
`build.vpsfree.cz`. Frontend/BFF builds and provenance, source-content and
package-content checks passed. Package-content checks also passed with the
site configuration's effective followed inputs.

The older-host archive contains 1,172 manifest entries and SHA256
`545f788c57702f83b198041bd25d397ae68f30592ff69acd554fc8fe79dd27b6`.
Both targets passed manifest verification, nginx validation and runtime
configuration validation under the service account with real systemd
credentials before any pointer switch. Previous hashed assets were retained.

Newadmin configuration was prepared in an isolated builder worktree from
configuration master `e6685e60`. `confctl inputs channel set --commit` pinned
only `vpsadminWebui` to the exact selected revision. Generated commit
`05c09c9ce81caaaa947e6588ed84c9c84ae6a87b` has both author and committer
`Michal Janoušek <kerry@kerrycze.net>`; declared commit hooks passed.
The selected-host build and dry activation passed. Shared checkouts and
unrelated ongoing builds were preserved.

Retained newadmin rollback: generation 14,
`/nix/store/379s2rvn5ccmnakryaj8ck9nbp5i3xks-nixos-system-vpsadmin-webui1-26.05.20261015.26f4107`.
The previous paired older-host releases are retained with private receipts.

## Remaining environment limitations

Dev retains its existing self-signed certificate/SAN issue; TLS verification
exceptions apply only to that origin. Its root has approximately 596 MiB free
for non-root processes. New artifacts are staged under `/data`, which has
ample capacity. The earlier review moved inactive caches/backups without
deleting them; permanent root-filesystem capacity work remains outstanding.

Real payment instructions are not configured on dev. Payment interaction tests
therefore use synthetic API responses and do not certify live bank instructions.
Browser emulation does not certify a physical mobile device.

## Completed merge and verification

All six checks passed on the exact heads of all eight feature PRs and
[integration PR 67](https://github.com/vpsfreecz/vpsadmin-webui/pull/67).
Immediately before merging, main, every PR head, clean local state, inclusion
of the approved heads and exclusion of draft 63 were checked again. Main was
fast-forwarded to the tested candidate at 22:05 CEST; GitHub confirmed all
nine PRs merged. Only draft 63 remained open.

[Candidate CI](https://github.com/vpsfreecz/vpsadmin-webui/actions/runs/39160110983)
passed the required audits, type checks, script/BFF/unit suites (1,854 unit
tests) and production build.
[Candidate browser CI](https://github.com/vpsfreecz/vpsadmin-webui/actions/runs/39160110976)
passed 521 desktop Chromium, 463 mobile Chromium and 157 mobile WebKit tests.
One mouse-only WebKit scenario was intentionally skipped. No flaky/retry-only
pass was reported. Main's repeated nonbrowser CI also passed after merge.

Against the actually deployed dev build, all **204 focused Playwright cases**
passed across the same three browser projects, covering all changed UI flows.
These cases use synthetic API/BFF responses and block fallback requests to the
real API. The deployed JavaScript and CSS were not substituted.

Separate Playwright sessions used real OAuth and dev API calls, with no
response or asset mocks. They verified ownership/display of disposable VPS 62,
first-click/tap VPS detail navigation, filter chip layout, no horizontal overflow,
centered user-data creation, footer links and absence of JavaScript exceptions
on desktop, Android Chromium and iPhone WebKit. The admin test suspended the
owned VPS, then renewed it through the deployed form without sending a null
reminder, reactivated it and started it. The API returned 200 and eventually
reported the VPS active and running. The admin outage form opened; no outage
was published.

The first test used an access token saved before waiting for CI, beyond its
15-minute fixed lifetime, and failed authentication. Fresh login succeeded.
Both fresh member/admin sessions then survived a controlled BFF restart.
The BFF runtime files/dependencies were byte-identical to the previous release
apart from build metadata. This does not certify long-idle refresh behavior.

Cleanup removed VPS 62 and all three release-test templates, closed all sessions
for the two disposable accounts and restored their locked/auth-disabled state.
Both captured tokens subsequently returned 401. Local/server temporary passwords,
cookies and token files were removed. Other accounts and infrastructure were
not changed.

## Deployment outcome

| Site | Verified release | Outcome |
| --- | --- | --- |
| dev.crucio.cz | `7860521f30826c3886c89c35e8ab6f4e082e0a4b` | Paired pointers/process verified; auth smoke and live/synthetic browser checks passed |
| clankerdev.vpsfree.cz | `7860521f30826c3886c89c35e8ab6f4e082e0a4b` | Paired pointers/process verified; auth smoke passed |
| newadmin.vpsfree.cz | `7860521f30826c3886c89c35e8ab6f4e082e0a4b` | Generation 15; seven confctl health checks and auth smoke passed |

Newadmin was switched using `confctl deploy --yes --dry-activate-first
--enable-auto-rollback cz.vpsfree/vpsadmin/int.vpsadmin-webui1 switch`.
The active system is
`/nix/store/6cy0w31n1r7xbmlh7yrbwrdcnqf3bz39-nixos-system-vpsadmin-webui1-26.05.20261015.26f4107`.
The separately verified BFF package is
`/nix/store/mx6ga0h64p3n75wlff5qcla883457hk0-vpsadmin-webui-bff-0.1.0`.
All frontend/BFF metadata records contain the matching full SHA and
`dirty: false`. Credential and nginx configuration hashes on the older hosts
were preserved. API origins remain dev.crucio.cz for dev and api.vpsfree.cz
for the two public sites.

Private paired rollback receipts/artifacts are retained on dev under
`/data/webui-release-20261018/private` and clankerdev under
`/root/webui-release-20261018/private`. Restore paired pointers using the
documented recovery procedure and the receipt; do not restore stale session files.
Newadmin retains generation 14.

## Public browser acceptance

All nine site/browser combinations passed real anonymous page rendering, API
origin/provenance checks, language switching, mobile menu navigation, news/about
deep links, viewport overflow and zero JavaScript exceptions. Both production
QR generators (CZK/EUR, synthetic payment parameters) decoded successfully
inside newadmin in desktop Chromium, mobile Chromium and WebKit under the
actual CSP. The CSP retains console/heatmap origins in `frame-src` and the
exact QR endpoint in `img-src`. Authenticated production mutations were not
performed; real mutation verification was confined to dev.

The standalone public harness initially selected all outage links, which became
ambiguous with live outage content. It was corrected to target the banner's
navigation link (mobile markup is not a `nav` landmark). All nine cases then
passed; no application change or skipped assertion was needed.

Evidence: [public browsers](assets/2026-10-18-webui/public-results.json),
[member workflow](assets/2026-10-18-webui/live-results.json),
[real VPS renewal](assets/2026-10-18-webui/admin-results.json),
[mobile editor](assets/2026-10-18-webui/iphone-centered-editor.png),
[renewed VPS](assets/2026-10-18-webui/admin-renewed-running.png).

The configuration input commit and this receipt are published directly to
master under the maintainer's channel-update instruction; no configuration PR
is required. Repeated post-merge browser workflows may still be running when
this receipt is committed. The exact pre-merge candidate's required CI and
post-deployment checks above have completed successfully.
