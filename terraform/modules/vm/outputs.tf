# VM Module Outputs

output "name" {
  description = "VM name"
  value       = libvirt_domain.vm.name
}

output "id" {
  description = "VM ID"
  value       = libvirt_domain.vm.id
}

output "ip_address" {
  description = "VM IP address (from DHCP)"
  value       = "check-tailscale"
}

output "mac_address" {
  description = "VM MAC address"
  value       = "auto-generated"
}
