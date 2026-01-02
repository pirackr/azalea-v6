# Terraform configuration for lush-forest VMs
# VMs: grumpy-walrus (worker), happy-dolphin (worker)

terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "0.8.3"
    }
  }

  backend "s3" {
    bucket                      = "tofu"
    key                         = "hosts/lush-forest/terraform.tfstate"
    region                      = "auto"
    endpoint                    = "https://afd308b5572244c6e32d3a7f7434f2c0.r2.cloudflarestorage.com"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

# Libvirt provider - connect to remote host via SSH
provider "libvirt" {
  uri = "qemu+ssh://deploy@lush-forest/system?keyfile=${var.ssh_private_key_path}&no_verify=1"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for libvirt connection"
  type        = string
}

variable "ssh_public_key" {
  description = "SSH public key for deploy user"
  type        = string
}

variable "tailscale_authkey" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

locals {
  ubuntu_image = "file:///home/pirackr/Working/azalea-v6/terraform/images/ubuntu-24.04-server-cloudimg-amd64.img"
}

# grumpy-walrus - K8s worker
module "grumpy_walrus" {
  source = "../../modules/vm"

  name         = "grumpy-walrus"
  vcpu         = 4
  memory       = 16384  # 16GB
  disk_size    = 70 * 1024 * 1024 * 1024  # 70GB
  source_image = local.ubuntu_image

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# happy-dolphin - K8s worker
module "happy_dolphin" {
  source = "../../modules/vm"

  name         = "happy-dolphin"
  vcpu         = 4
  memory       = 16384  # 16GB
  disk_size    = 70 * 1024 * 1024 * 1024  # 70GB
  source_image = local.ubuntu_image

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# Outputs
output "vms" {
  description = "VM information"
  value = {
    grumpy-walrus = {
      ip  = module.grumpy_walrus.ip_address
      mac = module.grumpy_walrus.mac_address
    }
    happy-dolphin = {
      ip  = module.happy_dolphin.ip_address
      mac = module.happy_dolphin.mac_address
    }
  }
}
