output "tunnel_id" {
  description = "Cloudflare tunnel ID"
  value       = cloudflare_zero_trust_tunnel_cloudflared.azalea.id
}

output "tunnel_token" {
  description = "Cloudflare tunnel token (for cloudflared)"
  value       = cloudflare_zero_trust_tunnel_cloudflared.azalea.tunnel_token
  sensitive   = true
}

output "tunnel_cname" {
  description = "CNAME target for tunnel DNS records"
  value       = "${cloudflare_zero_trust_tunnel_cloudflared.azalea.id}.cfargotunnel.com"
}
