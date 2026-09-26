mock_provider "cloudflare" {}

variables {
  zone_id = "z"
}

run "plan" {
  command = plan

  assert {
    condition     = length(module.dns.record_names) == 13
    error_message = "Unexpected number of records"
  }
}
