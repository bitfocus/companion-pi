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
    echo "Companion 4.0 is available, and can be installed on Companion-Pi"
    echo -e "\e[1;31;40mThis cannot be undone\e[0m"

    echo ""
    echo "You can remain on the 2.x builds until you choose to update. It is strongly recommended to update, as 2.x is very old and the newer versions are much more powerful"

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

    echo "Do you want to upgrade your installation to 4.0?"
    if [[ "yes" == $(ask_yes_or_no "") ]]
    then
        # make copy of config
        echo "Backing up configuration to /home/pi/companion-config-backup.zip"
        rm -f /home/pi/companion-config-backup.zip
        zip /home/pi/companion-config-backup.zip -r /home/companion/companion
        chown pi:pi /home/pi/companion-config-backup.zip

        echo "Cleaning up old installation"
        rm -Rf /usr/local/src/companion
    fi
fi

if [ -d "/usr/local/src/companion" ]; then
    # staying with v2

    # update companion soruce
    cd /usr/local/src/companion
    git fetch --all -q

    # The version can be the first argument, or we can prompt for it
    SELECTED_REF=$1
    if [ -z "$SELECTED_REF" ]; then
        # Run interactive version picker
        yarn --cwd "/usr/local/src/companionpi/update-prompt-2.4" install
        node "/usr/local/src/companionpi/update-prompt-2.4/main.js"

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
            git pull -q
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
else
    # proceed with v3
        
    # update the node version
    fnm use --install-if-missing --silent-if-unchanged
    fnm default $(fnm current)
    npm --unsafe-perm install -g yarn &>/dev/null

    # TODO - cleanup old node versions?

    # Run interactive version picker
    yarn --cwd "/usr/local/src/companionpi/update-prompt" --silent install
    node "/usr/local/src/companionpi/update-prompt/main.js" $1 $2

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
        mv /tmp/companion-update/*.rules /opt/companion/ 2>/dev/null || true
        rm -R /tmp/companion-update

        echo "Finishing"
    else
        echo "Skipping update"
    fi
fi

# update some tooling
cd /usr/local/src/companionpi

# copy the best option for udev rules
if [ -d "/etc/udev/rules.d/" ]; then
    if [ -f "/opt/companion/50-companion-headless.rules" ]; then
        cp /opt/companion/50-companion-headless.rules /etc/udev/rules.d/50-companion.rules
        udevadm control --reload-rules || true
    elif [ -f "/opt/companion/50-companion.rules" ]; then
        cp /opt/companion/50-companion.rules /etc/udev/rules.d/50-companion.rules
        udevadm control --reload-rules || true
    else
        # otherwise this is either v2 which doesn't ship any udev rules, or v4.3+ which uses a dynamic method
        # v2 is so old, we can ignore it
        echo "Skipping installing of udev rules, Companion 4.3+ uses runtime rule generation"
    fi
else
    echo "Skipping installing of udev rules, as /etc/udev/rules.d/ does not exist"
fi

if [ -d "/etc/sudoers.d" ]; then
    cp 090-companion_sudo /etc/sudoers.d/
fi
if [ $(getent group gpio) ]; then
  adduser -q companion gpio # for rpi-gpio
fi
if [ $(getent group dialout) ]; then
  adduser -q companion dialout # for serial based surfaces
fi
if [ $(getent group audio) ]; then
  adduser -q companion audio # for generic-midi
fi

# ensure some dependencies are installed
ensure_installed() {
  if ! dpkg --verify "$1" 2>/dev/null; then
    # Future: batch the installs, if there are multiple
    apt-get install -qq -y $1
  fi
}
ensure_installed "libfontconfig1" # for the new canvas in 3.2
if apt-get --simulate -qq install libasound2 &>/dev/null; then
    ensure_installed "libasound2" # for generic-midi
else
    # ubuntu 24
    ensure_installed "libasound2t64" # for generic-midi
fi

# if neither old or new config directory exists, create it. This is to work around a bug in 3.0.0-rc2
if [ ! -d "/home/companion/.config/companion-nodejs" ]; then
    if [ ! -d "/home/companion/companion" ]; then
        su companion -c "mkdir -p /home/companion/.config/companion-nodejs"
    fi
fi

# update startup script
cp companion.service /etc/systemd/system
systemctl daemon-reload

# install some scripts
ln -s -f /usr/local/src/companionpi/companion-license /usr/local/bin/companion-license
ln -s -f /usr/local/src/companionpi/companion-help /usr/local/bin/companion-help
ln -s -f /usr/local/src/companionpi/companion-update /usr/local/sbin/companion-update
ln -s -f /usr/local/src/companionpi/companion-reset /usr/local/sbin/companion-reset
ln -s -f /usr/local/src/companionpi/companion-sync-udev-rules /usr/local/sbin/companion-sync-udev-rules

# install the motd
ln -s -f /usr/local/src/companionpi/motd /etc/motd 
