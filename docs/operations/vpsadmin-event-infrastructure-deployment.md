# Deploying vpsAdmin event infrastructure

This runbook deploys the infrastructure prerequisites for the vpsAdmin event
system: the physical SMS gateways, Alertmanager routing and Prometheus
scraping. It is intentionally independent of the vpsAdmin maintenance
cutover. Do not deploy vpsAdmin API, WebUI, RabbitMQ, database, proxy, Node or
DNS generations while following this document.

Complete the checks and the single real SMS proof at the end, record the
evidence and stop. Continue later with
[Deploying the vpsAdmin event system](vpsadmin-event-system-deployment.md) only
when the operator decides that this infrastructure is ready.

## Compatibility and rollback

The new Alertmanager configuration adds a bearer header and continues to send
the same Alertmanager webhook format to port 9876. Old Sachet ignores the
additional header, so Alertmanager can be upgraded before the physical
gateways. The reverse combination is not supported: the new gateways require
the bearer token and reject requests from an old Alertmanager configuration.

Use this deployment order:

1. `int.alerts1`, then `int.alerts2`;
2. BRQ APU, then PRG APU; and
3. `int.mon1`, then `int.mon2`.

The Alertmanager HAProxy prefers PRG, then BRQ, then the local Sachet/Nexmo
fallback. The local fallback remains installed throughout this rollout.

Each new physical gateway creates
`/var/lib/vpsfree-sms-gateway/gateway.db` at schema version 1. There is no
Sachet database migration. Preserve this database across restarts and later
generations.

An individual APU can be rolled back while Alertmanager remains upgraded. For
a complete rollback, switch both APUs back to Sachet before rolling back either
Alertmanager. Otherwise the old Alertmanager would send unauthenticated
requests to a new gateway. Roll back Prometheus last.

Before rolling back an APU, stop new test traffic and inspect its durable
queue. Resolve or explicitly account for every queued or in-progress message;
the old Sachet service cannot drain the new gateway database.

## Prepare the release

Deploy only reviewed revisions. Do not infer them from an arbitrary worktree.

```shell
APPROVED_CONFIGURATION_REVISION=REVISION_APPROVED_FOR_INFRASTRUCTURE
SMS_GATEWAY_REVISION=REVIEWED_SMS_GATEWAY_REVISION

test "$(git rev-parse HEAD)" = "$APPROVED_CONFIGURATION_REVISION"
test -z "$(git status --porcelain --untracked-files=no)"
test "$(jq -r '.nodes.vpsfreeSmsGateway.locked.rev' flake.lock)" = \
  "$SMS_GATEWAY_REVISION"
```

Record the currently active generation on all six targets. These are the
rollback generations:

```text
cz.vpsfree/containers/prg/int.alerts1
cz.vpsfree/containers/prg/int.alerts2
cz.vpsfree/machines/brq/apu
cz.vpsfree/machines/prg/apu
cz.vpsfree/containers/prg/int.mon1
cz.vpsfree/containers/prg/int.mon2
```

Provision secrets through the normal encrypted secret-distribution process.
Do not print their values or put them in shell history, deployment notes or the
configuration repository.

Both Alertmanager containers require:

- `/private/alertmanager/sms_gateway_token.txt`.

Both APUs require:

- `/private/alertmanager/sms_gateway_token.txt`;
- `/private/vpsadmin-sms-gateway-token`;
- `/private/vpsfree-sms-gateway/status-token`; and
- `/private/vpsadmin-sms-callback-token`.

The Alertmanager token must be identical on both Alertmanagers and both APUs.
The vpsAdmin and callback tokens must be identical on both APUs and reserved
for the later API deployment. Compare protected checksums through the approved
secret tooling. Verify ownership and mode without displaying file contents.

Build and dry-activate every target before switching any of them:

```shell
confctl build cz.vpsfree/containers/prg/int.alerts1
confctl build cz.vpsfree/containers/prg/int.alerts2
confctl build cz.vpsfree/machines/brq/apu
confctl build cz.vpsfree/machines/prg/apu
confctl build cz.vpsfree/containers/prg/int.mon1
confctl build cz.vpsfree/containers/prg/int.mon2

confctl deploy cz.vpsfree/containers/prg/int.alerts1 dry-activate
confctl deploy cz.vpsfree/containers/prg/int.alerts2 dry-activate
confctl deploy cz.vpsfree/machines/brq/apu dry-activate
confctl deploy cz.vpsfree/machines/prg/apu dry-activate
confctl deploy cz.vpsfree/containers/prg/int.mon1 dry-activate
confctl deploy cz.vpsfree/containers/prg/int.mon2 dry-activate
```

