terraform {
  required_version = ">= 1.8.0"
  required_providers {
    # Used by the v5 wrapper; declared here so the root module resolves the
    # cloudflare/cloudflare provider and shows it on the Terraform Registry
    # tflint-ignore: terraform_unused_required_providers
    cloudflare = {
      source  = "cloudflare/cloudflare"
      version = "~> 5.26"
    }
  }
}
