# Static blog hosting and signed delivery

The backend owns blog routing. Its IPv4 port-80 frontend accepts Czech and
English hostnames from the Prague proxy's metadata-defined IPv4 address and
from local checks. The public proxy configures HTTPS/ACME for both languages
and forwards to backend port 80. Its only upload exception is the exact Czech
`/_deploy/blog` location; unrelated vhosts, limits and the nginx main unit
remain unchanged.

`services.vpsfree-static-blog.enable` and `publication.enable` default false.
When static storage is enabled, the frontend sends both fixed language Hosts
to the loopback static server on `127.0.0.1:8080`. When disabled, both return
503. Missing content while enabled returns 404 without a fallback. Unknown Hosts return 444. The former
`serveStatic` option is removed. Ports 8080 and 8091 stay private; the retired
WordPress and MySQL ports 8081 and 3306 have no listeners or firewall openings.

Each hop fixes Host. The proxy overwrites X-Real-IP and HTTPS protocol headers;
the frontend trusts only that proxy /32 and passes its resolved client address
and fixed HTTPS scheme. The backend owns nginx enablement, graceful reload and
the exact proxy IPv4 TCP/80 firewall rule. Health checks exercise both fixed
language Hosts through the local frontend. Internal content vhosts use relative
directory redirects; explicit legacy 301 redirects retain fixed HTTPS targets.
Static feeds internally select `/feed/index.xml` with RSS MIME type. Metadata
and receipts stay outside web roots.

The current configuration installs no WordPress application, PHP-FPM, WordPress
init/cron/timer or local MySQL service. It retains dormant `wordpress` and
`mysql` accounts and the `mysql` group with their previous UID, group and home
settings. Existing database/site files, uploads/fonts, secret keys, backups,
UID/GID maps and old system roots remain recovery data. Their ownership and
permissions must not change during source retirement; no data purge is implied.

## Publication authority and package

The protected-main Actions workflow holds the deployment key and authorizes a
release. The target proves key possession and package consistency, not
independent GitHub main/run success. Repository/workflow names are fixed; SHA,
run identity, source NAR and build inputs are authenticated sender assertions.
A key holder can publish arbitrary conforming site content, including
JavaScript. Operators must protect main/workflow changes and restrict the
`blog-production` environment to protected main. Only its push deploy job
receives `BLOG_DEPLOY_KEY`; pull requests, feature pushes and manual artifact
runs cannot upload automatically. No target PAT, GitHub API client, webhook,
queue or polling worker is installed.

The schema-1 package contains exactly `payload.tar.gz` and `receipt.json` in
one ZIP. The archive has separate `cs/` and `en/` trees, complete hash metadata
and its release envelope. Validation checks regular files, safe unique paths,
repository/workflow identity, clean source/build metadata, every declared hash
and archive digest. It rejects links, devices, executable/private web payloads
and undeclared files. The target never executes uploaded content. The BLOG
repository's `docs/deployment.md` describes packaging and workflow behavior.

## Fixed upload protocol

The endpoint is `POST https://blog.vpsfree.cz/_deploy/blog`. When publication is
enabled, the public proxy and backend port 80 forward it to `127.0.0.1:8091`.
Publication requires static storage. With publication or storage disabled, the
endpoint returns 404. English and other `/_deploy/` paths also return 404 at the
backend; `/_hooks/` returns 404. These reserved paths never reach the content
server.

Use one `Content-Type: application/zip`, one positive `Content-Length` and
exactly one of each identity header:

- `X-Blog-Run-Number`: canonical positive decimal workflow run number.
- `X-Blog-Body-SHA256`: lowercase 64-character SHA-256 of the exact ZIP bytes.
- `X-Blog-Signature`: `sha256=` followed by lowercase HMAC-SHA256 hex.

The HMAC message is ASCII with these five newline-terminated lines:

```text
blog-upload-v1
POST
/_deploy/blog
RUN_NUMBER
BODY_SHA256
```

The final digest line ends in a newline; there is no blank line after it. The
receiver rejects duplicate identity/framing headers, transfer/content encodings
and invalid signatures before package work, then streams the body to a
temporary file and compares its digest. The raw key never traverses the private
HTTP hop. The client uses verified HTTPS, follows no redirects and permits no
insecure certificate option. Keep keys/signatures out of URLs and debug logs.

Only the exact Czech location permits 512 MiB at both nginx hops. Compressed
ZIP, ZIP expansion and expanded tar payload each have 512 MiB ceilings; the
payload also has a 25,000-file ceiling. Both exact locations buffer request
bodies and have 180-second send/read timeouts; the receiver bounds body receipt
to 180 seconds. The client has 300 seconds total and at most 3 attempts. These
are provisional budgets requiring a full-size measurement of bytes, processing
time, memory and disk before production. Ordinary routes retain their existing
limits. Endpoint access/error logging is suppressed; no payload or
authentication header is logged by the receiver.

