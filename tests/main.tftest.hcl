# The root module passes everything to the v5 wrapper; the wrapper and the core
# have their own tests.

mock_provider "cloudflare" {}

variables {
  zone_id   = "z"
  zone_name = "example.com"
  records = {
    "@"   = { A = [{ content = "192.0.2.1" }], ALIASES = [{ content = "www" }] }
    "app" = { TXT = [{ content = "v=spf1 -all", key = "spf" }] }
  }
}

run "plan" {
  command = plan

  assert {
    condition     = length(output.record_names) == 3
    error_message = "All records must be planned through the v5 wrapper"
  }

  assert {
    condition     = module.v5.state_migration["ALIASES_@_www"] == "www CNAME"
    error_message = "Outputs of the v5 wrapper must be passed through"
  }

  assert {
    condition     = output.import_ids == {}
    error_message = "No import lookup unless import_existing is true"
  }
}

run "unknown_attribute" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", proxid = true }] } }
  }

  expect_failures = [var.records]
}

run "unknown_settings_attribute" {
  command = plan

  variables {
    records = { "app" = { AAAA = [{ content = "2001:db8::1", settings = { ipv6_onyl = true } }] } }
  }

  expect_failures = [var.records]
}

run "record_is_not_an_object" {
  command = plan

  variables {
    records = { "app" = { A = ["192.0.2.1"] } }
  }

  expect_failures = [var.records]
}
