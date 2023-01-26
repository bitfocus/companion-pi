packer {
  required_plugins {
    arm-image = {
      version = "0.2.5"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "branch" {
  type    = string
  default = "master"
}

source "arm-image" "companionpi" {
  iso_checksum              = "sha256:72c773781a0a57160eb3fa8bb2a927642fe60c3af62bc980827057bcecb7b98b"
  iso_url                   = "https://downloads.raspberrypi.org/raspios_lite_arm64/images/raspios_lite_arm64-2022-09-26/2022-09-22-raspios-bullseye-arm64-lite.img.xz"
  last_partition_extra_size = 2147483648
  qemu_binary               = "qemu-aarch64-static"
}

build {
  sources = ["source.arm-image.companionpi"]

  provisioner "shell" {
    #system setup
    inline = [
      # enable ssh
      "touch /boot/ssh",

      # change the hostname
      "CURRENT_HOSTNAME=`cat /etc/hostname | tr -d \" \t\n\r\"`",
      "echo CompanionPi > /etc/hostname",
      "sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tCompanionPi/g\" /etc/hosts",

      # add a system user
      "adduser --disabled-password companion --gecos \"\"",

      # install some dependencies
      "apt-get update",
      "apt-get install -y git unzip curl libusb-1.0-0-dev libudev-dev cmake",
      "apt-get clean"
    ]
  }

  provisioner "shell" {
    # run as root
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # install fnm to manage node version
      # we do this to /opt/fnm, so that the companion user can use the same installation
      "export FNM_DIR=/opt/fnm",
      "echo \"export FNM_DIR=/opt/fnm\" >> /root/.bashrc",
      "curl -fsSL https://fnm.vercel.app/install | bash -s -- --install-dir /opt/fnm",
      "export PATH=/opt/fnm:$PATH",
      "eval \"`fnm env --shell bash`\"",

      # clone the companionpi repository
      "git clone https://github.com/bitfocus/companion-pi.git -b feat/v3 /usr/local/src/companionpi",
      "cd /usr/local/src/companionpi",

      # # clone the companion repository
      # "git clone https://github.com/bitfocus/companion.git -b ${var.branch} /usr/local/src/companion",

      # configure git for future updates
      "git config --global pull.rebase false",

      # run the update script
      "./update.sh ${var.branch}",

      # install update script dependencies, as they were ignored
      "yarn --cwd \"/usr/local/src/companionpi/update-prompt\" install",

      # enable start on boot
      "systemctl enable companion"
    ]
  }

  provisioner "shell" {
    # run as companion user
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su companion -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # "cd /usr/local/src/companion",

      # add the fnm node to this users path
      "echo \"export PATH=/opt/fnm/aliases/default/bin:\\$PATH\" >> ~/.bashrc"

    ]
  }

}
