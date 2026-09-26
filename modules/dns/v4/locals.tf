locals {
  root_domain = coalesce(var.zone_name, try(data.cloudflare_zone.this[0].name, null))
}

module "records" {
  source = "../records"

  root_domain = local.root_domain
  records     = var.records
}
