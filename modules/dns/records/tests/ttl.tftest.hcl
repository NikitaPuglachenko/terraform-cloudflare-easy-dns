# TTL boundaries: 1 (automatic), minimum_ttl (60, or 30 on Enterprise zones) to 86400.
# Values out of the range for every plan fail in the validation of records; values
# below minimum_ttl fail in a precondition of output.flat_records, with a hint

variables {
  root_domain = "example.com"
  records     = {}
}

run "valid_ttls" {
  command = plan

  variables {
    records = { "app" = { A = [
      { content = "192.0.2.1", ttl = 1 },
      { content = "192.0.2.2", ttl = 60 },
      { content = "192.0.2.3", ttl = 86400 },
    ] } }
  }

  assert {
    condition     = [for ip in ["192.0.2.1", "192.0.2.2", "192.0.2.3"] : output.flat_records["app A ${ip}"].ttl] == [1, 60, 86400]
    error_message = "1, 60 and 86400 are valid on every plan"
  }
}

run "enterprise_ttls" {
  command = plan

  variables {
    minimum_ttl = 30
    default_ttl = 30
    records     = { "app" = { A = [{ content = "192.0.2.1" }, { content = "192.0.2.2", ttl = 59 }] } }
  }

  assert {
    condition     = output.flat_records["app A 192.0.2.1"].ttl == 30 && output.flat_records["app A 192.0.2.2"].ttl == 59
    error_message = "30 to 59 are valid with minimum_ttl = 30"
  }
}

run "ttl_29" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 29 }] } }
  }

  expect_failures = [var.records]
}

run "ttl_86401" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 86401 }] } }
  }

  expect_failures = [var.records]
}

run "ttl_0" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 0 }] } }
  }

  expect_failures = [var.records]
}

run "ttl_30_without_enterprise" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 30 }] } }
  }

  expect_failures = [output.flat_records]
}

run "ttl_59_without_enterprise" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 59 }] } }
  }

  expect_failures = [output.flat_records]
}

run "ttl_29_on_enterprise" {
  command = plan

  variables {
    minimum_ttl = 30
    records     = { "app" = { A = [{ content = "192.0.2.1", ttl = 29 }] } }
  }

  expect_failures = [var.records]
}

# Proxied records are not checked against minimum_ttl: Cloudflare sets their TTL to 1,
# which the wrappers send (ttl = 1 for proxied records)
run "proxied_record_with_a_low_ttl" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "192.0.2.1", ttl = 30, proxied = true }] } }
  }

  assert {
    condition     = output.flat_records["app A 192.0.2.1"].proxied
    error_message = "A proxied record with a TTL below minimum_ttl is accepted"
  }
}
