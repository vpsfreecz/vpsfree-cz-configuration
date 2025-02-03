#!/usr/bin/env bash

set -e

echo "Performing auto-updates"
confctl build -y -t auto-update --copy-only '*'
confctl deploy -t auto-update -g current --one-by-one --reboot '*' boot

echo "Performing manual-updates"
confctl deploy -t manual-update '*' boot

echo "Updating internal DNS resolvers"
confctl deploy -g current -t internal-dns --one-by-one --reboot '*' boot

echo "Deploying VPN"
confctl deploy -i --reboot cz.vpsfree/machines/prg/int.vpn boot

echo "Deploying APUs"
confctl build -t apu
confctl deploy -t apu -g current --copy-only -y
confctl deploy -t apu -g current -i --one-by-one --reboot '*' boot
