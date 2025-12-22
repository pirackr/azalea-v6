# VM Module - Creates a libvirt VM with cloud-init

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }
}

# Cloud-init configuration
data "template_file" "user_data" {
  template = file("${path.module}/templates/cloud-init.yaml")

  vars = {
    hostname          = var.name
    ssh_public_key    = var.ssh_public_key
    tailscale_authkey = var.tailscale_authkey
    timezone          = var.timezone
  }
}

data "template_file" "network_config" {
  template = file("${path.module}/templates/network-config.yaml")
}

# Cloud-init disk
resource "libvirt_cloudinit_disk" "init" {
  name           = "${var.name}-cloudinit.iso"
  user_data      = data.template_file.user_data.rendered
  network_config = data.template_file.network_config.rendered
  meta_data      = ""
}

# VM disk (download Ubuntu image directly)
resource "libvirt_volume" "disk" {
  name     = "${var.name}-disk.qcow2"
  pool     = var.pool_name
  capacity = var.disk_size

  create = {
    content = {
      url = "https://cloud-images.ubuntu.com/releases/noble/release/ubuntu-24.04-server-cloudimg-amd64.img"
    }
  }
}

# VM definition
resource "libvirt_domain" "vm" {
  name      = var.name
  memory    = var.memory
  vcpu      = var.vcpu
  type      = "kvm"
  autostart = var.autostart

  # CPU
  cpu = {
    mode = "host-passthrough"
  }

  # Devices
  devices = {
    # Disks: root disk + cloud-init ISO
    disks = [
      {
        volume_id = libvirt_volume.disk.id
      },
      {
        volume_id = libvirt_cloudinit_disk.init.id
        device    = "cdrom"
      }
    ]

    # Network
    interfaces = [
      {
        network = {
          name = var.network_name
        }
        wait_for_lease = true
      }
    ]

    # Console access
    consoles = [
      {
        type = "pty"
        target = {
          port = 0
          type = "serial"
        }
      }
    ]

    # VNC graphics
    graphics = [
      {
        type        = "vnc"
        listen_type = "address"
        auto_port   = true
      }
    ]
  }
}
