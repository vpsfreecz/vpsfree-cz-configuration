<a id="configs-for-vpsadmin-api-used-by-vpsfreecz"></a>

# vpsAdmin API configuration for vpsFree.cz

For the optional documentation sign-in hook, client registration and private
file provisioning, see [API documentation OAuth](../../../docs/operations/vpsadmin-documentation-oauth.md).

## `dataset_plans.rb`

A set of dataset plans available to users or admins. Plans are used to schedule
snapshots and transfers to a backup server.

## `dataset_properties.rb`

A set of dataset properties that vpsAdmin manages. Adding and removing
properties requires a database migration to add or delete the necessary
records in the DatasetProperty model.

## `hooks.rb`

Hooks fired by vpsAdmin-api:

- DatasetInPool:create - create a backup dataset, add dataset plans in production
- User:create - create a NAS dataset

## `incident_escalation.rb`

This file declares the `oomd` policy with bilingual labels, base limits of 3
incidents in 7 days for a warning and 10 in 30 days for a stop, and the existing
memory-pressure templates. Its explicit selector requires the `oomd` codename,
`node_vps_event` provenance, a source key, the VPS's bound source node and a
`restart` or `stop` action. These are facts from the authenticated node channel,
not independent evidence of memory pressure. Manual reports named `oomd` do not
match this site rule.

Every ordinary IncidentReport creation evaluates all configured policies. A rule
can select manual or imported categories without a backend change; declarations
use `rule :key do ... end` without an adapter. An absent selector matches every
ordinary report. Selectors receive deeply frozen plain `ctx.report`, `ctx.source`,
VPS/owner, time, counts and settings values; see the backend
[incident escalation reference](https://github.com/vpsfreecz/vpsadmin/blob/2026-10-30-oomd-abuse-policy/docs/incident-escalation.md)
for their exact fields and a two-policy non-OOM example. Return `true` or `false`.
Do not query databases or services, run commands or perform actions in selectors.
Unsaved parser dry runs do not evaluate policies. Updates, reads, retries,
scheduled processing and configuration changes never rerun matching or adopt old
reports. Selector side effects are unsupported because a rolled-back transaction
can retry creation.

A non-null global limit overrides the Ruby base; an explicit per-VPS limit
applies last. Null means inherit. Existing non-null values remain in effect, even
when they equal former defaults, so they can mask edits to the Ruby limits.
Clear an override through an explicit audited settings change. The global mode
remains a permission ceiling, and a VPS exemption prevents automatic stops.
Loading this file does not reset either setting.

The existing API and supervisor `configDirectory` settings distribute this same
directory. Restart all API, supervisor and task processes after changing the
file, then verify that they loaded the same policy identity before enabling
notifications or stops. There is no hot reload. Even a comment-only edit changes
the file identity and suppresses old decisions that have not been dispatched.
Editing the policy cannot recall queued or uncertain effects; those still need
the normal reconciliation process.

Before activating this file, including in observe mode, install a compatible
backend and schema, matching mail templates and compatible readers. Install the
backend's `create_incident_report` RPC support before upgrading nodectl, and retire
direct-SQL incident-report writers when activating these policies. Current
limits and status come from the declaration and overrides, even before any
incident matches. Invalid override combinations report `configuration_valid=false`
with null effective limits and status. Clients must check this flag before using
those values; the generated Go client's scalar fields decode null as zero or an
empty string. A saved evaluation describes a past decision and does not supply
current limits. Reaching a threshold does not guarantee a stop.

When the file is absent or declares no rules, there are no active policies.
Saved settings, evaluations and already submitted effects remain available. An invalid file prevents startup.
Removing the file does not reverse saved history or effects. Rollback requires
a backend and schema that support saved policy evaluations, nullable overrides
and notice privacy; an arbitrary older backend is not a safe rollback target.

## Abuse notices

`incident_reports.rb` routes RT mail to the provider parsers in
`abuse_notice_parser/`. The handler returns an array of incidents to vpsAdmin,
which sends each incident to its own user. See [abuse notice processing](abuse-notices.md)
for provider matching, historical ownership, evidence disclosure and failure
semantics, and the [operator runbook](../../../docs/operations/vpsadmin-abuse-notices.md)
for checks and recovery.

### SSH and structured reports

See [SSH and structured reports](abuse-notices.md#ssh-and-structured-reports).

### MasterDC UCEPROTECT

See [MasterDC UCEPROTECT](abuse-notices.md#masterdc-uceprotect).

### Verification and recovery

See the [abuse notice runbook](../../../docs/operations/vpsadmin-abuse-notices.md)
and [mail processing and recovery limits](abuse-notices.md#mail-processing-and-recovery-limits).
