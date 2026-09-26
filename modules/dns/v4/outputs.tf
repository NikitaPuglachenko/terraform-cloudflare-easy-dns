output "record_names" {
  description = "Hostnames of all managed records"
  value       = [for r in cloudflare_record.record : r.hostname]
}
