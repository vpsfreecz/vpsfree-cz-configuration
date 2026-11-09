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
