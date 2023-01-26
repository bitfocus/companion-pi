#!/usr/bin/env bash
set -e

# this is the bulk of the update script
# It is a separate file, so that the freshly cloned copy is invoked, not the old copy

# imitiate the fnm setup done in .bashrc
export FNM_DIR=/opt/fnm
export PATH=/opt/fnm:$PATH
eval "`fnm env`"

# The version can be the first argument, or we can prompt for it
SELECTED_BRANCH=$1

# update the node version
fnm use --install-if-missing
fnm default $(fnm current)
npm --unsafe-perm install -g yarn

# TODO - cleanup old versions?

# Run interactive version picker
yarn --cwd "/usr/local/src/companionpi/update-prompt" install
node "/usr/local/src/companionpi/update-prompt/main.js" $1

# Get result
if [ -f /tmp/companion-version-selection ]; then
    SELECTED_URL=$(cat /tmp/companion-version-selection)
    rm /tmp/companion-version-selection 2&>/dev/null || true
fi

if [ -n "$SELECTED_URL" ]; then 
    echo "Installing from $SELECTED_URL"

    # download it
    wget "$SELECTED_URL" -O /tmp/companion-update.tar.gz -q  --show-progress

    echo "Extracting..."
    rm -R /tmp/companion-update || true
    mkdir /tmp/companion-update
    tar -xzf /tmp/companion-update.tar.gz --strip-components=1 -C /tmp/companion-update
    rm /tmp/companion-update.tar.gz

    rm -R /opt/companion || true
    mv /tmp/companion-update/resources /opt/companion
    rm -R /tmp/companion-update

    echo "Finishing"
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

# install some scripts
ln -s -f /usr/local/src/companionpi/companion-license /usr/local/bin/companion-license
ln -s -f /usr/local/src/companionpi/companion-help /usr/local/bin/companion-help
ln -s -f /usr/local/src/companionpi/companion-update /usr/local/sbin/companion-update
ln -s -f /usr/local/src/companionpi/companion-reset /usr/local/sbin/companion-reset

# install the motd
ln -s -f /usr/local/src/companionpi/motd /etc/motd 
