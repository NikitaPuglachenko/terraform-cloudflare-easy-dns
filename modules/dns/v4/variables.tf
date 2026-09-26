variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "zone_name" {
  description = "Zone domain name (e.g. example.com). If null, it is looked up from zone_id"
  type        = string
  default     = null
}

variable "records" {
  description = <<-EOT
    DNS records: `records[NAME][TYPE] = [RECORD, ...]`, where NAME is a name within the
    zone (`@` for the apex) and TYPE a record type, optionally with a prefix
    (`"_acme-challenge.TXT"`). Record attributes: `content`, `ttl`, `proxied`, `priority`,
    `tag`, `flags`, `data`, `key`, `comment`, `tags` and `settings` (`flatten_cname`,
    `ipv4_only`, `ipv6_only`). See the README for the details. Unknown attributes fail at plan.
  EOT
  # Not a typed object: Terraform silently drops unknown attributes when converting to an
  # object type, so misspelled attributes are checked here and the typed structure is
  # built by the records module
  type = any

  validation {
    condition = try(alltrue(flatten([
      for name, types in var.records : [
        for type, list in types : [
          for record in list : (
            can(keys(record))
            && length(setsubtract(keys(record), ["content", "ttl", "proxied", "priority", "tag", "flags", "data", "key", "comment", "tags", "settings"])) == 0
            && (try(record.settings, null) == null || length(setsubtract(try(keys(record.settings), ["?"]), ["flatten_cname", "ipv4_only", "ipv6_only"])) == 0)
          )
        ]
      ]
    ])), false)
    error_message = try(
      "Invalid records (allowed attributes: content, ttl, proxied, priority, tag, flags, data, key, comment, tags, settings):\n${join("\n", flatten([
        for name, types in var.records : [
          for type, list in types : [
            for index, record in list : concat(
              can(keys(record)) ? [] : ["records[\"${name}\"][\"${type}\"][${index}] must be an object"],
              [for attribute in setsubtract(try(keys(record), []), ["content", "ttl", "proxied", "priority", "tag", "flags", "data", "key", "comment", "tags", "settings"]) : "records[\"${name}\"][\"${type}\"][${index}]: unknown attribute \"${attribute}\""],
              [for attribute in setsubtract(try(keys(record.settings), []), ["flatten_cname", "ipv4_only", "ipv6_only"]) : "records[\"${name}\"][\"${type}\"][${index}].settings: unknown attribute \"${attribute}\""]
            )
          ]
        ]
      ]))}",
      "records must be a map of names to maps of record types to lists of records."
    )
  }
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
