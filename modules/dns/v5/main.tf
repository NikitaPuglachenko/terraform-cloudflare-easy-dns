locals {
  root_domain = coalesce(var.zone_name, try(data.cloudflare_zone.this[0].name, null))
}

module "records" {
  source = "../records"

  root_domain = local.root_domain
  records     = var.records
}

data "cloudflare_zone" "this" {
  count   = var.zone_name == null ? 1 : 0
  zone_id = var.zone_id
}

resource "cloudflare_dns_record" "record" {
  for_each = module.records.flat_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type

  content = each.value.type == "CAA" ? null : each.value.content

  ttl = each.value.proxied ? 1 : each.value.ttl

  proxied  = each.value.type == "CAA" ? null : each.value.proxied
  priority = each.value.type == "MX" ? each.value.priority : null

  data = each.value.type == "CAA" ? {
    flags = each.value.flags
    tag   = each.value.tag
    value = each.value.content
  } : null
}

# Migration from the v4 module: state of cloudflare_record is moved without recreating records
moved {
  from = cloudflare_record.record
  to   = cloudflare_dns_record.record
}