Copy the six selected generations to their targets without activating them.
Record the exact selected generation identifiers beside their rollback
generations. All `switch` commands below must use those reviewed identifiers.

## Prepare authenticated probes

Before changing Alertmanager, confirm that old Sachet tolerates the bearer
header. Run the probe from an Alertmanager host using a protected temporary
curl configuration so the token is not exposed in the process list:

```shell
AUTH_CONFIG="$(mktemp)"
PROBE_BODY="$(mktemp)"
trap 'rm -f "$AUTH_CONFIG" "$PROBE_BODY"' EXIT
chmod 0600 "$AUTH_CONFIG" "$PROBE_BODY"

{
  printf 'header = "Authorization: Bearer '
  tr -d '\r\n' < /private/alertmanager/sms_gateway_token.txt
  printf '"\n'
} > "$AUTH_CONFIG"

printf '%s\n' \
  '{"receiver":"__deployment_auth_probe__","status":"firing","alerts":[]}' \
  > "$PROBE_BODY"

STATUS="$(${CURL:-curl} \
  --silent --show-error \
  --output /dev/null \
  --write-out '%{http_code}' \
  --config "$AUTH_CONFIG" \
  --header 'Content-Type: application/json' \
  --data-binary "@$PROBE_BODY" \
  http://apu.int.prg.vpsfree.cz:9876/alert)"

test "$STATUS" != 401
test "$STATUS" != 403
```

The deliberately unknown receiver must not enqueue or send an SMS. Stop if the
request is rejected for authentication or if the result cannot be explained
from Sachet logs.

Retain the same protected curl configuration for authenticated probes in this
maintenance session. Recreate it on another host rather than copying a token
file through an unapproved channel.

## Deploy Alertmanager

Switch the two Alertmanager containers one at a time:

```shell
confctl deploy --generation ALERTS1_GENERATION \
  cz.vpsfree/containers/prg/int.alerts1 switch
confctl deploy --generation ALERTS2_GENERATION \
  cz.vpsfree/containers/prg/int.alerts2 switch
```

After each switch, verify:

- `alertmanager.service`, `haproxy.service` and the local `sachet.service` are
  active with no failed units;
- Alertmanager is ready and remains a healthy member of its two-instance
  cluster;
- the loaded configuration contains the bearer credential file for both SMS
  receivers;
- route testing maps the existing critical/fatal labels to the intended SMS
  receiver; and
- HAProxy lists PRG, BRQ and local Nexmo backends in that order.

Also prove that the configured service identity can read the bearer credential
without displaying it:

```shell
ALERTMANAGER_USER="$(
  systemctl show --property User --value alertmanager.service
)"
test -n "$ALERTMANAGER_USER"
runuser -u "$ALERTMANAGER_USER" -- \
  test -r /private/alertmanager/sms_gateway_token.txt
```

Do not proceed if notification delivery errors appear in either Alertmanager
log. At this point both physical backends are still old Sachet and rollback of
an Alertmanager is independent.

## Deploy the physical gateways

Switch BRQ first:

```shell
confctl deploy --generation APU_BRQ_GENERATION \
  cz.vpsfree/machines/brq/apu switch
```

Verify locally and from an Alertmanager host:

```shell
confctl ssh cz.vpsfree/machines/brq/apu \
  systemctl is-active vpsfree-sms-gateway.service
confctl ssh cz.vpsfree/machines/brq/apu \
  test -c /dev/ttyUSB-EC25-at
confctl ssh cz.vpsfree/machines/brq/apu \
  vpsfree-sms-gatewayctl \
  --db /var/lib/vpsfree-sms-gateway/gateway.db stats

curl --fail http://apu.int.brq.vpsfree.cz:9876/-/live
curl --fail http://apu.int.brq.vpsfree.cz:9876/-/ready
curl --fail http://apu.int.brq.vpsfree.cz:9876/metrics >/dev/null
```

Repeat the authenticated unknown-receiver probe against BRQ. It must return an
application-level rejection rather than 401/403, and the gateway queue counts
must remain unchanged. Check the service journal for modem initialization or
SQLite errors.

