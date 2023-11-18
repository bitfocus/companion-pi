The recommended way to install Companion is to run the following as root

```
curl https://raw.githubusercontent.com/bitfocus/companion-pi/main/install.sh | bash
```

This will perform the same installation and setup steps as the CompanionPi image.
These steps include:
 * Create a `companion` user
 * Install any required system dependencies
 * Downloading the latest beta build of Companion
 * Setup udev rules to allow using Streamdecks and other supported surface
 * Setup sudo rules to allow Companion to shutdown and restart the system
 * Install scripts such as `companion-update`
If you want to understand the full scope of the changes, you can read the [install script](https://github.com/bitfocus/companion-pi/blob/main/install.sh).

You are free to customise the installation as you wish, but care should be taken to avoid breaking the updater or making changes that the updater will replace during the next update.  
If you need further customisation over this, let us know in [an issue](https://github.com/bitfocus/companion-pi/issues)
