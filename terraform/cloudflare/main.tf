# Cloudflare infrastructure management
# Manages: Tunnel, DNS records
#
# Bootstrap resources (not managed here):
# - R2 bucket "tofu" (Terraform state storage)

terraform {
  required_version = ">= 1.5"

  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.0"
    }
  }

  backend "s3" {
    bucket                      = "tofu"
    key                         = "cloudflare/terraform.tfstate"
    region                      = "auto"
    endpoint                    = "https://afd308b5572244c6e32d3a7f7434f2c0.r2.cloudflarestorage.com"
    skip_credentials_validation = true
    skip_region_validation      = true
    skip_requesting_account_id  = true
    skip_metadata_api_check     = true
    skip_s3_checksum            = true
  }
}

provider "cloudflare" {
  api_token = var.cloudflare_api_token
}
