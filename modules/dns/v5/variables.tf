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
}
