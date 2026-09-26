output "record_names" {
  description = "Names of all managed records"
  value       = module.v5.record_names
}

output "records" {
  description = "Managed records keyed by their stable identifier, with id, name, type and content"
  value       = module.v5.records
}

output "state_migration" {
  description = "Map of record keys used by module versions 1.x to the current keys, for state migration"
  value       = module.v5.state_migration
}

output "import_ids" {
  description = "Import IDs (<zone_id>/<record_id>) of records that already exist in the zone, keyed by record key. Empty unless import_existing is true; records with no or several matches are left out"
  value       = module.v5.import_ids
}
