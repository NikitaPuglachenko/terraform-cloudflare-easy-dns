# Lookup of records that already exist in the zone, enabled by var.import_existing.
# Matching to the configured records is done in the records module.

locals {
  # Record types of the configuration (ALIASES are CNAMEs)
  import_types = toset(flatten([
    for base_name, type_map in var.records : [
      for raw_key, recs in type_map :
      replace(element(split(".", raw_key), length(split(".", raw_key)) - 1), "ALIASES", "CNAME")
    ]
  ]))
}

# One lookup per record type: the provider returns data.flags as a number for CAA and
# DNSKEY and as null for other types, and a list mixing both makes Terraform crash
data "cloudflare_dns_records" "existing" {
  for_each = var.import_existing ? local.import_types : toset([])

  zone_id   = var.zone_id
  type      = each.key
  max_items = 10000
}

locals {
  existing_records = flatten([
    for type, lookup in data.cloudflare_dns_records.existing : [
      for r in lookup.result : {
        id      = r.id
        name    = r.name
        type    = r.type
        content = r.content
        data    = r.data == null ? null : { for field, value in r.data : field => tostring(value) if value != null }
      }
    ]
  ])
}
