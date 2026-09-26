locals {
  flat_records_regular = merge([
    for base_name, type_map in var.records : merge([
      for raw_key, recs in type_map : (
        raw_key == "ALIASES" || endswith(raw_key, ".ALIASES")
        ) ? {} : {
        for idx, rec in recs :
        (
          raw_key == "CAA"
          ? "${raw_key}_${base_name}_${lookup(rec, "tag", "na")}_${lookup(rec, "content", "na")}_${lookup(rec, "flags", 0)}"
          : "${raw_key}_${base_name}_${idx}"
          ) => merge(
          rec,
          length(split(".", raw_key)) > 1 ? {
            name = (
              base_name == "@"
              ? join(".", slice(split(".", raw_key), 0, length(split(".", raw_key)) - 1))
              : format(
                "%s.%s",
                join(".", slice(split(".", raw_key), 0, length(split(".", raw_key)) - 1)),
                base_name
              )
            )
            type = element(split(".", raw_key), length(split(".", raw_key)) - 1)
            } : {
            name = base_name
            type = raw_key
          }
        )
      }
    ]...)
  ]...)

  flat_records_aliases_legacy = merge([
    for name, type_map in var.records : merge([
      for type, recs in type_map : type != "ALIASES" ? {} : {
        for idx, rec in recs :
        "ALIASES_${name}_${rec.content}" => {
          name     = rec.content
          type     = "CNAME"
          content  = name == "@" ? var.root_domain : "${name}.${var.root_domain}"
          ttl      = rec.ttl
          proxied  = rec.proxied
          priority = null
        }
      }
    ]...)
  ]...)

  flat_records_aliases_inline = merge([
    for base_name, type_map in var.records : merge([
      for raw_key, recs in type_map : !endswith(raw_key, ".ALIASES") ? {} : {
        for idx, rec in recs :
        "ALIASES_INLINE_${base_name}_${raw_key}_${idx}_${rec.content}" => {
          name = rec.content
          type = "CNAME"
          content = format(
            "%s.%s",
            join(".", slice(split(".", raw_key), 0, length(split(".", raw_key)) - 1)),
            base_name == "@" ? var.root_domain : "${base_name}.${var.root_domain}"
          )
          ttl      = rec.ttl
          proxied  = rec.proxied
          priority = null
        }
      }
    ]...)
  ]...)

  flat_records_all = merge(
    local.flat_records_regular,
    local.flat_records_aliases_legacy,
    local.flat_records_aliases_inline,
  )
}
