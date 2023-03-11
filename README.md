# [Bitfocus Companion](https://bitfocus.io/companion)

CompanionPi is a prebuilt image for the Raspberry Pi 4B, setup to run [Bitfocus Companion](https://github.com/bitfocus/companion)

This repository houses the tooling for building the images, only issues relating to the image building/updating should be reported here.

This also works on other headless Debian or Ubuntu machines.
## Companion Pi

Prebiult images can be found on the [Bitfocus website](https://bitfocus.io/companion)

Note: This has been written for arm64 images, and is not tested or supported on anything below a 4B. We do not recommend running it on anything lower, but you can follow the [manual install instuctions](https://github.com/bitfocus/companion/wiki/Installation) if you are sure you want to.

## Other Debian/Ubuntu

No images are provided for this, but the process has been written to be a single script.

As root, run the following:
```
curl https://raw.githubusercontent.com/bitfocus/companion-pi/main/install.sh | sh
```

After this, you can use `sudo companion-update` to change the version it has installed.

Note: This script will create a new user called `companion`, which Companion will be run as and will own the configuration.

### Development

Warning: This has only been tested on linux, but it should work wherever packer is supported.

This repository utilises [packer](https://www.packer.io/) to build images, using an [arm-image plugin](https://github.com/solo-io/packer-plugin-arm-image) to add to an official raspberry-pi-lite image.

After installing packer, set it up for this project: `packer init companionpi.pkr.hcl`.

You can then perform the build with `packer build --var branch=master companionpi.pkr.hcl`. Be aware that this can be very slow, due to the cpu architecture emulation.

Once complete, the file `output-companionpi/image` can be written to an sd card and launched on a pi
