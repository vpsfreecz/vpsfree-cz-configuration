#!/usr/bin/env bash

set -e

echo "Performing auto-updates"
confctl deploy -t auto-update --one-by-one --reboot '*' boot

echo "Performing manual-updates"
confctl deploy -t manual-update --one-by-one '*' boot

echo "Updating internal DNS resolvers"
confctl build -t internal-dns
amtool silence add --duration=5m "severity=~critical|fatal"
confctl deploy -g current -t internal-dns --one-by-one --reboot '*' boot

echo "Deploying VPN"
confctl deploy --reboot cz.vpsfree/machines/prg/int.vpn boot

echo "Deploying APUs"
confctl deploy -t apu --reboot '*' boot