One service accepts body/validation/commit work at a time and rejects busy
requests with 503. It responds 200 JSON only after the exact release, selected
pointer and current receipt pass durability barriers, or after verifying an
identical retry still selected. The response binds source SHA, release key,
current receipt digest, body digest and run number/ID/attempt. Authentication,
invalid packages, conflicts and stale orders return non-2xx; paused/busy
requests are retryable. There is no 202 acceptance, deferred queue or
background replay.

A connection can fail after commit. The client retries transient errors using
the identical ZIP bytes and signature and checks the complete 200 identity.
Actions failure means delivery was not confirmed, not that serving is
unchanged. Retry that exact package or use root status to resolve uncertainty.
Once a pointer transaction starts, its reconciliation proceeds independently of
the client connection.

## Credentials and service

Enable storage and `publication.enable`, and set `publication.secretFile` to an
absolute runtime file string outside the Nix store. Provision a root-owned 0600
file containing 32 to 4096 exact key bytes and the matching UTF-8 Actions
secret; a randomly generated ASCII key is convenient. Do not add a newline on
either side. Nix installs no key material. systemd `LoadCredential` exposes
only that key to the fixed nonroot `blog-release` service. It has content
access but no root/systemctl authority. Rotation requires a coordinated
publication pause and replacement of both copies; there is no permanent dual-
key mode.

`blog-release` owns `/var/lib/blog/{releases,receipts,assets}`. Root owns
`/var/lib/blog-control` and the pause record. Its stable transaction lock is
group-accessible to `blog-release`, which can lock but cannot replace it or
change control state. The immutable policy fixes authority version, repository,
workflow path and state root, and binds the helper implementation. The active
policy reference must match the compiled helper. Before committing an upload,
the helper checks the current system and policy against the root-owned resume
record. A receiver can survive a system switch and accept uploads after the
operator verifies and explicitly resumes the new system, provided its compiled
policy is still selected. A changed policy requires the normal service update.

## Ordering, durability and maintenance

The target retains the greatest committed `(run_number, run_attempt)` in
`receipts/upload-order.json`, with run ID/source/body digest/release binding.
Lower orders and conflicting reuse are rejected; one run number keeps its run
ID and source across attempts. An identical retry succeeds only if its exact
transaction is still selected. A higher order is durably recorded even when
content selection is unchanged. The ordering namespace belongs to this fixed
workflow; recreating it requires explicit operator reinitialization. GitHub
concurrency controls load but does not establish dispatch order. The target
cannot know about a newer main commit that has not arrived successfully.

Body receipt stays outside the content locks. Immutable staging flushes payload,
archive and directory hierarchy, retaining its staging lock through commit.
Commit validates retained content, preserves fingerprinted CSS and immutable
legacy media, then rechecks policy/system and maintenance under the stable lock.
A durable pending transaction carries the
ordering floor before atomic pointer replacement. Current receipt, floor and
history are flushed before acknowledgment; reconciliation completes an
interruption after replacement or preserves the old selection before it.
Unknown pointers or corrupt content fail closed. Release retention runs
separately from uploads.

Root maintenance and rollback delegate content work to a child that
irreversibly drops to the fixed service UID/GID/groups with no retained
capabilities. It inherits the held lock. Root changes only control state.
Missing state defaults paused; resume binds the immutable policy digest and
selected system generation.

```sh
blog-static-release maintenance-enter
blog-static-release status
# Deploy and verify the intended system with the normal operator procedure.
blog-static-release maintenance-exit
```

Enter waits for an in-flight pointer transaction and blocks further commits
while publication is paused. A request already receiving or staging content may
finish after an explicit resume if the selected policy, control state and upload
ordering permit it. Exit reconciles receipts and resumes only the selected
policy/system; it enqueues nothing. The native pre-switch check requires pause
when prior publication exists, including when the candidate disables
publication. A failed switch never resumes
automatically; switching to older software also requires compatible target
activation and control-state checks.

`rollback --release KEY --expected-current DIGEST` is root-only and first
persists pause, then validates/selects the retained release as a separate
transaction. It preserves the greatest upload order. Publication stays paused;
after explicit resume, an old retry still cannot undo rollback. A newer
authorized upload is required. Use `status` for the selected release, current
receipt digest and committed floor. Rollback requires a complete retained
release; a pruned payload is no longer a rollback target. All receipts remain.
If no complete retained static release is available, keep serving unavailable
and restore a backed-up static payload through the normal publication authority.
There is no WordPress fallback in the current configuration.

Policy/control schema 2 is the upload authority boundary. Compatible schema-2
systems can roll back complete retained schema-1 **release content**. That does
not establish compatibility with an older schema-1 **control system**: its
maintenance check requires the older control schema and rejects schema-2 state.
Do not run old publication writers against the newer state.

A retained schema-2 system from the WordPress coexistence period may still
support WordPress recovery through its own routing selector. Recovery requires
its rooted generation, original inputs, database/site backups and account
owners. The retained generation determines routing; the current configuration
has no WordPress route. Before restoring an older system, inspect its
MySQL/tmpfiles rules: the generic data-directory rule is 0755 and must not widen
retained `/var/lib/mysql` permissions of 0700. Content recovery includes no
database or forum rollback, reimport or deletion.

