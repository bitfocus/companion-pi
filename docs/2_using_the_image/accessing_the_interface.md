Once you've got your Raspberry Pi up and running with the CompanionPi image, you'll need to know the IP address of your Raspberry Pi. There are a few ways to do this:

- A custom Python script written to email you the IP address every time it boots _(requires internet connection at boot)_: [on GitHub, here](https://github.com/oliverscheer/send-email-with-device-ip-address)
- Set a static IP address on your Pi _(good option if your Raspberry Pi is going to be always connected to the same equipment)_: [use this tutorial from The Pi Hut for 3.1.1 and older](https://thepihut.com/blogs/raspberry-pi-tutorials/how-to-give-your-raspberry-pi-a-static-ip-address-update) or [use this tutorial for 3.1.2 and later)[https://www.abelectronics.co.uk/kb/article/31/set-a-static-ip-address-on-raspberry-pi-os-bookworm]
- An attached LCD display to show your current IP address _(a little maker-y, and pretty cool)_: [example from PiMyLifeUp](https://pimylifeup.com/raspberry-pi-lcd-16x2/)

Once you know your IP address, you can access the Companion Admin User Interface on port 8000 of that IP address (i.e. http://192.168.1.3:8000).
