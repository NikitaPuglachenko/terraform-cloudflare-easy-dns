output "flat_records" {
  description = "Flattened map of records, keyed by a stable identifier, ready for for_each"
  value       = local.flat_records_all
}
