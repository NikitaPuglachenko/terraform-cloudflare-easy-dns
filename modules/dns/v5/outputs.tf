output "record_names" {
  description = "Names of all managed records"
  value       = [for r in cloudflare_dns_record.record : r.name]
}
