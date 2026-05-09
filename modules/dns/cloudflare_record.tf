resource "cloudflare_record" "record" {
  for_each = local.flat_records_all

  zone_id = var.zone_id
  name    = each.value.name
  type    = each.value.type

  content = each.value.type == "CAA" ? null : each.value.content

  ttl = (
    coalesce(lookup(each.value, "proxied", null), false)
    ? 1
    : lookup(each.value, "ttl", 3600)
  )

  proxied  = each.value.type == "CAA" ? null : lookup(each.value, "proxied", false)
  priority = each.value.type == "MX" ? lookup(each.value, "priority", null) : null

  dynamic "data" {
    for_each = each.value.type == "CAA" ? [1] : []
    content {
      flags = lookup(each.value, "flags", 0)
      tag   = each.value.tag
      value = each.value.content
    }
  }
}