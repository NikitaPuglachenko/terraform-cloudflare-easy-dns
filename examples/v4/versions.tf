terraform {
  required_version = ">= 1.8.0"
  required_providers {
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 4.30"
    }
  }
}

# The API token is read from the CLOUDFLARE_API_TOKEN environment variable
provider "cloudflare" {}
