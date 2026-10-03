variable "root_domain" {
  description = "Zone domain name (e.g. example.com), used as the target suffix for aliases"
  type        = string
}

variable "default_ttl" {
  description = "TTL of records that do not set one (1 means automatic)"
  type        = number
  default     = 3600

  validation {
    condition     = var.default_ttl == 1 || (var.default_ttl >= 30 && var.default_ttl <= 86400)
    error_message = "default_ttl must be 1 (automatic) or between 30 and 86400 seconds."
  }
}

variable "default_proxied" {
  description = "Whether A, AAAA, CNAME and ALIASES records that do not set proxied are proxied by Cloudflare"
  type        = bool
  default     = false
}

variable "default_comment" {
  description = "Comment of records that do not set one, e.g. \"Managed by Terraform\""
  type        = string
  default     = null
}

variable "default_tags" {
  description = "Tags added to all records, e.g. [\"managed-by:terraform\"] (tags require a Cloudflare plan that supports them)"
  type        = list(string)
  default     = []
}

variable "allowed_cname_conflicts" {
  description = "Names where a CNAME may share its name with other records, for existing zones that have such names (Cloudflare accepts them for records that are not proxied). Compared fully qualified and case-insensitively; a second CNAME on a name still fails"
  type        = list(string)
  default     = []
  nullable    = false
}

variable "records" {
  description = "DNS records grouped by base name (subdomain or @ for apex), then by record type"
  type = map(
    map(
      list(
        object({
          content  = optional(string)
          ttl      = optional(number) # default_ttl when not set
          proxied  = optional(bool)   # default_proxied when not set
          priority = optional(number)

          # for CAA
          tag   = optional(string)
          flags = optional(number, 0)

          # Structured data for SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC
          data = optional(map(string))

          # Stable key instead of the record value, so changing the value updates the record in place
          key = optional(string)

          # Shown in the Cloudflare dashboard: comment replaces default_comment, tags are added to default_tags
          comment = optional(string)
          tags    = optional(list(string))

          # Record settings (Cloudflare provider v5)
          settings = optional(object({
            flatten_cname = optional(bool)
            ipv4_only     = optional(bool)
            ipv6_only     = optional(bool)
          }))
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
          for rec in recs : rec.ttl == null || rec.ttl == 1 || (coalesce(rec.ttl, 1) >= 30 && coalesce(rec.ttl, 1) <= 86400)
        ]
      ]
    ]))
    error_message = "TTL must be 1 (automatic) or between 30 and 86400 seconds."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : !coalesce(rec.proxied, false) || contains(
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

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : concat(
        [base_name == "@" || can(regex("^(\\*|[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)(\\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)*$", base_name))],
        [
          for raw_key, recs in type_map :
          length(split(".", raw_key)) == 1 || can(regex("^(\\*|[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)(\\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)*$", join(".", slice(split(".", raw_key), 0, length(split(".", raw_key)) - 1))))
        ],
        [
          for raw_key, recs in type_map : [
            for rec in recs : rec.content == null || can(regex("^(\\*|[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)(\\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)*$", coalesce(rec.content, "x")))
          ] if element(split(".", raw_key), length(split(".", raw_key)) - 1) == "ALIASES"
        ]
      )
    ]))
    error_message = "Names, prefixes and ALIASES must be valid DNS names: labels of letters, digits, '_' and '-' (up to 63 characters) separated by dots, optionally starting with '*'."
  }

  validation {
    condition = alltrue(flatten([
      for base_name, type_map in var.records : [
        for raw_key, recs in type_map : [
          for rec in recs : (
            element(split(".", raw_key), length(split(".", raw_key)) - 1) == "A" ? can(cidrhost("${coalesce(rec.content, "x")}/32", 0)) && !strcontains(coalesce(rec.content, "x"), ":") :
            element(split(".", raw_key), length(split(".", raw_key)) - 1) == "AAAA" ? can(cidrhost("${coalesce(rec.content, "x")}/128", 0)) && strcontains(coalesce(rec.content, "x"), ":") :
            # Hostnames: labels of letters, digits, '_' and '-' (up to 63 characters)
            # separated by dots, at most 253 characters, an optional trailing dot; not an
            # IP address. "@" is the zone apex, and "." is a null MX (RFC 7505).
            contains(["CNAME", "MX", "NS", "PTR"], element(split(".", raw_key), length(split(".", raw_key)) - 1)) ? (
              coalesce(rec.content, "x") == "@"
              || (element(split(".", raw_key), length(split(".", raw_key)) - 1) == "MX" && coalesce(rec.content, "x") == ".")
              || (
                length(trimsuffix(coalesce(rec.content, "x"), ".")) <= 253
                && can(regex("^[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?(\\.[A-Za-z0-9_]([A-Za-z0-9_-]{0,61}[A-Za-z0-9_])?)*\\.?$", coalesce(rec.content, "x")))
                && !can(cidrhost("${trimsuffix(coalesce(rec.content, "x"), ".")}/32", 0))
              )
            ) :
            element(split(".", raw_key), length(split(".", raw_key)) - 1) == "TXT" ? length(coalesce(rec.content, "")) <= 2048 :
            true
          )
        ]
      ]
    ]))
    error_message = "A records need an IPv4 address and AAAA records an IPv6 address; CNAME, MX, NS and PTR records need a hostname (labels of letters, digits, '_' and '-' up to 63 characters, at most 253 in total, not an IP address; \"@\" for the zone apex, \".\" for a null MX); TXT values are limited to 2048 characters."
  }
}

variable "existing_records" {
  description = "Records that already exist in the zone, used to find import IDs. Names are fully qualified, as returned by the Cloudflare API"
  type = list(object({
    id      = string
    name    = string
    type    = string
    content = optional(string)
    data    = optional(map(string))
  }))
  default = []
}
