output "record_names" {
  description = "Hostnames of all managed records"
  value       = [for r in cloudflare_record.record : r.hostname]
}

output "records" {
  description = "Managed records keyed by their stable identifier, with id, name, type and content"
  value = {
    for key, r in cloudflare_record.record : key => {
      id      = r.id
      name    = r.hostname
      type    = r.type
      content = r.content
    }
  }
}
