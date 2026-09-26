# Scenario 2: adopt the records of scenario 1 into an empty state

module "fixture" {
  source = "../fixture"

  prefix    = var.prefix
  zone_name = var.zone_name
  a_value   = var.a_value
  txt_value = var.txt_value
}

module "dns" {
  source = "../../.."

  zone_id         = var.zone_id
  zone_name       = var.zone_name
  default_ttl     = 300
  default_comment = "easy-dns-e2e"
  import_existing = true
  records         = module.fixture.records
}

import {
  for_each = module.dns.import_ids
  to       = module.dns.module.v5.cloudflare_dns_record.record[each.key]
  id       = each.value
}
