# PHP WebUI OAuth logging

OAuth callbacks can carry authorization codes and state in their query strings.
The legacy PHP WebUI protects logs at its public proxy, internal nginx and
application error handler. These controls complement the shared
[API and authentication service protections](vpsadmin-documentation-oauth.md).

## Proxy logs

The policy covers `vpsadmin.vpsfree.cz`, `vpsadmin-admin.vpsfree.cz` and
`vpsadmin-dev.vpsfree.cz`, including their HTTP redirects and common internal
nginx configuration. The development vhost retains its basic authentication.

The site fragment `configs/nginx/oauth-client-logs.nix` writes access records to
`/var/log/nginx/oauth-clients.log`. Records retain client address, time, method,
path without query, status, response size, request time, upstream response time
and upstream status. They omit the full request target, query, Referer,
User-Agent and arbitrary headers or bodies.

Nginx cannot redact individual values from arbitrary error messages, so these
vhosts suppress raw nginx errors. Safe access records, startup failures, health
checks and application diagnostics remain available. Malformed requests rejected
before vhost selection are outside this control. Existing logs are not deleted
or retrospectively sanitized.

The production and development HAProxy frontends disable HTTP request logging.
Their binds, backends, balancing and metrics stay unchanged. These callbacks do
not traverse Varnish.

Explicit HTTP redirect vhosts carry the same log policy. They retain the
redirect status and complete destination, including its query, along with the
existing names, aliases, certificates and ACME webroots. The redirect remains
in location `/` so the generated HTTP-01 challenge location takes precedence.
Maintenance and ACME locations inherit the selected log policy.

Callback responses, redirects and errors use `Referrer-Policy: strict-origin`.
Nginx hides upstream copies before adding this header. Later requests retain an
origin for form guards without sending the full callback URL as Referer. OAuth
inputs, Cookie, Authorization, bodies, Location and Set-Cookie remain intact.

## PHP diagnostics

The WebUI PHP-FPM pool sends native PHP diagnostics to syslog. Use the explicit
`syslog` destination: PHP interprets `stderr` as a file path, which can resolve
inside the read-only Nix store. Normal error logging and worker-output capture
remain enabled.

For callbacks containing a code, the WebUI catches failures from OAuth setup,
provider lookup, token exchange and user login. It displays the existing generic
error response and logs only `vpsAdmin OAuth callback failed`. Exception messages
and traces are omitted. Successful callbacks retain their state checks, session
handling and redirect.

This catch does not cover failures before the callback block or change login
initiation, logout, switching accounts or provider errors without a code. Those
paths retain their existing behavior and diagnostics. The development host uses
a mutable application checkout; verify its actual revision instead of inferring
it from the production pin.

## Verification and rollout

Before activation, inspect generated configuration for every HTTP/TLS name,
alias, maintenance response and internal redirect. Confirm the safe log policy,
one effective strict-origin header, retained development basic authentication
and unchanged ACME, listeners and upstreams.

Use an isolated fixture with the installed nginx, PHP-FPM and WebUI package.
Exercise callback setup/provider failures and success, then an ordinary error.
Require the fixed callback diagnostic and useful ordinary diagnostics in the
actual configured sink, with no synthetic callback secrets in captured logs.
Check that request values, status and redirects remain correct.

Prepare affected outputs and record predecessor generations before an
authorized rollout. Apply edge and HAProxy controls before backend/application
protection. A partial rollout does not establish protection through every hop.
Real login acceptance, deployment and default-branch integration follow their
respective authorization procedures. Synthetic checks do not prove historical
or production absence of disclosure.

## Rollback

Restore affected systems through their recorded generations. Retain independent
proxy protections when reverting the application where possible; restoring an
old log policy reopens that sink. OAuth clients, registered callbacks,
credentials, session keys and database state remain unchanged. No schema
migration or credential rotation is required. Handling any demonstrated exposure
or existing logs is a separate task.
