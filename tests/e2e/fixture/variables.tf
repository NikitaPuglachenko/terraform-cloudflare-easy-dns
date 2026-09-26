variable "prefix" {
  description = "Label that all record names of the run start with or contain"
  type        = string
}

variable "zone_name" {
  description = "Zone domain name"
  type        = string
}

variable "a_value" {
  description = "IPv4 address of the record without a key, changed to check replacement"
  type        = string
  default     = "192.0.2.10"
}

variable "txt_value" {
  description = "Value of the TXT record with a key, changed to check an in-place update"
  type        = string
  default     = "rotation=1"
}
