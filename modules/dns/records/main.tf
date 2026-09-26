locals {
  # Record types defined by structured data instead of content
  data_types = ["CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI"]

  # One entry per record in the input, with the parts of its key split out:
  # "_acme-challenge.TXT" -> prefix "_acme-challenge", kind "TXT"
  entries = flatten([
    for base_name, type_map in var.records : [
      for raw_key, recs in type_map : [
        for idx, rec in recs : {
          rec       = rec
          base_name = base_name
          raw_key   = raw_key
          idx       = idx
          prefix    = length(split(".", raw_key)) > 1 ? join(".", slice(split(".", raw_key), 0, length(split(".", raw_key)) - 1)) : null
          kind      = element(split(".", raw_key), length(split(".", raw_key)) - 1)
          base_fqdn = base_name == "@" ? var.root_domain : "${base_name}.${var.root_domain}"
          source    = "records[\"${base_name}\"][\"${raw_key}\"][${idx}]"
        }
      ]
    ]
  ])

  # Resolved records: ALIASES become CNAMEs, prefixes are prepended to the base name
  resolved = [
    for e in local.entries : {
      rec     = e.rec
      source  = e.source
      name    = e.kind == "ALIASES" ? e.rec.content : e.prefix == null ? e.base_name : e.base_name == "@" ? e.prefix : "${e.prefix}.${e.base_name}"
      type    = e.kind == "ALIASES" ? "CNAME" : e.kind
      content = e.kind == "ALIASES" ? (e.prefix == null ? e.base_fqdn : "${e.prefix}.${e.base_fqdn}") : e.rec.content

      # Key used by module versions 1.x, for state migration
      old_key = (
        e.kind == "ALIASES" && e.prefix == null ? "ALIASES_${e.base_name}_${e.rec.content}" :
        e.kind == "ALIASES" ? "ALIASES_INLINE_${e.base_name}_${e.raw_key}_${e.idx}_${e.rec.content}" :
        e.raw_key == "CAA" ? "CAA_${e.base_name}_${e.rec.tag}_${e.rec.content}_${e.rec.flags}" :
        "${e.raw_key}_${e.base_name}_${e.idx}"
      )
    }
  ]

  # Keys follow the zone file format: "<name> <TYPE> <value>"
  records = [
    for r in local.resolved : {
      key = (
        r.rec.key != null ? "${r.name} ${r.type} ${r.rec.key}" :
        r.type == "CNAME" ? "${r.name} CNAME" :
        r.type == "CAA" ? "${r.name} CAA ${r.rec.tag} ${r.content}" :
        r.type == "TXT" ? "${r.name} TXT ${substr(sha1(r.content), 0, 12)}" :
        contains(local.data_types, r.type) ? "${r.name} ${r.type} ${substr(sha1(jsonencode(r.rec.data)), 0, 12)}" :
        "${r.name} ${r.type} ${r.content}"
      )
      old_key = r.old_key
      source  = r.source
      name    = r.name
      type    = r.type
      content = r.type == "CAA" || contains(local.data_types, r.type) ? null : r.content
      ttl     = coalesce(r.rec.ttl, var.default_ttl)
      proxied = (
        r.rec.proxied != null ? r.rec.proxied :
        contains(["A", "AAAA", "CNAME"], r.type) ? var.default_proxied :
        false
      )
      comment  = r.rec.comment != null ? r.rec.comment : var.default_comment
      tags     = distinct(concat(var.default_tags, coalesce(r.rec.tags, [])))
      settings = r.rec.settings
      priority = contains(["MX", "URI"], r.type) ? r.rec.priority : r.type == "SRV" ? tonumber(r.rec.data.priority) : null
      data = (
        r.type == "CAA" ? tomap({ flags = tostring(r.rec.flags), tag = r.rec.tag, value = r.content }) :
        # Cloudflare returns SVCB and HTTPS targets as fully qualified names, so they
        # get the trailing dot here to avoid a diff on every plan
        contains(["HTTPS", "SVCB"], r.type) ? merge(r.rec.data, {
          target = endswith(r.rec.data.target, ".") ? r.rec.data.target : "${r.rec.data.target}."
        }) :
        contains(local.data_types, r.type) ? r.rec.data :
        null
      )
    }
  ]

  grouped = { for r in local.records : r.key => r... }
  duplicates = [
    for key, group in local.grouped : "\"${key}\" from ${join(" and ", [for r in group : r.source])}"
    if length(group) > 1
  ]

  # A CNAME cannot share its name with other records, except at the zone apex (CNAME flattening)
  by_name = { for r in local.records : lower(r.name) => r... }
  cname_conflicts = [
    for name, group in local.by_name : "\"${name}\": ${join(", ", [for r in group : "${r.type} from ${r.source}"])}"
    if name != "@" && anytrue([for r in group : r.type == "CNAME"]) && anytrue([for r in group : r.type != "CNAME"])
  ]

  flat_records = {
    for key, group in local.grouped : key => {
      name     = group[0].name
      type     = group[0].type
      content  = group[0].content
      ttl      = group[0].ttl
      proxied  = group[0].proxied
      comment  = group[0].comment
      tags     = group[0].tags
      settings = group[0].settings
      priority = group[0].priority
      data     = group[0].data
    }
  }

  state_migration = {
    for r in local.records : r.old_key => r.key if r.old_key != r.key
  }
}
