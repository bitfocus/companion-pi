#!/bin/bash

# Given the new defaut of expecting ipv6 to be enabled, handle its absence
ADMIN_ADDRESS=""
inet6=$(/usr/sbin/ip a 2>&1 | grep -c 'inet6')
if [ $inet6 -eq 0 ]; then
    ADMIN_ADDRESS="--admin-address 0.0.0.0"
fi

if [ -d /usr/local/src/companion ]; then
    # Found an old 2.x installation, that must be what is still installed
    cd /usr/local/src/companion

    if [ -f "UPDATE_IN_PROGRESS" ]; then
        echo "Companion can not be started, an update operation was interrupted."
        exit 5
    fi

    # run it!
    /opt/fnm/aliases/default/bin/node headless_ip.js 0.0.0.0
else
    # No 2.x, so we can assume its modern!
    cd /opt/companion

    # node binary path could be different since v3.5
    NODE_EXE=/opt/companion/node-runtime/bin/node
    if ! [ -d /opt/companion/node-runtime ]; then
        NODE_EXE=/opt/companion/node-runtimes/main/bin/node
    fi

    $NODE_EXE /opt/companion/main.js --extra-module-path /opt/companion-module-dev $ADMIN_ADDRESS
fi
