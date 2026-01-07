variable "cloudflare_api_token" {
  description = "Cloudflare API token"
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID"
  type        = string
  default     = "afd308b5572244c6e32d3a7f7434f2c0"
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for pirackr.xyz"
  type        = string
}

# Import-only variables (can be removed after first apply)
variable "tunnel_id" {
  description = "Existing Cloudflare tunnel ID (for import)"
  type        = string
}

variable "tunnel_secret" {
  description = "Tunnel secret (base64 encoded)"
  type        = string
  sensitive   = true
}
