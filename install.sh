#!/usr/bin/env bash
set -e

echo "This will attempt to install Companion as a system service on this device."
echo "It is designed to be run on headless servers, but can be used on desktop machines if you are happy to not have the tray icon."
echo "A user called 'companion' will be created to run the service, and various scripts will be installed to manage the service"

if [ $(/usr/bin/id -u) -ne 0 ]; then
    echo "Must be run as root"
    exit 1
fi

COMPANIONPI_BRANCH="${COMPANIONPI_BRANCH:-main}"
COMPANION_BRANCH="${COMPANION_BRANCH:-beta}"

# add a system user
adduser --disabled-password companion --gecos ""

# install some dependencies
apt-get update
apt-get install -y git unzip curl libusb-1.0-0-dev libudev-dev
apt-get clean

# install fnm to manage node version
# we do this to /opt/fnm, so that the companion user can use the same installation
export FNM_DIR=/opt/fnm
echo "export FNM_DIR=/opt/fnm" >> /root/.bashrc
curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /opt/fnm
export PATH=/opt/fnm:$PATH
eval "`fnm env --shell bash`",

# clone the companionpi repository
git clone https://github.com/bitfocus/companion-pi.git -b $COMPANIONPI_BRANCH /usr/local/src/companionpi
cd /usr/local/src/companionpi

# configure git for future updates
git config --global pull.rebase false

# run the update script
./update.sh $COMPANION_BRANCH

# install update script dependencies, as they were ignored
yarn --cwd "/usr/local/src/companionpi/update-prompt" install

# enable start on boot
systemctl enable companion


# add the fnm node to this users path
# TODO - verify permissions
echo "export PATH=/opt/fnm/aliases/default/bin:\$PATH" >> /home/companion/.bashrc

echo "Companion is installed!"
echo "You can start it with \"sudo systemctl start companion\" or \"sudo companion-update\""