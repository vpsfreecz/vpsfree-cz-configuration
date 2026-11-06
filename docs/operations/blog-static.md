# Static blog candidate

`cluster/cz.vpsfree/containers/int.blog/static-blog.nix` is imported with
`services.vpsfree-static-blog.enable = false`. Importing the disabled module adds
no effective users, units, tmpfiles, nginx virtual hosts or firewall rules.
WordPress configuration, port-80 protections, database/PHP/cron, proxy, DNS,
forum settings, input pins and existing health checks remain unchanged.

This is an inactive source candidate. Enabling it requires separate deployment
approval. No activation or dry-activation is part of its local preparation.

## Prepared hosting shape

If later enabled, an unprivileged `blog-release` user owns
`/var/lib/blog/{releases,receipts,assets}`. Nginx has separate Czech/English
virtual hosts on IPv4 port 8080, rooted at `current/cs` and `current/en`.
Unknown hosts are rejected; `/feed/` maps internally to RSS XML without a redirect.
The listener has no PHP execution. Port 8080 is allowed only from the same exact
metadata-resolved proxy IPv4, with assertions against broad port/range openings.
Metadata, archives and receipts sit outside both web roots.

The original WordPress virtual host remains separate on port 80. No current
proxy target is changed, and there is no new public English DNS/TLS setup here.
Static local checks must send the intended Host header. An empty candidate
release root serves no content; module enablement alone does not publish a site.

## Artifact preparation

The configuration-owned `tools/blog-static-release.py` uses the reviewed blog
artifact contract: deterministic `payload.tar.gz` plus `receipt.json`, separate
language roots, exact clean source SHA, build inputs, full file hashes and
workflow identity. The source repository's `docs/deployment.md` describes its
packager and workflow. No live-content flake pin or build on the VPS is needed.

Before any production use, establish the exact GitHub workflow ID, protected
`vpsfreecz/blog` main branch, artifact read visibility/credential and outbound
API/download route. Credentials are runtime files, not Nix/store inputs. The
helper's `prepare` command can independently verify API facts and stage the
exact current SHA; it does not switch a live pointer. No production request or
credential provisioning is needed to run the local mocked fixtures.

Missing or expired artifacts leave serving unchanged and report the exact SHA.
Rebuild/rerun that same authorized SHA through the trusted workflow; never
choose an older fallback or let the read-only pull credential dispatch a run.
Retain exact downloaded archives, extracted current/previous releases and their
receipts locally. Back them up with the validated WordPress recovery material;
Actions retention is temporary and is not the recovery contract. No cleanup or
garbage collector is included.

Validation rejects unsafe/traversing/duplicate paths, links, devices, undeclared
payload, identity mismatch and incorrect hashes before release staging. The
target never executes the payload. Signed download URLs and credentials are not
printed or copied to receipts. Fingerprinted `/css/` files have an independent
retained fallback so cached pages survive a pointer switch; HTML never uses that
fallback. Reusing immutable CSS or legacy-upload paths with different bytes is
rejected.

## Admission and transaction boundary

`pull.enable` defaults to false. Enabling it currently fails evaluation because
installed machine-coordination admission has not been integrated. The production
`pull`, `activate` and `rollback` CLI paths also refuse with
`machine-admission-unavailable`; there is no override flag, hook or environment
variable. The target's filesystem lock serializes writes only and grants no
machine ownership or maintenance exclusion.

Pure local fixture functions exercise atomic same-filesystem `current` symlink
replacement, immediate authorized-head/prior-receipt checks, current/previous
receipts, interruption reconciliation and explicit retained-release rollback.
An injected test callback is not a runtime admission bridge and is not exposed
as a production command. No activation-readiness conclusion follows from these
fixtures. A later package must implement and verify installed admission before
releasing the automatic driver.

Run the local checks from this configuration repository:

```sh
nix develop -c python3 tests/blog-static-release.py
nix eval --impure --json --expr 'import ./tests/blog-static-module.nix { nixpkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgsStable; }'
```

The module fixture compares effective disabled state with the existing hardened
WordPress configuration, checks separate roots/feed/PHP/unknown-host behavior,
proxy-only port policy and the refused scheduler. Mocked API/artifact fixtures
cover exact identity, expiry, malformed payload, hash mismatch, stale/concurrent
switches, interruption and rollback without contacting production. Complete
configuration builds/review remain separate checks on the exact final head.

## Future transition and rollback

Later approval must cover the actual static enablement, English DNS/TLS, proxy
port change, legacy query/alias handling and forum setup/tests. The source route
manifest is evidence, not nginx query routing. Briefly check for changed articles
or comments before switching, refreshing the snapshot only if needed; no formal
writer freeze is planned.

Rollback restores the proxy's original WordPress port-80 target and retained
WordPress state. An admitted static-content rollback can instead select a
validated retained release and record its own outcome without changing the system
generation. Retain newer static articles and Discourse replies for reconciliation;
do not delete forum data. Neither deployment evidence nor content rollback grants
default-branch integration or session lifecycle permission.
