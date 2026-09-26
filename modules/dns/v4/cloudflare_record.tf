data "cloudflare_zone" "this" {
  count   = var.zone_name == null ? 1 : 0
  zone_id = var.zone_id
}

resource "cloudflare_record" "record" {
  for_each = module.records.flat_records

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type

  content = each.value.type == "CAA" ? null : each.value.content

  ttl = each.value.proxied ? 1 : each.value.ttl

  proxied  = each.value.type == "CAA" ? null : each.value.proxied
  priority = each.value.type == "MX" ? each.value.priority : null

  dynamic "data" {
    for_each = each.value.type == "CAA" ? [1] : []
    content {
      flags = each.value.flags
      tag   = each.value.tag
      value = each.value.content
    }
  }
}
