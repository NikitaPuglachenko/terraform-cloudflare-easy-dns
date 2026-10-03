locals {
  root_domain = coalesce(var.zone_name, try(data.cloudflare_zone.this[0].name, null))
}

module "records" {
  source = "../records"

  root_domain             = local.root_domain
  records                 = var.records
  default_ttl             = var.default_ttl
  default_proxied         = var.default_proxied
  default_comment         = var.default_comment
  default_tags            = var.default_tags
  allowed_cname_conflicts = var.allowed_cname_conflicts
  minimum_ttl             = var.minimum_ttl
}

data "cloudflare_zone" "this" {
  count   = var.zone_name == null ? 1 : 0
  zone_id = var.zone_id
}

resource "cloudflare_record" "record" {
  for_each = module.records.flat_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type
  content = each.value.content

  ttl = each.value.proxied ? 1 : each.value.ttl

  # Records with structured data (CAA, SRV, ...) cannot be proxied
  proxied  = each.value.data == null ? each.value.proxied : null
  priority = each.value.priority
  comment  = each.value.comment
  tags     = length(each.value.tags) > 0 ? each.value.tags : null

  dynamic "data" {
    for_each = each.value.data == null ? [] : [each.value.data]
    content {
      algorithm      = lookup(data.value, "algorithm", null)
      altitude       = lookup(data.value, "altitude", null)
      certificate    = lookup(data.value, "certificate", null)
      digest         = lookup(data.value, "digest", null)
      digest_type    = lookup(data.value, "digest_type", null)
      fingerprint    = lookup(data.value, "fingerprint", null)
      flags          = lookup(data.value, "flags", null)
      key_tag        = lookup(data.value, "key_tag", null)
      lat_degrees    = lookup(data.value, "lat_degrees", null)
      lat_direction  = lookup(data.value, "lat_direction", null)
      lat_minutes    = lookup(data.value, "lat_minutes", null)
      lat_seconds    = lookup(data.value, "lat_seconds", null)
      long_degrees   = lookup(data.value, "long_degrees", null)
      long_direction = lookup(data.value, "long_direction", null)
      long_minutes   = lookup(data.value, "long_minutes", null)
      long_seconds   = lookup(data.value, "long_seconds", null)
      matching_type  = lookup(data.value, "matching_type", null)
      order          = lookup(data.value, "order", null)
      port           = lookup(data.value, "port", null)
      precision_horz = lookup(data.value, "precision_horz", null)
      precision_vert = lookup(data.value, "precision_vert", null)
      preference     = lookup(data.value, "preference", null)
      priority       = lookup(data.value, "priority", null)
      protocol       = lookup(data.value, "protocol", null)
      public_key     = lookup(data.value, "public_key", null)
      regex          = lookup(data.value, "regex", null)
      replacement    = lookup(data.value, "replacement", null)
      selector       = lookup(data.value, "selector", null)
      service        = lookup(data.value, "service", null)
      size           = lookup(data.value, "size", null)
      tag            = lookup(data.value, "tag", null)
      target         = lookup(data.value, "target", null)
      type           = lookup(data.value, "type", null)
      usage          = lookup(data.value, "usage", null)
      value          = lookup(data.value, "value", null)
      weight         = lookup(data.value, "weight", null)
    }
  }
}

# Numbers in text values are written in their canonical form ("0123" -> "123",
# "1.10" -> "1.1"), which loses what was written in YAML; quoting keeps it
check "records_text_values_are_strings" {
  assert {
    condition = alltrue(flatten([
      for name, types in var.records : [
        for type, list in types : [
          for record in list : [
            # fine: a JSON string, or a value that is not a number
            for attribute in ["content", "key", "comment", "tag"] : startswith(jsonencode(try(record[attribute], "")), "\"") || !can(tonumber(try(record[attribute], "")))
          ]
        ]
      ]
    ]))
    error_message = "Text values given as numbers are written in their canonical form (0123 -> 123, 1.10 -> 1.1); in YAML quote them to keep them as written:\n${join("\n", flatten([
      for name, types in var.records : [
        for type, list in types : [
          for index, record in list : [
            for attribute in ["content", "key", "comment", "tag"] : "records[\"${name}\"][\"${type}\"][${index}].${attribute} is ${jsonencode(record[attribute])}"
            if !startswith(jsonencode(try(record[attribute], "")), "\"") && can(tonumber(try(record[attribute], "")))
          ]
        ]
      ]
    ]))}"
  }
}
