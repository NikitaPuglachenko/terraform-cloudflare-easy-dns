# Matching of records that already exist in the zone to the configured records,
# so they can be adopted with import blocks instead of being created again

locals {
  # Values are compared case-insensitively and without a trailing dot; TXT values
  # without quotes, since Cloudflare may return them quoted and split into chunks
  existing = [
    for r in var.existing_records : {
      id   = r.id
      name = lower(trimsuffix(r.name, "."))
      type = r.type
      content = r.content == null ? null : (
        r.type == "TXT" ? replace(replace(r.content, "\" \"", ""), "\"", "") : lower(trimsuffix(r.content, "."))
      )
      data = coalesce(r.data, {})
    }
  ]

  import_matches = {
    for key, rec in local.flat_records : key => [
      for e in local.existing : e.id
      if e.type == rec.type
      && e.name == lower(rec.name == "@" ? var.root_domain : "${rec.name}.${var.root_domain}")
      && (
        rec.data == null
        ? e.content == (rec.type == "TXT" ? replace(replace(rec.content, "\" \"", ""), "\"", "") : lower(trimsuffix(rec.content, ".")))
        : alltrue([for field, value in rec.data : lower(trimsuffix(lookup(e.data, field, ""), ".")) == lower(trimsuffix(value, "."))])
      )
    ]
  }

  # Only unambiguous matches: records with no match are new, records with several
  # matches (duplicates in the zone) are left for manual review
  import_record_ids = {
    for key, ids in local.import_matches : key => ids[0]
    if length(ids) == 1
  }
}
