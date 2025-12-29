# Terraform configuration for misty-bamboo VMs
# VMs: chunky-wombat (worker), fancy-penguin (worker)

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
    key                         = "hosts/misty-bamboo/terraform.tfstate"
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
  uri = "qemu+ssh://deploy@misty-bamboo/system?keyfile=${var.ssh_private_key_path}&no_verify=1"
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

# chunky-wombat - K8s worker
module "chunky_wombat" {
  source = "../../modules/vm"

  name         = "chunky-wombat"
  vcpu         = 4
  memory       = 16384  # 16GB
  source_image = local.ubuntu_image

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# fancy-penguin - K8s worker
module "fancy_penguin" {
  source = "../../modules/vm"

  name         = "fancy-penguin"
  vcpu         = 4
  memory       = 16384  # 16GB
  source_image = local.ubuntu_image

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# Outputs
output "vms" {
  description = "VM information"
  value = {
    chunky-wombat = {
      ip  = module.chunky_wombat.ip_address
      mac = module.chunky_wombat.mac_address
    }
    fancy-penguin = {
      ip  = module.fancy_penguin.ip_address
      mac = module.fancy_penguin.mac_address
    }
  }
}
