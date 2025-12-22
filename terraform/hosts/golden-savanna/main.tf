# Terraform configuration for golden-savanna VMs
# VMs: sleepy-koala (control), lazy-panda (worker)

terraform {
  required_version = ">= 1.0"

  required_providers {
    libvirt = {
      source  = "dmacvicar/libvirt"
      version = "~> 0.9"
    }
  }

  backend "s3" {
    bucket                      = "tofu"
    key                         = "hosts/golden-savanna/terraform.tfstate"
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
  uri = "qemu+ssh://deploy@golden-savanna/system?keyfile=${var.ssh_private_key_path}&no_verify=1"
}

variable "ssh_private_key_path" {
  description = "Path to SSH private key for libvirt connection"
  type        = string
}

# Variables
variable "ssh_public_key" {
  description = "SSH public key for deploy user"
  type        = string
}

variable "tailscale_authkey" {
  description = "Tailscale authentication key"
  type        = string
  sensitive   = true
}

# sleepy-koala - K8s control plane
module "sleepy_koala" {
  source = "../../modules/vm"

  name     = "sleepy-koala"
  vcpu     = 4
  memory   = 8192                    # 8GB
  disk_size = 80 * 1024 * 1024 * 1024  # 80GB

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# lazy-panda - K8s worker (large)
module "lazy_panda" {
  source = "../../modules/vm"

  name      = "lazy-panda"
  vcpu      = 8
  memory    = 24576                     # 24GB
  disk_size = 200 * 1024 * 1024 * 1024  # 200GB

  ssh_public_key    = var.ssh_public_key
  tailscale_authkey = var.tailscale_authkey
}

# Outputs
output "vms" {
  description = "VM information"
  value = {
    sleepy-koala = {
      ip  = module.sleepy_koala.ip_address
      mac = module.sleepy_koala.mac_address
    }
    lazy-panda = {
      ip  = module.lazy_panda.ip_address
      mac = module.lazy_panda.mac_address
    }
  }
}
