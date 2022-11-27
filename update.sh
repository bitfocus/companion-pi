#!/usr/bin/env bash
set -e

# this is the bulk of the update script
# It is a separate file, so that the freshly cloned copy is invoked, not the old copy

# imitiate the fnm setup done in .bashrc
export FNM_DIR=/opt/fnm
export PATH=/opt/fnm:$PATH
eval "`fnm env`"

# update companion soruce
cd /usr/local/src/companion
git fetch --all

# The version can be the first argument, or we can prompt for it
SELECTED_REF=$1
if [ -z "$SELECTED_REF" ]; then
    # Run interactive version picker
    yarn --cwd "/usr/local/src/companionpi/update-prompt" install
    node "/usr/local/src/companionpi/update-prompt/main.js"

    # Get result
    if [ -f /tmp/companion-version-selection ]; then
        SELECTED_REF=$(cat /tmp/companion-version-selection)
        rm /tmp/companion-version-selection 2&>/dev/null || true
    fi
fi

if [ -n "$SELECTED_REF" ]; then 
    # companion is not safe to be started
    touch /usr/local/src/companion/UPDATE_IN_PROGRESS

    echo "Switching to $SELECTED_REF"

    # switch to the new ref
    git checkout $SELECTED_REF
    GIT_BRANCH=$(git branch --show-current)
    if [[ "$GIT_BRANCH" != "" ]]; then
        # only do a pull if on a branch
        git pull
    fi

    # update the node version
    fnm use --install-if-missing
    fnm default $(fnm current)
    npm --unsafe-perm install -g yarn

    # make sure there is a swap file in case there is not enough memory
    SWAPFILE="/swapfile-upgrade"
    if [ ! -f "$SWAPFILE" ]; then
        fallocate -l 2G $SWAPFILE
        chmod 600 $SWAPFILE
        mkswap $SWAPFILE
    fi
    swapon $SWAPFILE || true

    # install dependencies
    yarn config set network-timeout 100000 -g
    export NODE_OPTIONS=--max-old-space-size=8192 # some pi's run out of memory
    yarn update

    # swap is no longer needed
    swapoff $SWAPFILE || true

    # companion is safe to be started
    rm /usr/local/src/companion/UPDATE_IN_PROGRESS || true

else
    echo "Skipping update"
fi

# update some tooling
cd /usr/local/src/companionpi
cp 50-companion.rules /etc/udev/rules.d/
udevadm control --reload-rules
cp 090-companion_sudo /etc/sudoers.d/
adduser -q companion gpio
adduser -q companion dialout

# update startup script
cp companion.service /etc/systemd/system
systemctl daemon-reload

# add udevd systemd override allowing network connectivity for curl triggering surfaces update
mkdir -p /usr/lib/systemd/system/systemd-udevd.service.d/
cp /usr/local/src/companionpi/systemd-udevd-override.conf /usr/lib/systemd/system/systemd-udevd.service.d/override.conf

# install some scripts
ln -s -f /usr/local/src/companionpi/companion-license /usr/local/bin/companion-license
ln -s -f /usr/local/src/companionpi/companion-help /usr/local/bin/companion-help
ln -s -f /usr/local/src/companionpi/companion-update /usr/local/sbin/companion-update
ln -s -f /usr/local/src/companionpi/companion-reset /usr/local/sbin/companion-reset

# install the motd
ln -s -f /usr/local/src/companionpi/motd /etc/motd 
