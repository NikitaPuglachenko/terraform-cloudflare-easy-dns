# Migration from the v4 wrapper: the state of cloudflare_record is moved to
# cloudflare_dns_record without recreating records. Kept in its own file so a copy
# of the module that never used the v4 wrapper can leave it out (the v5-only
# release archive does).
moved {
  from = cloudflare_record.record
  to   = cloudflare_dns_record.record
}
