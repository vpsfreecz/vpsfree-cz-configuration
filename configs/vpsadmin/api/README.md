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

### SSH and structured reports

The handler recognizes the provider profiles below. The RT originator must match
unless `CHECK_SENDER` disables identity checks for diagnostics. This check selects
a provider within trusted RT ingestion; it does not verify the report's claims.

| Provider | RT originator | Source and event time |
| --- | --- | --- |
| Blocklist.de | `abuse-team@blocklist.de` | XARF 0.2 `report.txt` source and complete RFC 2822 or ISO date |
| CEDO | `www-root@cedo.com` | XARF 0.2 `report.txt` source and complete date |
| Provider.tools | `noreply@provider.tools` | Inline `X-XARF: PLAIN` source and summary `Last seen` |
| LRob/Shieldlist | `abusereport@lrob.net` | `connection/login_attack` XARF 4.2.0 `xarf.json` source and `timestamp` |
| Cisilino | `notifiche@cisilino.com` | Matching source slots in the bilingual subject and explicit UTC `Last seen` |
| Custom Visuals | `abuse@customvisuals.com` | Subject source and numeric-offset timestamp prefix in the designated last-log section |

Fail2Ban also recognizes the Burina `Abuse from IP` format under its existing
sender policy. The subject identifies the source; the latest syslog timestamp
prefix in the report's log section determines the incident time. The numeric
timezone note and message Date determine the year: exactly one candidate from
adjacent years must be nonfuture and within 31 days of the message Date. Invalid
or out-of-window timestamp prefixes reject the report. The rest of each record
is preserved without interpreting its SSH message, username or source address.
The original Fail2Ban format and Apache logs remain supported.

Each valid report creates at most one incident. The parser looks up the reported
source's historical assignment once, at the selected event time. A missing
assignment produces no incident. Overlapping reports in separate messages remain
separate incidents.

The incident retains the original subject after removing the RT prefix and the
decoded human body after removing the RT wrapper. Direct plain-text attachments
are appended, including structured reports and complete log files. LRob appends
its decoded `text/plain` evidence without the JSON envelope or Base64 encoding.
Existing line-ending and outer-whitespace normalization applies; wording and
internal wrapping are preserved. An exact text section already present in the
body is not appended again. HTML, binary attachments and nested or forwarded MIME
messages are not included.

The entire readable report goes to the owner selected at the event time. It may
include earlier activity, repeated records or mentions of other IPs. The parser
does not split or filter evidence by assignment or reject a report merely because
its contents span reassignments. Individual log messages cannot change the
reported source, though a later syslog prefix in Burina's log section can change
the selected event time.

Only the required source, selected time, provider identity and report structure
are validated. Missing, duplicate, invalid or conflicting required metadata and
competing required MIME sections reject the report without an alternate IP/date
fallback. Blocklist.de/CEDO use the structured date; Provider.tools uses `Last
seen`. Other dates, counts, services, translations and sample messages remain
forwarded content. These profiles do not interpret YAML or fetch links. LRob
checks JSON sender/reporter contacts and decodes MIME and evidence Base64
separately; malformed JSON/Base64, duplicate JSON keys and unsupported evidence
types are rejected.
A feedback MIME part is not required. The existing XArfDecoder schema checks
remain in force, including standard optional field types; only the adapter's
unused range extensions are left uninterpreted. Abusix and Netcraft handling,
including Netcraft reminder subjects and deduplication, stays unchanged.

Empty optional logs or evidence are accepted when readable report content is
present. Report sections, JSON and decoded evidence are limited to 1 MiB. The
original stripped subject is limited to 255 characters and final text to 65,535
bytes; both must be compatible with utf8mb3. Oversized or unrepresentable content
is rejected without truncation or replacement summaries. Fractional event times
are kept for assignment lookup; stored precision depends on the existing database
column. These parsers require no schema change.

Rejection diagnostics identify the provider, RT ticket and reason without copying
bulk evidence. Malformed new provider profiles return `processed? == false`.
Matched Fail2Ban notices retain their existing handled semantics. `processed?`
does not guarantee that an incident was created or retain mail for retry.

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
