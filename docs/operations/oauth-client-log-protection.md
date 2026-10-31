# PHP WebUI OAuth logging

OAuth callbacks can carry authorization codes and state in their query strings.
The vpsAdmin modules supply protection for nginx, HAProxy and PHP-FPM logs.
The [product logging contract](https://github.com/vpsfreecz/vpsadmin/blob/7219ab22a49f666077056fc2f093424547294aeb/docs/http-log-protection.md)
describes the defaults required by this configuration, their TLS behavior and
customization limits. This guide covers their deployment on vpsFree.cz; see also
[API documentation OAuth](vpsadmin-documentation-oauth.md).

## Site routing

The PHP hosts are `vpsadmin.vpsfree.cz`, `vpsadmin-admin.vpsfree.cz` and
`vpsadmin-dev.vpsfree.cz`. Site configuration selects their names, aliases,
certificates, listeners and backends. The development vhost also requires Basic
authentication. Product defaults protect their HTTP redirects and TLS requests,
along with the internal PHP nginx hosts.

API and authentication traffic follows the existing nginx → Varnish → HAProxy
route. Varnish retains the API metrics endpoint's 60-second cache. PHP traffic
uses its existing HAProxy route. Varnish's shared-memory request records remain
available; this configuration does not enable a collector that persists them.
Any separately configured request-log collector must omit secrets from its
persistent output.
At the API/auth edge, the site also clears `X-Forwarded-Prefix`, `X-Original-URL`,
`X-Rewrite-URL` and `Connection`, in addition to the product's forwarding-header
policy. Preserve these trust decisions when changing routes.

Read the generated nginx `access_log` directives to locate the product's logs.
They retain request status and timing while omitting queries and headers. Check
all selected virtual hosts, HTTP redirects and maintenance responses; errors
before nginx selects a virtual host remain outside this protection. Existing
logs are not deleted or retrospectively sanitized.

## PHP and development scope

The product's PHP-FPM defaults send native diagnostics to syslog while keeping
error logging and worker-output capture enabled. For code-bearing callbacks,
the application catches failures in OAuth setup, provider lookup, token exchange
and user login and records `vpsAdmin OAuth callback failed`. Failures before
that block, login initiation, logout, account switching and provider errors
without a code retain their existing behavior and diagnostics.

The development host uses a mutable application checkout. Verify its actual
revision and effective PHP settings separately from the production pin. Safe
proxy logs alone do not establish that its application diagnostics are protected.

## Verification and rollout

Build the proxy, both production WebUI hosts and the development WebUI host.
Inspect their generated configuration for every HTTP/TLS name and alias,
maintenance response and internal redirect. Confirm the product log format,
one effective `Referrer-Policy: strict-origin` header on PHP responses, retained
development Basic authentication, and the intended ACME handling, listeners
and upstreams. Review the product's listener and custom-snippet limits before
changing TLS settings.

Use the product-owned fixtures with the evaluated site configuration and the
actual installed nginx, PHP-FPM and WebUI packages. Exercise callback
setup/provider failures and success, then an ordinary error. Require the fixed
callback diagnostic and useful ordinary diagnostics in the configured sink,
with synthetic callback secrets absent from the captured persistent-log sinks. Check that request
values, status and redirects remain correct.

Record predecessor generations before an authorized rollout. Apply the edge
and HAProxy protections first, then the matching backend/application protection,
and enable callback traffic after both are in place. A partial rollout does
not establish protection through every hop. Real login acceptance, deployment
and default-branch integration follow their respective authorization procedures.
Synthetic checks do not prove historical or production absence of disclosure.

## Rollback

Restore affected systems through their recorded generations. Before rolling
back the product pin, inspect that generation's edge, HAProxy and backend
logging settings. Keep the persistent-log protections while callbacks remain enabled;
restoring an old logging policy reopens that sink.

OAuth clients, registered callbacks, credentials, session keys and database
state remain unchanged. No schema migration or credential rotation is required.
Handling any demonstrated exposure or existing logs is a separate task.