Switch PRG and perform the same checks:

```shell
confctl deploy --generation APU_PRG_GENERATION \
  cz.vpsfree/machines/prg/apu switch

confctl ssh cz.vpsfree/machines/prg/apu \
  systemctl is-active vpsfree-sms-gateway.service
confctl ssh cz.vpsfree/machines/prg/apu \
  test -c /dev/ttyUSB-EC25-at
confctl ssh cz.vpsfree/machines/prg/apu \
  vpsfree-sms-gatewayctl \
  --db /var/lib/vpsfree-sms-gateway/gateway.db stats

curl --fail http://apu.int.prg.vpsfree.cz:9876/-/live
curl --fail http://apu.int.prg.vpsfree.cz:9876/-/ready
curl --fail http://apu.int.prg.vpsfree.cz:9876/metrics >/dev/null
```

Confirm from both Alertmanager hosts that HAProxy considers PRG and BRQ
available. Keep the local Sachet/Nexmo backend active.

## Deploy Prometheus

Switch the two monitor containers one at a time:

```shell
confctl deploy --generation MON1_GENERATION \
  cz.vpsfree/containers/prg/int.mon1 switch
confctl deploy --generation MON2_GENERATION \
  cz.vpsfree/containers/prg/int.mon2 switch
```

After each switch, verify `prometheus.service`, its loaded configuration and
the `sms-gateway` scrape job. The query below must return exactly the PRG and
BRQ targets with value 1 on both monitors:

```promql
up{job="sms-gateway"} == 1
```

Check that gateway identity/location labels are correct and that queue,
delivery and modem metrics have plausible values.

## Send one real proof SMS

Use `sms-aither` for the one approved real message. Run this from one
Alertmanager container through its local HAProxy. This exercises the deployed
bearer credential, HAProxy preference and the PRG physical gateway without
creating a firing Alertmanager alert that would also notify other receivers.
It is a compositional infrastructure proof rather than an Alertmanager-process
end-to-end notification: the loaded configuration, route test and
service-user credential-read check validate the Alertmanager side, while the
request below validates its exact webhook payload and downstream path.

```shell
AUTH_CONFIG="$(mktemp)"
PROOF_BODY="$(mktemp)"
RESPONSE="$(mktemp)"
trap 'rm -f "$AUTH_CONFIG" "$PROOF_BODY" "$RESPONSE"' EXIT
chmod 0600 "$AUTH_CONFIG" "$PROOF_BODY" "$RESPONSE"

{
  printf 'header = "Authorization: Bearer '
  tr -d '\r\n' < /private/alertmanager/sms_gateway_token.txt
  printf '"\n'
} > "$AUTH_CONFIG"

cat > "$PROOF_BODY" <<'EOF'
{
  "receiver": "sms-aither",
  "status": "firing",
  "alerts": [
    {
      "status": "firing",
      "labels": {
        "alertname": "EventInfrastructureDeployment",
        "instance": "production-proof"
      },
      "annotations": {}
    }
  ],
  "groupLabels": {},
  "commonLabels": {},
  "commonAnnotations": {},
  "externalURL": ""
}
EOF

STATUS="$(${CURL:-curl} \
  --silent --show-error \
  --output "$RESPONSE" \
  --write-out '%{http_code}' \
  --config "$AUTH_CONFIG" \
  --header 'Content-Type: application/json' \
  --data-binary "@$PROOF_BODY" \
  http://127.0.0.1:5000/alert)"

test "$STATUS" = 202
```

Record only the nonsensitive message ID from the protected response file. On
the PRG APU, locate that ID with
`vpsfree-sms-gatewayctl outbound list --source alertmanager` and require its
final state to become `sent`. Confirm:

- the recipient received exactly one SMS with the deployment marker;
- the sent metric increased on PRG;
- neither BRQ nor the Nexmo fallback sent a duplicate; and
- both Prometheus instances still report both gateways up.

Record the configuration and SMS gateway revisions, all six active and
rollback generation IDs, probe results, gateway message ID, final state,
receipt confirmation, Prometheus query result and any warnings. Do not record
tokens, phone numbers or message response bodies.

The infrastructure phase is now complete. Stop here and leave the final
decision to begin the vpsAdmin maintenance runbook to the operator.
