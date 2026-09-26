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

          # Record settings, provider v5 only (ignored by the v4 wrapper)
          settings = optional(object({
            flatten_cname = optional(bool)
            ipv4_only     = optional(bool)
            ipv6_only     = optional(bool)
          }))
        })
      )
    )
  )
}

variable "import_existing" {
  description = "Look up records that already exist in the zone and expose their IDs in the import_ids output, to adopt them with import blocks. Requires the DNS Read permission"
  type        = bool
  default     = false
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
