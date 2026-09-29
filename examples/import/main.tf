# Starting to manage a zone that already has records: the existing records are
# adopted into the state instead of being created again. After the first apply,
# remove the import block and import_existing.
module "dns" {
  # Outside of this repository, with a local copy of the module (see the README):
  #   source = "./modules/easy-dns"
  source = "../.."

  zone_id         = var.zone_id
  zone_name       = var.zone_name
  import_existing = true

  records = {
    "@"   = { A = [{ content = "192.0.2.10", proxied = true }], ALIASES = [{ content = "www" }] }
    "git" = { A = [{ content = "192.0.2.20" }] }
  }
}

# Records that exist in the zone are imported; the others are created
import {
  for_each = module.dns.import_ids
  to       = module.dns.module.v5.cloudflare_dns_record.record[each.key]
  id       = each.value
}
