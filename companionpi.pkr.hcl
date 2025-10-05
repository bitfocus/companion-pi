packer {
  required_plugins {
    arm-image = {
      version = "0.2.7"
      source  = "github.com/solo-io/arm-image"
    }
  }
}

variable "build" {
  type    = string
  default = "beta"
}
variable "pibranch" {
  type    = string
  default = "main"
}

source "arm-image" "companionpi" {
  iso_checksum              = "sha256:79146135607ffe8acac94e5ff501de6fc49583117de5ad08c45a32c73ae2a027"
  iso_url                   = "https://downloads.raspberrypi.com/raspios_lite_arm64/images/raspios_lite_arm64-2025-10-02/2025-10-01-raspios-trixie-arm64-lite.img.xz"
  last_partition_extra_size = 2147483648
  qemu_binary               = "qemu-aarch64-static"
}

build {
  sources = ["source.arm-image.companionpi"]

  provisioner "file" {
    source = "install.sh"
    destination = "/tmp/install.sh"
  }

  provisioner "shell" {
    #system setup
    inline = [
      # enable ssh
      "touch /boot/ssh",

      # change the hostname
      "CURRENT_HOSTNAME=`cat /etc/hostname | tr -d \" \t\n\r\"`",
      "echo CompanionPi > /etc/hostname",
      "sed -i \"s/127.0.1.1.*$CURRENT_HOSTNAME/127.0.1.1\tCompanionPi/g\" /etc/hosts",
    ]
  }

  provisioner "shell" {
    # run as root
    execute_command = "chmod +x {{ .Path }}; {{ .Vars }} su root -c {{ .Path }}"
    inline_shebang  = "/bin/bash -e"
    inline = [
      # run the script
      "export COMPANIONPI_BRANCH=${var.pibranch}",
      "export COMPANION_BUILD=${var.build}",
      "chmod +x /tmp/install.sh",
      "/tmp/install.sh"
    ]
  }

}
