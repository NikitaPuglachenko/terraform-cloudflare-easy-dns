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
        })
      )
    )
  )
}
