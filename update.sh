#!/bin/bash -e

# this is the bulk of the update script
# It is a separate file, so that the freshly cloned copy is invoked, not the old copy

# imitiate the fnm setup done in .bashrc
export FNM_DIR=/opt/fnm
export PATH=/opt/fnm:$PATH
eval "`fnm env`"

# update companion soruce
cd /usr/local/src/companion
git fetch --all
GIT_BRANCH=$(git branch --show-current)
if [[ "$GIT_BRANCH" != "" ]]; then
    # only do a pull if on a branch
    git pull
fi

# TODO - prompt for which branch to use

# update the node version
fnm use --install-if-missing
fnm default $(fnm current)
npm --unsafe-perm install -g yarn

# install dependencies
yarn config set network-timeout 100000 -g
yarn update

# update some tooling
cd /usr/local/src/companionpi
cp 50-companion.rules /etc/udev/rules.d/
udevadm control --reload-rules

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
