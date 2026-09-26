output "flat_records" {
  description = "Flattened map of records keyed by \"<name> <TYPE> <value>\", ready for for_each"
  value       = local.flat_records

  precondition {
    condition     = length(local.duplicates) == 0
    error_message = "Duplicate records (remove the duplicates or set a unique key for each of them):\n${join("\n", local.duplicates)}"
  }

  precondition {
    condition     = length(local.cname_conflicts) == 0
    error_message = "A CNAME record cannot share its name with other records (except at the zone apex):\n${join("\n", local.cname_conflicts)}"
  }
}

output "state_migration" {
  description = "Map of record keys used by module versions 1.x to the current keys, for state migration"
  value       = local.state_migration
}
