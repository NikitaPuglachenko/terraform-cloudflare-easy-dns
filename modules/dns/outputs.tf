output "record_names" {
  value = [for r in cloudflare_record.record : r.hostname]
}

