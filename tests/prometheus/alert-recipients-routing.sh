#!/usr/bin/env bash
set -euo pipefail

check() {
  local receivers="$1"
  shift
  amtool config routes test --config.file="$ALERTMANAGER_CONFIG" \
    --verify.receivers="$receivers" "$@"
}

aither=machine-mail-aitherdev.int.vpsfree.cz
multi=machine-mail-node19.prg.vpsfree.cz
mail_only=machine-mail-mail-only.int.vpsfree.cz
team=team-mail,team-telegram,sms-aither,sms-snajpa

for identity in fqdn=aitherdev.int.vpsfree.cz node_fqdn=aitherdev.int.vpsfree.cz; do
  for alert in InfraHighCpuLoad InfraHighIoWait InfraExporterDown FilesystemCritFreeSpace SystemdUnitFailed; do
    for frequency in hourly daily; do
      check "$aither" "$identity" "alertname=$alert" severity=warning "frequency=$frequency"
      check "$aither,sms-aither" "$identity" "alertname=$alert" severity=critical "frequency=$frequency"
      check "$aither,sms-aither" "$identity" "alertname=$alert" severity=fatal "frequency=$frequency"
      check blackhole "$identity" "alertname=$alert" severity=none "frequency=$frequency"
    done
  done
  check "$aither" "$identity" alertname=UnknownSeverity severity=unknown
  check "$aither" "$identity" alertname=MissingSeverity
done

# The same policy covers host, management and independently reported node alerts.
for identity in fqdn=node19.prg.vpsfree.cz fqdn=node19-mgmt.prg.vpsfree.cz node_fqdn=node19.prg.vpsfree.cz; do
  check "$multi" "$identity" alertname=Warning severity=warning
  check "$multi,sms-aither,sms-snajpa" "$identity" alertname=Critical severity=critical
  check "$multi,sms-aither,sms-snajpa" "$identity" alertname=Fatal severity=fatal
  check blackhole "$identity" alertname=Inhibition severity=none
done

# Selected users without SMS get email at every notifying severity.
for severity in warning critical fatal; do
  check "$mail_only" fqdn=mail-only.int.vpsfree.cz "severity=$severity"
done
check blackhole fqdn=mail-only.int.vpsfree.cz severity=none

# Subject identity takes precedence over the scrape host, including unmarked nodes.
check "$multi,sms-aither,sms-snajpa" fqdn=aitherdev.int.vpsfree.cz \
  node_fqdn=node19.prg.vpsfree.cz severity=critical
check "$team" fqdn=aitherdev.int.vpsfree.cz node_fqdn=normal.int.vpsfree.cz severity=critical
check "$team" fqdn=aitherdev.int.vpsfree.cz node_fqdn=unknown.int.vpsfree.cz severity=fatal
check "$aither,sms-aither" fqdn=node19.prg.vpsfree.cz \
  node_fqdn=aitherdev.int.vpsfree.cz severity=critical
check "$aither,sms-aither" fqdn=aitherdev.int.vpsfree.cz node_fqdn= severity=critical

# Unmarked and lookalike systems, plus global alerts, keep team routing.
for fqdn in normal.int.vpsfree.cz unknown.int.vpsfree.cz aitherdev2.int.vpsfree.cz aitherdev.int.vpsfree.cz.example; do
  check team-mail "fqdn=$fqdn" severity=warning
  check "$team" "fqdn=$fqdn" severity=critical
  check "$team" "fqdn=$fqdn" severity=fatal
  check blackhole "fqdn=$fqdn" severity=none
done
check "$team" alertname=GlobalCritical severity=critical
check team-mail alertname=GlobalUnknown severity=unknown
