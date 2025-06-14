#!/usr/bin/env bash

set -e

echo "Removing build machine generations"
confctl generation rotate --no-gc -lr -t build

echo "Removing generations of netbooted machines"
confctl generation rotate --no-gc -lr -t pxe-primary

echo "Collecting garbage"
confctl collect-garbage -t build
