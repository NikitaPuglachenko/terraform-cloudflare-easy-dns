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

  # Fully qualified, lower-case names, so "@" and the zone name, or "www" and
  # "www.example.com", are the same name; for record names and for the names in
  # allowed_cname_conflicts
  fqdn = {
    for n in distinct(concat([for r in local.resolved : r.name], var.allowed_cname_conflicts)) : n => (
      lower(trimsuffix(n, ".")) == "@" ? lower(var.root_domain) :
      lower(trimsuffix(n, ".")) == lower(var.root_domain) || endswith(lower(trimsuffix(n, ".")), ".${lower(var.root_domain)}") ? lower(trimsuffix(n, ".")) :
      "${lower(trimsuffix(n, "."))}.${lower(var.root_domain)}"
    )
  }

  # Keys follow the zone file format: "<name> <TYPE> <value>"
  keyed = [
    for r in local.resolved : merge(r, {
      key = (
        r.rec.key != null ? "${r.name} ${r.type} ${r.rec.key}" :
        r.type == "CNAME" ? "${r.name} CNAME" :
        r.type == "CAA" ? "${r.name} CAA ${r.rec.tag} ${r.content}" :
        r.type == "TXT" ? "${r.name} TXT ${substr(sha1(r.content), 0, 12)}" :
        contains(local.data_types, r.type) ? "${r.name} ${r.type} ${substr(sha1(jsonencode(r.rec.data)), 0, 12)}" :
        "${r.name} ${r.type} ${r.content}"
      )
    })
  ]

  records = [
    for r in local.keyed : {
      key     = r.key
      old_key = r.old_key
      source  = r.source
      name    = r.name
      fqdn    = local.fqdn[r.name]
      # The key without its name part, normalized like DNS compares it: addresses
      # and hostnames case-insensitively and without a trailing dot
      key_value = (
        r.rec.key == null && contains(["A", "AAAA", "MX", "NS", "PTR"], r.type)
        ? "${r.type} ${lower(trimsuffix(r.content, "."))}"
        : trimprefix(r.key, "${r.name} ")
      )
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
        # yamldecode reads an unquoted N as false (YAML 1.1); for LOC it can only mean north
        r.type == "LOC" ? merge(r.rec.data, lookup(r.rec.data, "lat_direction", "") == "false" ? { lat_direction = "N" } : {}) :
        contains(local.data_types, r.type) ? r.rec.data :
        null
      )
    }
  ]

  grouped = { for r in local.records : r.key => r... }

  # The same record written with different name forms ("www" and "www.example.com",
  # "@" and the zone name) gets different keys, so it is checked separately
  by_identity = { for r in local.records : "${r.fqdn} ${r.key_value}" => r... }

  duplicates = concat(
    [
      for key, group in local.grouped : "\"${key}\" from ${join(" and ", [for r in group : r.source])}"
      if length(group) > 1
    ],
    [
      for identity, group in local.by_identity : "\"${identity}\" as ${join(" and ", [for r in group : "\"${r.key}\" from ${r.source}"])}"
      if length(distinct([for r in group : r.key])) > 1
    ],
  )

  # A CNAME cannot share its name with other records, except at the zone apex (CNAME
  # flattening) and on names listed in allowed_cname_conflicts (existing zones,
  # where Cloudflare accepted it for records that are not proxied). A name never
  # has more than one CNAME, whatever keys the records have. Names are grouped
  # fully qualified.
  by_name = { for r in local.records : r.fqdn => r... }
  cname_shared = [
    for name, group in local.by_name : name
    if name != lower(var.root_domain) && anytrue([for r in group : r.type == "CNAME"]) && anytrue([for r in group : r.type != "CNAME"])
  ]
  allowed_cname_conflicts = distinct([for n in var.allowed_cname_conflicts : local.fqdn[n]])
  cname_conflicts = [
    for name, group in local.by_name : "\"${name}\": ${join(", ", [for r in group : "${r.type} from ${r.source}"])}"
    if length([for r in group : r if r.type == "CNAME"]) > 1
    || (contains(local.cname_shared, name) && !contains(local.allowed_cname_conflicts, name))
  ]
  # Listed names that no longer have a conflict, so the list does not keep growing
  unused_allowed_cname_conflicts = [for n in local.allowed_cname_conflicts : n if !contains(local.cname_shared, n)]

  flat_records = {
    for key, group in local.grouped : key => {
      # Cloudflare stores names in lower case; the key keeps the name as written
      name     = lower(group[0].name)
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

check "allowed_cname_conflicts_in_use" {
  assert {
    condition     = length(local.unused_allowed_cname_conflicts) == 0
    error_message = "allowed_cname_conflicts lists names without a CNAME conflict, which can be removed: ${join(", ", local.unused_allowed_cname_conflicts)}"
  }
}
