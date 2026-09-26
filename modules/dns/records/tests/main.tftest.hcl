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
      A                       = [{ content = "30.40.50.60" }, { content = "30.40.50.70" }]
      MX                      = [{ content = "mx.example.com", priority = 5 }]
      CAA                     = [{ content = "letsencrypt.org", tag = "issue" }]
      "_acme-challenge.TXT"   = [{ content = "tok" }]
      "cdn.ALIASES"           = [{ content = "static", ttl = 1800 }]
      "google._domainkey.TXT" = [{ content = "v=DKIM1; p=abc", key = "dkim" }]
    }
  }
}

run "flattening" {
  command = plan

  assert {
    condition     = length(output.flat_records) == 11
    error_message = "Unexpected number of records"
  }

  assert {
    condition     = output.flat_records["_dmarc TXT ${substr(sha1("v=DMARC1"), 0, 12)}"].name == "_dmarc"
    error_message = "Nested name in apex"
  }

  assert {
    condition     = output.flat_records["_acme-challenge.app TXT ${substr(sha1("tok"), 0, 12)}"].name == "_acme-challenge.app"
    error_message = "Nested name"
  }

  assert {
    condition     = output.flat_records["www CNAME"].content == "example.com"
    error_message = "Apex alias"
  }

  assert {
    condition     = output.flat_records["m2 CNAME"].content == "mail.example.com"
    error_message = "Apex inline alias"
  }

  assert {
    condition     = output.flat_records["static CNAME"].content == "cdn.app.example.com" && output.flat_records["static CNAME"].ttl == 1800
    error_message = "Inline alias"
  }

  assert {
    condition     = output.flat_records["app A 30.40.50.70"].ttl == 3600 && output.flat_records["app A 30.40.50.70"].proxied == false
    error_message = "Defaults"
  }

  assert {
    condition     = output.flat_records["app MX mx.example.com"].priority == 5
    error_message = "MX"
  }

  assert {
    condition     = output.flat_records["app CAA issue letsencrypt.org"].data.tag == "issue" && output.flat_records["app CAA issue letsencrypt.org"].data.flags == "0" && output.flat_records["app CAA issue letsencrypt.org"].content == null
    error_message = "CAA"
  }

  assert {
    condition     = output.flat_records["google._domainkey.app TXT dkim"].content == "v=DKIM1; p=abc"
    error_message = "Explicit key"
  }
}

run "state_migration" {
  command = plan

  assert {
    condition = output.state_migration == {
      "A_@_0"                                   = "@ A 30.40.50.61"
      "_dmarc.TXT_@_0"                          = "_dmarc TXT ${substr(sha1("v=DMARC1"), 0, 12)}"
      "ALIASES_@_www"                           = "www CNAME"
      "ALIASES_INLINE_@_mail.ALIASES_0_m2"      = "m2 CNAME"
      "A_app_0"                                 = "app A 30.40.50.60"
      "A_app_1"                                 = "app A 30.40.50.70"
      "MX_app_0"                                = "app MX mx.example.com"
      "CAA_app_issue_letsencrypt.org_0"         = "app CAA issue letsencrypt.org"
      "_acme-challenge.TXT_app_0"               = "_acme-challenge.app TXT ${substr(sha1("tok"), 0, 12)}"
      "ALIASES_INLINE_app_cdn.ALIASES_0_static" = "static CNAME"
      "google._domainkey.TXT_app_0"             = "google._domainkey.app TXT dkim"
    }
    error_message = "Unexpected state migration map"
  }
}

run "duplicate_records" {
  command = plan

  variables {
    records = {
      "app" = {
        A       = [{ content = "1.2.3.4" }, { content = "1.2.3.4" }]
        ALIASES = [{ content = "www" }]
      }
      "www" = { CNAME = [{ content = "other.example.com" }] }
    }
  }

  expect_failures = [output.flat_records]
}

run "invalid_key" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ content = "x", key = "my key" }] } }
  }

  expect_failures = [var.records]
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

run "data_types" {
  command = plan

  variables {
    records = {
      "_sip._tcp" = {
        SRV = [{ data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } }]
      }
      "@" = {
        HTTPS      = [{ key = "h3", data = { priority = 1, target = ".", value = "alpn=\"h3,h2\"" } }]
        OPENPGPKEY = [{ content = "mQINBGE" }]
      }
      "_ftp._tcp" = {
        URI = [{ priority = 10, data = { weight = 1, target = "ftp://ftp.example.com/" } }]
      }
      "_25._tcp.mail" = {
        TLSA = [{ key = "mx", data = { usage = 3, selector = 1, matching_type = 1, certificate = "abcdef" } }]
      }
      "office" = {
        LOC = [{ key = "hq", data = { lat_degrees = 59, lat_minutes = 26, lat_seconds = 14, lat_direction = "N", long_degrees = 24, long_minutes = 44, long_seconds = 43, long_direction = "E" } }]
      }
    }
  }

  assert {
    condition     = output.flat_records["_sip._tcp SRV ${substr(sha1(jsonencode({ priority = "10", weight = "5", port = "5060", target = "sip.example.com" })), 0, 12)}"].priority == 10
    error_message = "SRV key is a hash of the data, priority comes from the data"
  }

  assert {
    condition     = output.flat_records["@ HTTPS h3"].content == null && output.flat_records["@ HTTPS h3"].data.target == "." && output.flat_records["@ HTTPS h3"].priority == null
    error_message = "HTTPS"
  }

  assert {
    condition     = output.flat_records["@ OPENPGPKEY mQINBGE"].content == "mQINBGE" && output.flat_records["@ OPENPGPKEY mQINBGE"].data == null
    error_message = "OPENPGPKEY uses content"
  }

  assert {
    condition     = one([for k, r in output.flat_records : r.priority if r.type == "URI"]) == 10
    error_message = "URI priority"
  }

  assert {
    condition     = output.flat_records["_25._tcp.mail TLSA mx"].data.usage == "3" && output.flat_records["office LOC hq"].data.lat_direction == "N"
    error_message = "TLSA and LOC data"
  }
}

run "data_on_content_type" {
  command = plan

  variables {
    records = { "app" = { A = [{ content = "1.2.3.4", data = { target = "x" } }] } }
  }

  expect_failures = [var.records]
}

run "srv_without_data" {
  command = plan

  variables {
    records = { "_sip._tcp" = { SRV = [{ content = "sip.example.com" }] } }
  }

  expect_failures = [var.records]
}

run "srv_missing_field" {
  command = plan

  variables {
    records = { "_sip._tcp" = { SRV = [{ data = { priority = 10, weight = 5, target = "sip.example.com" } }] } }
  }

  expect_failures = [var.records]
}

run "srv_unknown_field" {
  command = plan

  variables {
    records = { "_sip._tcp" = { SRV = [{ data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com", proto = "_tcp" } }] } }
  }

  expect_failures = [var.records]
}

run "uri_without_priority" {
  command = plan

  variables {
    records = { "_ftp._tcp" = { URI = [{ data = { weight = 1, target = "ftp://ftp.example.com/" } }] } }
  }

  expect_failures = [var.records]
}
