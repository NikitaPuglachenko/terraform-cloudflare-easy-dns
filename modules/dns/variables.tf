variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "records" {
  type = map(
    map(
      list(
        object({
          content  = optional(string)
          ttl      = optional(number)
          proxied  = optional(bool)
          priority = optional(number)

          # for CAA
          tag   = optional(string)
          flags = optional(number)
        })
      )
    )
  )
}