# Matching of records that already exist in the zone to the configured records,
# so they can be adopted with import blocks instead of being created again

locals {
  # Names, hostnames and hex values are compared case-insensitively and without a
  # trailing dot, other values exactly. TXT values are joined from the quoted chunks
  # Cloudflare may return them in, and one pair of surrounding quotes is dropped;
  # quotes inside the value still count. OPENPGPKEY content is base64, so it is
  # compared exactly.
  txt_chunks_joined = { for r in var.existing_records : r.id => r.content == null ? "" : replace(r.content, "\" \"", "") }
  existing = [
    for r in var.existing_records : {
      id   = r.id
      name = lower(trimsuffix(r.name, "."))
      type = r.type
      content = r.content == null ? null : (
        r.type == "TXT" ? (
          length(local.txt_chunks_joined[r.id]) >= 2 && startswith(local.txt_chunks_joined[r.id], "\"") && endswith(local.txt_chunks_joined[r.id], "\"")
          ? substr(local.txt_chunks_joined[r.id], 1, length(local.txt_chunks_joined[r.id]) - 2)
          : local.txt_chunks_joined[r.id]
        ) : contains(local.exact_content_types, r.type) ? r.content : lower(trimsuffix(r.content, "."))
      )
      data = coalesce(r.data, {})
    }
  ]

  # Record types whose content is not a hostname or an address
  exact_content_types = ["OPENPGPKEY"]

  # Fields of structured records that hold hostnames or hex strings
  case_insensitive_fields = ["target", "replacement", "digest", "fingerprint"]

  # CAA issue/issuewild values are "<issuer domain>[; parameters]": the domain is
  # compared like a hostname, the parameters (account URIs, ...) exactly
  caa_issuer_tags = ["issue", "issuewild"]

  configured_txt = {
    for key, rec in local.flat_records : key => replace(rec.content, "\" \"", "")
    if rec.type == "TXT"
  }

  import_matches = {
    for key, rec in local.flat_records : key => [
      for e in local.existing : e.id
      if e.type == rec.type
      && e.name == lower(rec.name == "@" ? var.root_domain : "${rec.name}.${var.root_domain}")
      && (
        rec.data == null
        ? e.content == (
          rec.type == "TXT" ? (
            length(local.configured_txt[key]) >= 2 && startswith(local.configured_txt[key], "\"") && endswith(local.configured_txt[key], "\"")
            ? substr(local.configured_txt[key], 1, length(local.configured_txt[key]) - 2)
            : local.configured_txt[key]
          ) : contains(local.exact_content_types, rec.type) ? rec.content : lower(trimsuffix(rec.content, "."))
        )
        : alltrue([
          for field, value in rec.data : (
            contains(local.case_insensitive_fields, field) || (field == "certificate" && contains(["TLSA", "SMIMEA"], rec.type))
            ? lower(trimsuffix(lookup(e.data, field, ""), ".")) == lower(trimsuffix(value, "."))
            : rec.type == "CAA" && field == "value" && contains(local.caa_issuer_tags, lookup(rec.data, "tag", ""))
            ? format("%s%s", lower(trimsuffix(trimspace(split(";", lookup(e.data, field, ""))[0]), ".")), substr(lookup(e.data, field, ""), length(split(";", lookup(e.data, field, ""))[0]), -1))
            == format("%s%s", lower(trimsuffix(trimspace(split(";", value)[0]), ".")), substr(value, length(split(";", value)[0]), -1))
            : lookup(e.data, field, "") == value
          )
        ])
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
