#!/usr/bin/env bash
set -e

# this is the bulk of the update script
# It is a separate file, so that the freshly cloned copy is invoked, not the old copy

# imitiate the fnm setup done in .bashrc
export FNM_DIR=/opt/fnm
export PATH=/opt/fnm:$PATH
eval "`fnm env`"

# ensure the module dev folder exists
if [ ! -d /opt/companion-module-dev ]; then
    mkdir /opt/companion-module-dev
fi

# check if the conversion to v3 is required
if [ -d "/usr/local/src/companion" ]; then
    echo "In order to proceed, your Companion-Pi installation must be converted to make it compatible with Companion 3.0"
    echo -e "\e[1;31;40mThis cannot be undone\e[0m"

    echo ""
    echo "Companion 3.0 has not been released as stable. Doing this conversion now will result in running a beta version"

    echo ""
    echo "A backup of your configuration will be made for you, which you should take a copy of in case you wish to downgrade"
    echo "Any modules you have installed locally will be deleted, as they are not compatible without updates"
    echo ""

    function ask_yes_or_no() {
        read -p "$1 ([y]es or [N]o): "
        case $(echo $REPLY | tr '[A-Z]' '[a-z]') in
            y|yes) echo "yes" ;;
            *)     echo "no" ;;
        esac
    }

    echo "Are you sure you want to upgrade your installation?"
    if [[ "no" == $(ask_yes_or_no "") ]]
    then
        echo "Abort."
        exit 0
    fi

    # make copy of config
    echo "Backing up configuration to /home/pi/companion-config-backup.zip"
    rm -f /home/pi/companion-config-backup.zip
    zip /home/pi/companion-config-backup.zip -r /home/companion/companion
    chown pi:pi /home/pi/companion-config-backup.zip

    echo "Cleaning up old installation"
    rm -Rf /usr/local/src/companion
fi

# update the node version
fnm use --install-if-missing --silent-if-unchanged
fnm default $(fnm current)
npm --unsafe-perm install -g yarn &>/dev/null

# TODO - cleanup old versions?

# Run interactive version picker
yarn --cwd "/usr/local/src/companionpi/update-prompt" --silent install
node "/usr/local/src/companionpi/update-prompt/main.js" $1

# Get result
if [ -f /tmp/companion-version-selection ]; then
    SELECTED_URL=$(cat /tmp/companion-version-selection)
    rm -f /tmp/companion-version-selection
fi

if [ -n "$SELECTED_URL" ]; then 
    echo "Installing from $SELECTED_URL"

    # download it
    wget "$SELECTED_URL" -O /tmp/companion-update.tar.gz -q  --show-progress

    # extract download
    echo "Extracting..."
    rm -R -f /tmp/companion-update
    mkdir /tmp/companion-update
    tar -xzf /tmp/companion-update.tar.gz --strip-components=1 -C /tmp/companion-update
    rm /tmp/companion-update.tar.gz

    # copy across the useful files
    rm -R -f /opt/companion
    mv /tmp/companion-update/resources /opt/companion
    rm -R /tmp/companion-update

    echo "Finishing"
else
    echo "Skipping update"
fi

# update some tooling
cd /usr/local/src/companionpi
cp 50-companion.rules /etc/udev/rules.d/
udevadm control --reload-rules || true
cp 090-companion_sudo /etc/sudoers.d/
if [ $(getent group gpio) ]; then
  adduser -q companion gpio
fi
if [ $(getent group dialout) ]; then
  adduser -q companion dialout
fi


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
