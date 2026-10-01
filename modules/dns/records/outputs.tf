output "flat_records" {
  description = "Flattened map of records keyed by \"<name> <TYPE> <value>\", ready for for_each"
  value       = local.flat_records

  precondition {
    condition     = length(local.duplicates) == 0
    error_message = "Duplicate records (remove the duplicates or set a unique key for each of them; MX records that differ only in priority and CAA records that differ only in flags have the same key and need a key too):\n${join("\n", local.duplicates)}"
  }

  precondition {
    condition     = length(local.cname_conflicts) == 0
    error_message = "A CNAME record cannot share its name with other records (except at the zone apex), and a name has at most one CNAME. Names that already have a CNAME next to other records in the zone can be listed in allowed_cname_conflicts:\n${join("\n", local.cname_conflicts)}"
  }
}

output "state_migration" {
  description = "Map of record keys used by module versions 1.x to the current keys, for state migration"
  value       = local.state_migration
}

output "import_record_ids" {
  description = "Cloudflare record IDs of existing_records matching the configured records, keyed by record key. Records with no or several matches are left out"
  value       = local.import_record_ids
}
