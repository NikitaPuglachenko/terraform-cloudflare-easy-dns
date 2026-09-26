output "record_names" {
  description = "Names of all managed records"
  value       = [for r in cloudflare_dns_record.record : r.name]
}

output "records" {
  description = "Managed records keyed by their stable identifier, with id, name, type and content"
  value = {
    for key, r in cloudflare_dns_record.record : key => {
      id      = r.id
      name    = r.name
      type    = r.type
      content = r.content
    }
  }
}

output "state_migration" {
  description = "Map of record keys used by module versions 1.x to the current keys, for state migration"
  value       = module.records.state_migration
}
