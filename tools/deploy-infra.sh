#!/usr/bin/env bash

set -e

reboot=n

while [ $# -gt 0 ]; do
    case "$1" in
        -r|--reboot)
            reboot=y
            ;;
        *)
            echo "Unknown option/argument '$1'"
            exit 1
            ;;
    esac

    shift
done

if [ "$reboot" == y ]; then
    echo "Performing update by reboot"
else
    echo "Performing update at runtime (no reboots)"
fi

sleep 1


echo "Performing auto-updates"
confctl deploy -y -t auto-update --copy-only '*'

if [ "$reboot" == y ]; then
    confctl deploy -t auto-update -g current --one-by-one --reboot '*' boot
else
    confctl deploy -t auto-update -g current --one-by-one
fi


echo "Performing manual-updates"
confctl deploy -t manual-update '*' boot

echo "Updating internal DNS resolvers"

if [ "$reboot" == y ]; then
    confctl deploy -g current -t internal-dns --one-by-one --reboot '*' boot
else
    confctl deploy -g current -t internal-dns --one-by-one
fi


echo "Deploying VPN"

if [ "$reboot" == y ]; then
    confctl deploy -i --reboot cz.vpsfree/machines/prg/int.vpn boot
else
    confctl deploy cz.vpsfree/machines/prg/int.vpn
fi


echo "Deploying APUs"
confctl build -t apu
confctl deploy -t apu -g current --copy-only -y

if [ "$reboot" == y ]; then
    confctl deploy -t apu -g current -i --one-by-one --reboot '*' boot
else
    confctl deploy -t apu -g current --one-by-one
fi