## Release retention

`services.vpsfree-static-blog.retention.keepReleases` is a positive integer,
defaulting to 5. When storage and publication are enabled, the daily
`blog-release-prune.timer` runs the selected helper as `blog-release`, without
credentials or network access. It keeps the configured number of newest distinct
available releases by successful selection time, plus the current release, its
immediate previous release and the release named by the ordering floor. These
protected references can retain more payloads than the configured count.

Only old, successfully selected release directories and their matching archives
are candidates. Stage-only releases, incoming directories and unknown orphans
remain untouched. All release and transaction receipts, ordering state, control
records and both locks are retained. Shared immutable CSS remains cumulative;
the selected and retained trees preserve their legacy media. This bounds old
completed payload copies, not total disk usage. Keep independent WordPress,
configuration, secret and system-generation backups outside this retention.

```sh
blog-static-release prune --dry-run
blog-static-release prune
```

Root invocations delegate content work to the same `blog-release` account.
Dry-run reports the keep and candidate sets without changing content or trash;
it may run while publication is paused. Actual pruning skips while paused or
disabled, when either existing lock is busy, or while a transaction is pending.
Missing protected content and conflicting references refuse retirement.

Uploads, maintenance and rollback continue to wait for their existing locks.
Prune alone tries publication and then staging without waiting, releasing
publication immediately if staging is busy. It never causes an upload failure
solely through lock contention. Under both locks it inspects only metadata and
renames eligible payloads into private `releases/.trash`. Recursive deletion
uses directory descriptors and rejects links or filesystem boundaries after
both locks have been released. Slow or failed deletion therefore does not hold
up an upload commit. Existing finite network timeouts still apply; stalled
storage can still exhaust them.

The helper reports kept, candidate, retired and deleted release keys, skips and
cleanup failures. An interrupted retirement or deletion can be retried by the
next pass using the retained receipts and trash entries. It does not restore
retired payloads automatically or reset ordering. Cleanup failure cannot undo a
successful publication. Schema-1 release content remains supported while its
complete payload is retained; receipts alone do not promise rollback access.

## Checks and operator transition

```sh
nix develop -c python3 tests/blog-static-release.py
nix develop -c python3 tests/blog-upload.py
nix eval --impure --json --expr 'import ./tests/blog-static-module.nix { nixpkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgsStable; }'
nix eval --impure --json --expr 'import ./tests/blog-upload-module.nix { nixpkgs = (builtins.getFlake (toString ./.)).inputs.nixpkgsStable; }'
```

Focused fixtures cover validation, authentication, body/header bounds,
ordering, exact retries, interrupted commits, rollback/pause, policy/system
changes, credential isolation, module modes and generated routes. Module
fixtures also check absent WordPress/MySQL runtime, retained account metadata,
private ports and both disabled 503 frontends. The unchanged proxy fixture
checks unrelated vhosts and main-unit parity. Final committed independent review
precedes the affected backend native build. This retirement does not change
the publisher or proxy and does not require repeating their full-size upload
measurement. Synthetic tests do not prove live TLS, branch/environment
restrictions, systemd credentials, production UIDs or real GitHub delivery.

Before retiring a coexistent backend, preserve old rooted systems and inputs,
independent database/site/secret-key backups, UID/GID maps, current receipt and
upload floor. Verify a complete retained static recovery payload and actual
account ownership and data permissions. Confirm live Czech and English proxy
forwarding still targets backend port 80; reconcile any different predecessor.
The proxy configuration and its TLS/upload exception need no deployment for
this backend-only transition.

Build and copy the reviewed backend, inspect the system diff and dry activation,
and confirm that retirement is limited to WordPress init/cron/PHP-FPM and local
MySQL. Enter publication maintenance before switching. Activate the static-only
backend with graceful nginx reload and unchanged proxy trust. The new firewall
configuration retains only the exact idempotent teardown of the two old
WordPress SMTP OUTPUT chains; it does not create them or flush unrelated rules.
Check that no remaining WordPress worker needs those restrictions.

Verify retired units and absent 8081/3306 listeners, both fixed frontend Hosts,
static hashes, feed/search/media, PHP denial and the finite 540 Czech legacy
aliases. Unknown literal identity/feed combinations return 404; encoded keys
are not inferred. English has no Czech aliases. Check dormant account metadata,
retained data ownership and permissions, receiver health, current receipt,
floor, control state, timer and policy. Use raw HTTP checks without executing
article scripts or creating forum topics. Explicitly leave maintenance against
the new selected system even when the helper and policy bytes are unchanged;
resume changes no content or ordering.

Recover content first with a complete retained static release through guarded
rollback, preserving the maximum floor, followed by explicit resume. If a system
recovery is needed, use the compatible rooted generation and its own versioned
recovery rules above. Retain newer static articles and forum replies for
reconciliation. Scheduled retention removes only eligible static release
payloads, not WordPress data, backups, Nix roots or Git refs. Any later purge of
old data or dormant accounts needs separate approval and a decision to retire
that recovery path. Content rollback remains separate from system rollback,
default-branch integration and session lifecycle.
