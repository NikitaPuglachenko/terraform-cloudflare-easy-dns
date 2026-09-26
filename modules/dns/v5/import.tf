# Lookup of records that already exist in the zone, enabled by var.import_existing.
# Matching to the configured records is done in the records module.

data "cloudflare_dns_records" "existing" {
  count = var.import_existing ? 1 : 0

  zone_id   = var.zone_id
  max_items = 10000
}

locals {
  existing_records = [
    for r in try(data.cloudflare_dns_records.existing[0].result, []) : {
      id      = r.id
      name    = r.name
      type    = r.type
      content = r.content
      data    = r.data == null ? null : { for field, value in r.data : field => tostring(value) if value != null }
    }
  ]
}
