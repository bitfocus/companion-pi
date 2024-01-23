We only officialy support the Raspberry Pi 4 and 5, as well as derivatives of these such as the 400 or Compute Module 4.  
It is possible to use the older models+, but **it is not recommended or supported**. Should you choose to do so, you do so at your own risk and with the understanding that the community will not be able to help you with any issues.

If you are installing Companion from scratch on an older Pi 4, make sure you've got your system updated with the latest eeprom/firmware updates ([info here](https://www.raspberrypi.org/forums/viewtopic.php?t=255001)). A update (late October 2019) combines the update mechanisms for both the SPI EEPROM and the VLI USB controller chip. Installing the latest updates will (in the future) open up the ability to boot your Raspberry Pi from a network-connected device or from an external USB storage device, and also updates the VLI firmware to reduce power consumption and bring running temperatures down by up to 3-4 °C.

Models older then the 4 are not supported as stability issues were identified which we believe are due to multiple (potentially interrelated) factors, including power output capability (e.g. to power a Stream Deck), power input requirements, OEM power supply capacity, Ethernet-no-longer-on-shared-USB-bus, maximum RAM, and of course CPU (as detailed in [Issue #313](https://github.com/bitfocus/companion/issues/313)).  Accordingly, ongoing development efforts are focused on Raspberry Pi 4 systems.