# mx2: CentOS to NixOS

## Applicability

Use this guide when replacing a CentOS mx2 host with the NixOS container, restoring
CentOS state, or recovering a transition that retains mail on either host. The
retirement status of this path is unresolved; retain these requirements until
the owning maintainer confirms that old state, backup restoration and rollback
no longer need them.

## Transition and recovery

Apply the [mx2 deployment prerequisites](../mx2.md#deployment-prerequisites-and-recovery),
including real-network checks and a trusted ACME certificate before public SMTP
ingress. The isolated check does not verify production routing or primary-side
acceptance.

Postfix keeps its queue and data under `/var/lib/postfix`; Postgrey keeps its
database under `/var/postgrey`. Retain `system.stateVersion = "25.05"` for the
imported container. Do not copy a CentOS queue or database into these paths
without a separately verified migration. Drain the old host through SMTP and
retain its disk for recovery. If ingress is reverted after NixOS accepts mail,
keep and drain that queue too; a NixOS generation rollback does not restore the
old CentOS system. SMTP retries can duplicate mail after an ambiguous reply.
