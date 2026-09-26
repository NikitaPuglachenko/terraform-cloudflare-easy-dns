variables {
  root_domain = "example.com"
  records = {
    "@" = {
      A              = [{ content = "30.40.50.61", proxied = true }]
      "_dmarc.TXT"   = [{ content = "v=DMARC1" }]
      ALIASES        = [{ content = "www" }]
      "mail.ALIASES" = [{ content = "m2" }]
    }
    "app" = {
      A                     = [{ content = "30.40.50.60" }]
      MX                    = [{ content = "mx.example.com", priority = 5 }]
      CAA                   = [{ content = "letsencrypt.org", tag = "issue" }]
      "_acme-challenge.TXT" = [{ content = "tok" }]
      "cdn.ALIASES"         = [{ content = "static", ttl = 1800 }]
    }
  }
}

run "flattening" {
  command = plan

  assert {
    condition     = length(output.flat_records) == 9
    error_message = "Unexpected number of records"
  }

  assert {
    condition     = output.flat_records["_dmarc.TXT_@_0"].name == "_dmarc" && output.flat_records["_dmarc.TXT_@_0"].type == "TXT"
    error_message = "Nested name in apex"
  }

  assert {
    condition     = output.flat_records["_acme-challenge.TXT_app_0"].name == "_acme-challenge.app"
    error_message = "Nested name"
  }

  assert {
    condition     = output.flat_records["ALIASES_@_www"].content == "example.com" && output.flat_records["ALIASES_@_www"].type == "CNAME"
    error_message = "Apex alias"
  }

  assert {
    condition     = output.flat_records["ALIASES_INLINE_@_mail.ALIASES_0_m2"].content == "mail.example.com"
    error_message = "Apex inline alias"
  }

  assert {
    condition     = output.flat_records["ALIASES_INLINE_app_cdn.ALIASES_0_static"].content == "cdn.app.example.com" && output.flat_records["ALIASES_INLINE_app_cdn.ALIASES_0_static"].ttl == 1800
    error_message = "Inline alias"
  }

  assert {
    condition     = output.flat_records["A_app_0"].ttl == 3600 && output.flat_records["A_app_0"].proxied == false
    error_message = "Defaults"
  }
}

run "unsupported_type" {
  command = plan

  variables {
    records = { "app" = { SRV = [{ content = "x" }] } }
  }

  expect_failures = [var.records]
}

run "missing_content" {
  command = plan

  variables {
    records = { "app" = { A = [{ proxied = true }] } }
  }

  expect_failures = [var.records]
}

run "invalid_ttl" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "1.2.3.4", ttl = 5 }] } }
  }

  expect_failures = [var.records]
}

run "proxied_txt" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ content = "x", proxied = true }] } }
  }

  expect_failures = [var.records]
}

run "mx_without_priority" {
  command = plan

  variables {
    records = { "app" = { MX = [{ content = "mx.example.com" }] } }
  }

  expect_failures = [var.records]
}

run "caa_without_tag" {
  command = plan

  variables {
    records = { "app" = { CAA = [{ content = "letsencrypt.org" }] } }
  }

  expect_failures = [var.records]
}
