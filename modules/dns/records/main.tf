# The core module turns the records input into a flat map of records for for_each, with
# no resources of its own. The steps, one file each:
#
#   names.tf   entries of the input and their fully qualified names
#   keys.tf    resolved records (ALIASES as CNAMEs, defaults applied) and their keys
#   checks.tf  invariants over all records: duplicates, CNAME conflicts, TTLs,
#              wildcards, self-references (output preconditions in outputs.tf)
#   import.tf  matching of existing_records for import
#
# Checks of single values are validations of var.records in variables.tf.

locals {
  # Record types defined by structured data instead of content
  data_types = ["CERT", "DNSKEY", "DS", "HTTPS", "LOC", "NAPTR", "SMIMEA", "SRV", "SSHFP", "SVCB", "TLSA", "URI"]
}
