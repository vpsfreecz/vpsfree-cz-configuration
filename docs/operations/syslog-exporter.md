# Syslog exporter on the central log host

`log.int.prg.vpsfree.cz` receives remote syslog and exposes Prometheus metrics on
TCP port 9102. The configuration machine is
`cz.vpsfree/containers/prg/int.log`. Building a candidate does not authorize
deployment; obtain approval before replacing the service.

## Runtime contract

`services.prometheus.confExporters.syslog` selects the package, account,
listening address and port, working directory and JSON settings. By default, the
service runs `syslog-exporter --config PATH --listen ADDRESS:PORT` as
`syslog-exporter`, using `/var/syslog-exporter` as its working directory. The directory remains for
compatibility; the exporter persists no metrics or ingestion cursor there.

Tmpfiles manages `/var/log/rsyslog.pipe` as a FIFO with mode 0640 and owner
`root:syslog-exporter`. The executable opens an existing FIFO; it does not create
or replace it. Keep that ownership separate from the `log-readers` group used
for archived logs. Preserve the restricted log-reader access and rotation rules
in [log-reader access](log-reader-access.md).

The systemd unit remains `prometheus-syslog-exporter.service`. It uses
`Type=simple`, restarts on failure after 30 seconds, and has no readiness or
watchdog notification protocol. An active unit and successful HTTP scrape alone
do not prove that incoming records are being consumed.

Rsyslog receives TCP 11514 and UDP 11515, writes remote files and forwards records
to the FIFO. Local messages also reach the FIFO. The unchanged default pipe
format is `RSYSLOG_FileFormat`: RFC3339 timestamp, hostname, tag and message,
terminated by LF. The rsyslog package's message-size limit and control-character
escaping apply before the exporter sees a record. The exporter bounds its own
framing buffer separately. See the exporter's documentation for parsing,
diagnostics and the supported frame limit.

Keep generated `settings.hosts` identities, OS values and collector opt-ins.
Monitoring scrapes HTTP `/metrics` every 60 seconds with job `log`; existing
metric names, labels, gauge lifetimes and counter behavior are compatibility
contracts for `modules/clusterconf/monitor/rules/syslog.nix`.

## Delivery limits

The FIFO has no acknowledgement or durable cursor. The central ompipe action
has no configured disk queue or retry override. The configured rsyslog
implementation uses a nonblocking write: a full pipe suspends the action,
and a positive short write is not retried. A stopped or slow reader, a process
restart or an oversize record can therefore cause missing or incomplete metric
events. The sender's TCP forwarding queue does not guarantee delivery through
the central FIFO. UDP can also lose messages before central reception.

Archived files are a separate output, not an automatic replay source. Exporter
counters and temporary gauges reset on restart. Two readers on one FIFO divide
the records between them; never compare implementations by attaching both to the
live pipe. Use isolated replay FIFOs or an explicitly duplicated disposable
producer configuration for comparison.

## Prepare a candidate

Enter this repository's environment with `nix develop`. Keep the exact exporter
source revision, source hash and Cargo dependency hash in
`packages/syslog-exporter/default.nix`. Use the configuration's pinned stable
Rust toolchain; an exporter update does not require updating fleet channels.

Before changing a deployed service:

1. Evaluate the log host's generated JSON, systemd command, account and tmpfiles
   rules. Check the package pin, port, collector selection and existing alerts.
2. Build the package and then `confctl build cz.vpsfree/containers/prg/int.log`.
   Record the package and system store paths and the complete source/input graph
   outside this repository, alongside review and verification evidence.
3. Run the exporter's contract tests and isolated producer/consumer checks.
   Compare submitted, archived, FIFO-observed and accepted records separately.
   Exercise finite bursts, slow readers, overflow and restarts with the pinned
   rsyslog package. Test scrape responsiveness during the same workload.
4. Establish the actual deployed system generation before replacement, retaining
   its exact system closure and exporter package. For a Ruby-to-Rust transition,
   retain the Ruby closure as rollback material. Check the working directory for
   unexpected operator-managed files; preserve them and the FIFO/log paths.
5. Obtain deployment approval and the required machine ownership before any
   activation. Keep build preparation separate from activation. Default-branch
   integration requires its own explicit approval.

A passing package build or HTTP check does not establish a supported burst rate
or zero-loss behavior. Keep the measured envelope and remaining gaps in the
rollout record. Avoid synthetic fatal/OOM events in production monitoring.

## Authorized replacement and verification

With approval for the exact host and candidate, use the normal confctl deployment
procedure. Keep one FIFO reader: stop the old exporter before starting its
replacement. Avoid an rsyslog restart when the configuration does not require
one, and record the service gap and any actual producer restart.

Check both `syslog.service` and `prometheus-syslog-exporter.service`, continuing
file writes, FIFO diagnostics and HTTP `/metrics`. Verify expected host labels,
collector selection and existing alert expressions over several 60-second
scrapes and a complete 240-second flare window. A green `up` series covers HTTP
availability, so also verify that new records reach the counters.

Retain exact old/new package and system paths, input identities and observed
results in the rollout record. Do not remove the rollback closure while recovery
still depends on it.

## Rollback

If the replacement cannot consume records or serve compatible metrics, stop its
reader and reactivate the retained prior system closure through the normal
approved deployment procedure. Restore the old package and service command as a
unit; changing only the binary can leave incompatible launch arguments.

Keep `/var/log/rsyslog.pipe`, `/var/syslog-exporter`, archived logs, ownership and
rotation configuration. There is no exporter state conversion or data deletion.
Recheck service status, file logging, incoming metric updates and scrape labels
after recovery. Counters and gauges restart from their initial values; rollback
cannot recover metric events already lost through the FIFO.
