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

This file runs trusted operator Ruby code to select the policy for VPS
memory-pressure incidents. The `oomd` rule uses the `node_oomd` source adapter,
bilingual labels and the memory-pressure warning/stopped templates. Its initial
callback sets base limits of 5 incidents in 7 days for a warning and 10 in 30 days
for a stop, follows the configured global mode and does not suppress actions.
Use only the supplied context in the callback. Do not query the database or other
services, run commands, or perform actions from it.
See the backend [incident escalation reference](https://github.com/vpsfreecz/vpsadmin/blob/2026-10-30-oomd-abuse-policy/docs/incident-escalation.md)
for the DSL, evaluation, source qualification and recovery contract.

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
backend and schema, matching mail templates and compatible readers. With any
Ruby policy file, reads report current limits and status as unknown. A saved
evaluation describes a past decision. PHP and React must handle unknown current
values. The generated Go client's scalar fields decode null as zero or an empty
string. Go consumers that use these fields must preserve
unknown values or stop interpreting them before activation. This restriction
does not affect unrelated operations.

When the file is absent, the backend uses the built-in static rule with its own
policy identity and preserves settings. An invalid file prevents startup.
Removing the file does not reverse saved history or effects. Rollback requires
a backend that supports nullable overrides and notice privacy, with the additive
schema retained; an arbitrary older backend is not a safe rollback target.

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
