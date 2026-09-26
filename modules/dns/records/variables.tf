variable "root_domain" {
  description = "Zone domain name (e.g. example.com), used as the target suffix for aliases"
  type        = string
}

variable "records" {
  description = "DNS records grouped by base name (subdomain or @ for apex), then by record type"
  type = map(
    map(
      list(
        object({
          content  = optional(string)
          ttl      = optional(number, 3600)
          proxied  = optional(bool, false)
          priority = optional(number)

          # for CAA
          tag   = optional(string)
          flags = optional(number, 0)

          # Structured data for SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC
          data = optional(map(string))

          # Stable key instead of the record value, so changing the value updates the record in place
          key = optional(string)
        })
      )
    )
  )

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : contains(
          [
            "A", "AAAA", "CNAME", "MX", "NS", "PTR", "TXT", "OPENPGPKEY", "CAA", "ALIASES",
            "CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI",
          ],
          element(split(".", raw_key), length(split(".", raw_key)) - 1)
        )
      ]
    ]))
    error_message = "Unsupported record type. Supported: A, AAAA, CNAME, MX, NS, PTR, TXT, OPENPGPKEY, CAA, ALIASES, CERT, DNSKEY, DS, HTTPS, LOC, NAPTR, SMIMEA, SRV, SSHFP, SVCB, TLSA and URI (optionally with a prefix, e.g. \"_acme-challenge.TXT\")."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : rec.content != null && rec.content != ""
        ] if !contains(["CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI"], element(split(".", raw_key), length(split(".", raw_key)) - 1))
      ]
    ]))
    error_message = "Every record except SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC must have a non-empty content."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : (
            contains(["CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI"], element(split(".", raw_key), length(split(".", raw_key)) - 1))
            ? rec.data != null && length(coalesce(rec.data, {})) > 0
            : rec.data == null
          )
        ]
      ]
    ]))
    error_message = "SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC records require data; other record types must not set it."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : (
            length(setsubtract(keys(coalesce(rec.data, {})), lookup({
              SRV    = ["priority", "weight", "port", "target"]
              URI    = ["weight", "target"]
              HTTPS  = ["priority", "target", "value"]
              SVCB   = ["priority", "target", "value"]
              TLSA   = ["usage", "selector", "matching_type", "certificate"]
              SMIMEA = ["usage", "selector", "matching_type", "certificate"]
              SSHFP  = ["algorithm", "type", "fingerprint"]
              DS     = ["key_tag", "algorithm", "digest_type", "digest"]
              DNSKEY = ["flags", "protocol", "algorithm", "public_key"]
              CERT   = ["type", "key_tag", "algorithm", "certificate"]
              NAPTR  = ["order", "preference", "flags", "service", "regex", "replacement"]
              LOC = [
                "lat_degrees", "lat_minutes", "lat_seconds", "lat_direction",
                "long_degrees", "long_minutes", "long_seconds", "long_direction",
                "altitude", "size", "precision_horz", "precision_vert",
              ]
            }, element(split(".", raw_key), length(split(".", raw_key)) - 1), []))) == 0
            && length(setsubtract(lookup({
              SRV    = ["priority", "weight", "port", "target"]
              URI    = ["weight", "target"]
              HTTPS  = ["priority", "target"]
              SVCB   = ["priority", "target"]
              TLSA   = ["usage", "selector", "matching_type", "certificate"]
              SMIMEA = ["usage", "selector", "matching_type", "certificate"]
              SSHFP  = ["algorithm", "type", "fingerprint"]
              DS     = ["key_tag", "algorithm", "digest_type", "digest"]
              DNSKEY = ["flags", "protocol", "algorithm", "public_key"]
              CERT   = ["type", "key_tag", "algorithm", "certificate"]
              NAPTR  = ["order", "preference", "replacement"]
              LOC = [
                "lat_degrees", "lat_minutes", "lat_seconds", "lat_direction",
                "long_degrees", "long_minutes", "long_seconds", "long_direction",
              ]
            }, element(split(".", raw_key), length(split(".", raw_key)) - 1), []), keys(coalesce(rec.data, {})))) == 0
          )
        ] if contains(["CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI"], element(split(".", raw_key), length(split(".", raw_key)) - 1))
      ]
    ]))
    error_message = "Record data has unknown or missing fields. See \"Record Types\" in the README for the fields of each type."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : rec.ttl == 1 || (rec.ttl >= 30 && rec.ttl <= 86400)
        ]
      ]
    ]))
    error_message = "TTL must be 1 (automatic) or between 30 and 86400 seconds."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : !rec.proxied || contains(
            ["A", "AAAA", "CNAME", "ALIASES"],
            element(split(".", raw_key), length(split(".", raw_key)) - 1)
          )
        ]
      ]
    ]))
    error_message = "Only A, AAAA, CNAME and ALIASES records can be proxied."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : rec.priority != null
        ] if contains(["MX", "URI"], element(split(".", raw_key), length(split(".", raw_key)) - 1))
      ]
    ]))
    error_message = "MX and URI records require a priority."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : contains(["issue", "issuewild", "iodef"], coalesce(rec.tag, "none"))
        ] if element(split(".", raw_key), length(split(".", raw_key)) - 1) == "CAA"
      ]
    ]))
    error_message = "CAA records require a tag: issue, issuewild or iodef."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : rec.key == null || can(regex("^\\S+$", rec.key))
        ]
      ]
    ]))
    error_message = "Record key must be a non-empty string without whitespace."
  }
}
