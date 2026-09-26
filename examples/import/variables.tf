variable "zone_id" {
  description = "Cloudflare Zone ID"
  type        = string
}

variable "zone_name" {
  description = "Zone domain name"
  type        = string
  default     = "example.com"
}
