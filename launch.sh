#!/bin/bash

# Check if IPv6 is avialable on this system
inet6=$(ip a | grep -c inet6)
if [ $inet6 -eq 0 ]; then
    export DISABLE_IPV6="1"
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

    if [ -f /opt/companion/config-tool.js ]; then
        # New releases: derive env + flags from the config file.
        # `generate` runs in a subshell and exits; `exec` then replaces this
        # script, so the final process tree is just `node main.js`.
        export COMPANION_CONFIG_FILE=/etc/companion/config.yaml
        source <($NODE_EXE /opt/companion/config-tool.js generate)

        exec $NODE_EXE /opt/companion/main.js "$@"
    else
        # Older releases (no config-tool): existing behaviour, unchanged.
        export COMPANION_ENABLE_SHELL_COMMAND_SUPPORT=1
        export COMPANION_ENABLE_RESTRICTED_MODULES=1
        
        exec $NODE_EXE /opt/companion/main.js --extra-module-path /opt/companion-module-dev "$@"
    fi
fi
