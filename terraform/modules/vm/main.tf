# VM Module - Creates a libvirt VM with cloud-init

terraform {
  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }
}

# Cloud-init disk
resource "libvirt_cloudinit_disk" "init" {
  name = "${var.name}-cloudinit.iso"
  pool = var.pool_name

  user_data = templatefile("${path.module}/templates/cloud-init.yaml", {
    hostname          = var.name
    ssh_public_key    = var.ssh_public_key
    tailscale_authkey = var.tailscale_authkey
    timezone          = var.timezone
  })

  network_config = file("${path.module}/templates/network-config.yaml")
}

# VM disk (created from source image)
resource "libvirt_volume" "disk" {
  name   = "${var.name}-disk.qcow2"
  pool   = var.pool_name
  source = var.source_image
  format = "qcow2"
}

# VM definition
resource "libvirt_domain" "vm" {
  name      = var.name
  memory    = var.memory
  vcpu      = var.vcpu
  autostart = var.autostart

  cpu {
    mode = "host-passthrough"
  }

  cloudinit = libvirt_cloudinit_disk.init.id

  disk {
    volume_id = libvirt_volume.disk.id
  }

  network_interface {
    network_name   = var.network_name
    wait_for_lease = true
  }

  console {
    type        = "pty"
    target_port = "0"
    target_type = "serial"
  }

  graphics {
    type        = "vnc"
    listen_type = "address"
    autoport    = true
  }
}
