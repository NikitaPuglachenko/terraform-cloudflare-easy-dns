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
          ["A", "AAAA", "CNAME", "MX", "NS", "PTR", "TXT", "CAA", "ALIASES"],
          element(split(".", raw_key), length(split(".", raw_key)) - 1)
        )
      ]
    ]))
    error_message = "Supported record types are A, AAAA, CNAME, MX, NS, PTR, TXT, CAA and ALIASES (optionally with a prefix, e.g. \"_acme-challenge.TXT\")."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : rec.content != null && rec.content != ""
        ]
      ]
    ]))
    error_message = "Every record must have a non-empty content."
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
        ] if element(split(".", raw_key), length(split(".", raw_key)) - 1) == "MX"
      ]
    ]))
    error_message = "MX records require a priority."
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
