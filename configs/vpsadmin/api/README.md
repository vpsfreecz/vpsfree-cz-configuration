# Configs for vpsAdmin-api used by vpsFree.cz

## `dataset_plans.rb`

A set of dataset plans available for user or admins. Plans are used to schedule
snapshots and transfers to a backup server.

## `dataset_properties.rb`

A set of dataset properties that vpsAdmin manages. Adding and removing
properties hass to come with a database migration to add/delete necessary
records to model DatasetProperty.

## `hooks.rb`
Use hooks fired by vpsAdmin-api.

 - DatasetInPool:create - create a backup dataset, add dataset plans in production
 - User:create - create a NAS dataset


## Abuse notices

`incident_reports.rb` routes RT mail to the provider parsers in
`abuse_notice_parser/`. The handler returns an array of incidents to vpsAdmin,
which sends each incident to its own user.

### MasterDC UCEPROTECT

The UCEPROTECT parser accepts explicit source IP lists in Czech or English
notices and all rows of tables beginning with `IP,LAST IMPACT TIMESTAMP,`.
Address lists can use commas, semicolons, `a`, or `and`, including line wrapping.
Addresses in mail headers, URLs, and signatures do not create incidents.

Each distinct IP and detection time produces a separate incident, even when
several IPs belong to one user or VPS. Ownership is looked up at the detection
time. CSV timestamps take precedence over prose mentions of the same IP; an
empty timestamp uses the message date. An invalid CSV timestamp does not fall
back to prose. Duplicate entries in the same message are suppressed, while
separate timestamped events remain separate incidents. CSV `0.0.0.0` rows are
ignored as sentinels.

A single IP in the subject is a fallback when the body contains no recognized report
data. It never restricts which body entries are processed. Contradictions
between the subject and body are logged. Subject-only address lists are rejected
for manual review rather than selecting one address. An unparseable subject
suffix also disables original-text reuse for valid body entries.

Multi-entry notices use generated incident subjects and text containing the
selected IP, detection time, and that entry's CSV IP/timestamp fields when
available. Other CSV fields and the complete original message remain in RT.
Unambiguous single-entry notices retain the original subject and body. Evidence
is split before ownership lookup so an unassigned second IP is not disclosed
to the user of the first IP.

Invalid addresses or dates, missing assignments, and invalid incident lengths
are logged and skipped; independent valid entries are processed. A malformed
CSV table is rejected as a whole. Because its row boundaries are unknown, prose
in that same decoded MIME section is also excluded from fallback; other valid
tables and independent MIME sections can still be processed. Tables end at an
empty line or another recognized CSV header. The standard `--` signature marker
ends report extraction in that section.

Each rejection includes the RT ticket or subject reference, Message-ID, source
location, and reason. The final log line counts created incidents (proposed
incidents in a dry run), duplicates, ignored sentinels, and rejected entries or
tables. The existing handler marks a matched MasterDC message as handled even
if some or all entries are rejected. This flag is not a completeness guarantee.

### Verification and recovery

Run the parser suite in the configuration development shell:

```bash
nix develop -c bundle exec rake spec
```

The vpsAdmin mail task deletes fetched messages independently of parser success
when running with `EXECUTE=yes`. A false `processed?` result does not retain mail
for retry. Dry runs leave mail and incident records unchanged.

Use the original RT ticket to investigate rejected entries. Before manually
reprocessing a report, inspect the incidents already created and select only
missing entries. There is no cross-message deduplication or automatic retry in
this parser. Database and notification failures retain the existing vpsAdmin
error behavior and can require checking which records or notifications already
succeeded before recovery.

The parser uses the existing vpsAdmin incident-array interface and needs no
schema migration or coordinated node update. Deploy it with the API's
configuration. Rolling back restores the previous parser behavior; it does not
remove incidents or retract notifications already sent.
