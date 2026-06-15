# [Bitfocus Companion](https://companion.free)

CompanionPi is a prebuilt image for the Raspberry Pi 4B, set up to run [Bitfocus Companion](https://companion.free) as a headless appliance.

> **Headless/server use only.** This image and install script set up Companion to run as a background service on a machine with **no desktop environment**. It is not intended for desktop installs — if you want to run Companion on your everyday Windows, macOS, or Linux desktop, download the regular [desktop build](https://user.bitfocus.io/download) instead.

This repository houses the tooling for building the images. Only issues relating to the image building/updating should be reported here.

The same setup also works on other headless Debian or Ubuntu machines (see [Other Debian/Ubuntu](#other-debianubuntu) below).

## Companion Pi

Prebuilt images can be found on the [Bitfocus website](https://user.bitfocus.io/download).

After flashing the image to an SD card and booting the Pi, Companion runs automatically as a service. You then administer it remotely through its web interface from another device on the network — there is no local desktop or GUI on the Pi itself.

Note: This has been written for arm64 images, and is not tested or supported on anything below a 4B. We do not recommend running it on anything lower, but you can follow the [manual install instructions](https://companion.free/user-guide/beta/getting-started/companion-pi/) if you are sure you want to.

## Other Debian/Ubuntu

No images are provided for this, but the process has been written as a single script. It is intended for **headless servers** — machines you administer over the network, not desktop computers.

As root, run the following:

```
curl https://raw.githubusercontent.com/bitfocus/companion-pi/main/install.sh | bash
```

This installs Companion as a service and starts it automatically. As with the Pi image, you administer it through its web interface from another device.

After installing, you can use `sudo companion-update` to change the version it has installed.

Note: This script will create a new user called `companion`, which Companion will be run as and will own the configuration.

### Development

Warning: This has only been tested on linux, but it should work wherever packer is supported.

This repository utilises [packer](https://www.packer.io/) to build images, using an [arm-image plugin](https://github.com/solo-io/packer-plugin-arm-image) to add to an official raspberry-pi-lite image.

After installing packer, set it up for this project: `packer init companionpi.pkr.hcl`.

You can then perform the build with `packer build --var pibranch=main companionpi.pkr.hcl`. Be aware that this can be very slow, due to the cpu architecture emulation.

Once complete, the file `output-companionpi/image` can be written to an SD card and launched on a Pi.
