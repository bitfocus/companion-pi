Following the change in April 2022 by Raspberry Pi, the CompanionPi images do not allow ssh access until you setup a user. If you have a screen connected you will prompted to setup the user, or you can create the user with a config file at first boot

To create the user at first boot:
 * At the root of your SD card, create a file named `userconf.txt`
 * Run `openssl passwd -6 <your-password>` to generate a hash of your password.
 * Add a single line to the `userconf.txt` file, `<username>:<password-hash>` using the output of the previous step as the password hash.


There are other security-oriented best practices that are recommended, such as:

* Making sudo require a password
* Making sure you've got the latest os updates and security fixes
* Improving SSH security
* All of these recommended best practices can be found here, on the [raspberrypi.org website](https://www.raspberrypi.org/documentation/configuration/security.md)
