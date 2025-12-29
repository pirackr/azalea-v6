# VM Module Variables

variable "name" {
  description = "VM name (will be used as hostname)"
  type        = string
}

variable "vcpu" {
  description = "Number of virtual CPUs"
  type        = number
  default     = 2
}

variable "memory" {
  description = "Memory in MB"
  type        = number
  default     = 2048
}

variable "source_image" {
  description = "Path to source image (file:// URL)"
  type        = string
}

variable "pool_name" {
  description = "Libvirt storage pool name"
  type        = string
  default     = "default"
}

variable "network_name" {
  description = "Libvirt network name"
  type        = string
  default     = "default"
}

variable "ssh_public_key" {
  description = "SSH public key for deploy user"
  type        = string
}

variable "tailscale_authkey" {
  description = "Tailscale auth key for automatic registration"
  type        = string
  sensitive   = true
}

variable "timezone" {
  description = "Timezone for the VM"
  type        = string
  default     = "America/Los_Angeles"
}

variable "autostart" {
  description = "Start VM automatically on host boot"
  type        = bool
  default     = true
}
