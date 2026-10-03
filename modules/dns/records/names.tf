# Entries of the input and their names. A name may be written short ("www"), fully
# qualified ("www.example.com"), as "@" or as the zone name, in any case; qualified and
# fqdn map every form to one name, which all comparisons use.

locals {
  # The zone name as compared and appended: without a trailing dot ("example.com." and
  # "example.com" are the same zone)
  zone = trimsuffix(var.root_domain, ".")

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
          source    = "records[\"${base_name}\"][\"${raw_key}\"][${idx}]"
        }
      ]
    ]
  ])

  # Record names as written: ALIASES name the CNAME by their content, prefixes are
  # prepended to the base name
  entry_names = [
    for e in local.entries : (
      element(split(".", e.raw_key), length(split(".", e.raw_key)) - 1) == "ALIASES" ? e.rec.content :
      length(split(".", e.raw_key)) == 1 ? e.base_name :
      e.base_name == "@" ? join(".", slice(split(".", e.raw_key), 0, length(split(".", e.raw_key)) - 1)) :
      "${join(".", slice(split(".", e.raw_key), 0, length(split(".", e.raw_key)) - 1))}.${e.base_name}"
    )
  ]

  # Every name fully qualified, in one place: "@" is the zone name, a name that
  # already ends with the zone name is kept, any other name gets the zone name
  # appended. qualified keeps the case as written (alias targets), fqdn is lower
  # case (comparisons). For base names, record names, allowed_cname_conflicts.
  qualified = {
    for n in distinct(concat(keys(var.records), local.entry_names, var.allowed_cname_conflicts)) : n => (
      trimsuffix(n, ".") == "@" ? local.zone :
      lower(trimsuffix(n, ".")) == lower(local.zone) || endswith(lower(trimsuffix(n, ".")), ".${lower(local.zone)}") ? trimsuffix(n, ".") :
      "${trimsuffix(n, ".")}.${local.zone}"
    )
  }
  fqdn = { for n, q in local.qualified : n => lower(q) }
}
