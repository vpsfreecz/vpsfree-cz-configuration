# mx2 backup mail relay

`configs/mx2.nix` defines the mail policy shared by the production container and
the isolated VM check. It permits relay for exactly `vpsfree.cz`,
`lists.vpsfree.cz` and `vpsfree.org`, forwards them to
`prasiatko-mail.vpsfree.cz`, and opens TCP25 through the firewall. Arbitrary
subdomains do not inherit relay permission. The advertised message limit is
100 MiB, matching the primary's observed SMTP limit.

Run the isolated check from the repository root on a Linux builder with KVM:

```sh
nix build -L .#checks.x86_64-linux.mx2
```

Build the actual container separately in the development shell:

```sh
nix develop -c confctl build --yes cz.vpsfree/containers/mx2
```

The check uses three VMs: an untrusted sender and bounce sink, the candidate
relay, and a controlled Postfix receiver with local DNS. All VMs restrict host
network access, have no default route or port forwarding, and use a DNS server
without upstream forwarding. Production names resolve only to fixture addresses.
The check sends no mail to the real primary or any public recipient.

It checks domain and subdomain relay decisions, IPv4 and IPv6 SMTP, envelope
and message content, Postgrey rejection/retry and persistence, controlled DNSBL
rejection, and the missing milter's configured `accept` action. It requires a
final DATA acceptance before testing queued mail across Postfix and VM restarts,
then restores the primary and checks delivery and queue drain. Separate primary
4xx and 5xx cases exercise deferral and a delivery-status notification to the
controlled sender. A self-signed primary certificate exercises opportunistic
outbound TLS; another case disables primary STARTTLS and checks plaintext
fallback. EHLO/SIZE checks use a declared oversized length without a large body.
Each wait is bounded, with a 30-minute runtime ceiling.

The MX fixture imports the production mail module. Its only differences are
hostname, interface and resolver plumbing, a two-second Postgrey delay, shorter
queue retry/connect times and shorter policy-service failure timeouts. It keeps
relay/recipient restrictions, transport, DNSBL names, trusted-network defaults,
firewall allowance, persistent paths and the absent milter unchanged. Postgrey's
whitelist behavior remains enabled. The primary's response map, mail capture,
self-signed certificate and DNS answers are fixture services, not a reproduction
of the Debian primary's configuration.

## Deployment prerequisites and recovery

Passing this check does not verify the actual container host, addresses, routing,
DNS propagation or primary-side acceptance of the candidate. Verify those with
the built container under a separate deployment plan. Internal DNS records must
reach every configured resolver before relying on the primary transport name.

The container advertises `mx2.vpsfree.cz` and offers opportunistic inbound TLS
with a native ACME certificate. HTTP-01 issuance and renewal require public TCP80
to reach the container. Postfix waits for the local ACME bootstrap unit, which
can create a provisional self-signed certificate; it does not wait for the
separate order/renew unit. Verify a trusted certificate for `mx2.vpsfree.cz`
before opening public SMTP ingress. Renewal reloads Postfix. Outbound TLS remains
opportunistic, so a self-signed primary is compatible.
The localhost milter is absent and mail proceeds when it is unavailable; this
configuration does not provide milter scanning.

There is no primary recipient directory on the backup. Unknown recipients in
the three relay domains can be accepted and later bounced, creating a
backscatter risk. Recipient synchronization is separate follow-up work; online
primary verification alone cannot provide outage queueing.

## Persistent state and queue recovery

Postfix keeps its queue and data under `/var/lib/postfix`; Postgrey keeps its
database under `/var/postgrey`. Retain `system.stateVersion = "25.05"` for the
imported container. SMTP retries can duplicate mail after an ambiguous reply.

For a CentOS-to-NixOS transition, including restored CentOS state or recovery
that still depends on the old host, follow the
[transition and queue recovery requirements](upgrades/mx2-centos-to-nixos.md).
Keep and drain every queue that has accepted mail if ingress is reverted.
