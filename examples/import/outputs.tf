output "import_ids" {
  description = "Records found in the zone and imported"
  value       = module.dns.import_ids
}

output "import_duplicates" {
  description = "Records that match several existing records, which are not imported: remove the duplicates from the zone"
  value       = module.dns.import_duplicates
}
