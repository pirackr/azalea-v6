# Cloudflare Tunnel configuration
# Routes:
#   - *.pirackr.xyz -> traefik (K8s ingress)
#   - ssh.pirackr.xyz -> golden-savanna:22

resource "cloudflare_zero_trust_tunnel_cloudflared" "azalea" {
  account_id = var.cloudflare_account_id
  name       = "azalea"
  secret     = var.tunnel_secret
}

# Tunnel ingress configuration
resource "cloudflare_zero_trust_tunnel_cloudflared_config" "azalea" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.azalea.id

  config {
    # SSH access to golden-savanna
    ingress_rule {
      hostname = "ssh.pirackr.xyz"
      service  = "ssh://golden-savanna:22"
    }

    ingress_rule {
      hostname = "org.pirackr.xyz"
      service = "ssh://ssh-pod.org.svc.cluster.local:22"
    }

    # Wildcard -> Traefik ingress controller
    ingress_rule {
      hostname = "*.pirackr.xyz"
      service  = "http://traefik.traefik.svc.cluster.local:80"
    }

    # Catch-all (required)
    ingress_rule {
      service = "http_status:404"
    }
  }
}

# DNS records pointing to tunnel
resource "cloudflare_record" "tunnel_wildcard" {
  zone_id = var.cloudflare_zone_id
  name    = "*"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.azalea.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1 # Auto TTL when proxied
}

resource "cloudflare_record" "tunnel_ssh" {
  zone_id = var.cloudflare_zone_id
  name    = "ssh"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.azalea.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}

resource "cloudflare_record" "tunnel_org" {
  zone_id = var.cloudflare_zone_id
  name    = "org"
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.azalea.id}.cfargotunnel.com"
  proxied = true
  ttl     = 1
}
