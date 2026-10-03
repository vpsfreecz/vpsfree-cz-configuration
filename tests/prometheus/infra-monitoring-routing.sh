#!/usr/bin/env bash
set -euo pipefail

check() {
  local receivers="$1"
  shift
  amtool config routes test --config.file="$ALERTMANAGER_CONFIG" \
    --verify.receivers="$receivers" alertname=FilesystemCritFreeSpace \
    instance=test:9100 frequency=hourly "$@"
}

with_sms=team-mail,team-telegram,sms-aither,sms-snajpa

check "$with_sms" job=infra machine_type=vps alertclass=fsavail severity=critical
for mountpoint in / /run /nix/store; do
  check "$with_sms" job=infra machine_type=vps alertclass=fsavail \
    severity=critical "mountpoint=$mountpoint"
done
for machine_type in vm physical unknown vmx; do
  check "$with_sms" job=infra "machine_type=$machine_type" alertclass=fsavail severity=critical
done
check "$with_sms" job=infra alertclass=fsavail severity=critical
for job in infra nodes mon meet-jvbs; do
  check "$with_sms" "job=$job" machine_type=vps alertclass=fsavail severity=critical
  check "$with_sms" "job=$job" machine_type=vps alertclass=fsavail severity=fatal
  check team-mail "job=$job" machine_type=vps alertclass=fsavail severity=warning
done
check "$with_sms" job=infra machine_type=vps alertclass=cpuload severity=critical
check "$with_sms" job=infra machine_type=vps severity=critical
check "$with_sms" machine_type=vps alertclass=fsavail severity=critical
check "$with_sms" job=infra machine_type=vps alertclass=fsavail severity=fatal
check team-mail job=infra machine_type=vps alertclass=fsavail severity=warning
check blackhole job=infra machine_type=vps alertclass=fsavail severity=none
