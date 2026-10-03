# Record identity: the key of a record is its Terraform address, so it must depend on
# the value or on an explicit key, never on the position in a list

variables {
  root_domain = "example.com"
  records = {
    "app" = {
      A   = [{ content = "192.0.2.1" }, { content = "192.0.2.2" }, { content = "192.0.2.3" }]
      TXT = [{ content = "v=spf1 -all" }, { content = "token" }]
      MX  = [{ content = "mx1.example.com", priority = 10 }, { content = "mx2.example.com", priority = 20 }]
    }
    "_sip._tcp" = {
      SRV = [
        { data = { priority = 10, weight = 5, port = 5060, target = "sip1.example.com" } },
        { data = { priority = 20, weight = 5, port = 5060, target = "sip2.example.com" } },
      ]
    }
  }
}

run "initial_order" {
  command = plan
}

run "reordered" {
  command = plan

  variables {
    records = {
      "app" = {
        A   = [{ content = "192.0.2.3" }, { content = "192.0.2.1" }, { content = "192.0.2.2" }]
        TXT = [{ content = "token" }, { content = "v=spf1 -all" }]
        MX  = [{ content = "mx2.example.com", priority = 20 }, { content = "mx1.example.com", priority = 10 }]
      }
      "_sip._tcp" = {
        SRV = [
          { data = { priority = 20, weight = 5, port = 5060, target = "sip2.example.com" } },
          { data = { priority = 10, weight = 5, port = 5060, target = "sip1.example.com" } },
        ]
      }
    }
  }

  assert {
    condition     = output.flat_records == run.initial_order.flat_records
    error_message = "Reordering records must not change any key or value"
  }
}

run "one_value_changed" {
  command = plan

  variables {
    records = {
      "app" = {
        A   = [{ content = "192.0.2.3" }, { content = "192.0.2.1" }, { content = "192.0.2.4" }]
        TXT = [{ content = "token" }, { content = "v=spf1 -all" }]
        MX  = [{ content = "mx2.example.com", priority = 20 }, { content = "mx1.example.com", priority = 10 }]
      }
      "_sip._tcp" = {
        SRV = [
          { data = { priority = 20, weight = 5, port = 5060, target = "sip2.example.com" } },
          { data = { priority = 10, weight = 5, port = 5060, target = "sip1.example.com" } },
        ]
      }
    }
  }

  assert {
    condition     = setsubtract(keys(run.initial_order.flat_records), keys(output.flat_records)) == toset(["app A 192.0.2.2"])
    error_message = "Only the record whose value changed loses its key"
  }

  assert {
    condition     = setsubtract(keys(output.flat_records), keys(run.initial_order.flat_records)) == toset(["app A 192.0.2.4"])
    error_message = "Only the new value gets a new key"
  }
}

run "key_kept_value_changed" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = "verification", content = "token-1" }], A = [{ key = "web", content = "192.0.2.1" }] } }
  }

  assert {
    condition     = keys(output.flat_records) == ["app A web", "app TXT verification"]
    error_message = "A key replaces the value in the record key"
  }
}

run "key_kept_value_changed_again" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = "verification", content = "token-2" }], A = [{ key = "web", content = "192.0.2.2" }] } }
  }

  assert {
    condition     = keys(output.flat_records) == keys(run.key_kept_value_changed.flat_records)
    error_message = "With the same key, a new value keeps the address, so the record is updated in place"
  }

  assert {
    condition     = output.flat_records["app TXT verification"].content == "token-2" && output.flat_records["app A web"].content == "192.0.2.2"
    error_message = "The new values must be planned"
  }
}

run "key_renamed" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = "site-verification", content = "token-2" }], A = [{ key = "web", content = "192.0.2.2" }] } }
  }

  assert {
    condition     = keys(output.flat_records) == ["app A web", "app TXT site-verification"]
    error_message = "A renamed key is a new address, so the record is replaced"
  }
}

# Keys are compared as written: keys that differ only in case are different records
run "keys_are_case_sensitive" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = "foo", content = "a" }, { key = "FOO", content = "b" }] } }
  }

  assert {
    condition     = keys(output.flat_records) == ["app TXT FOO", "app TXT foo"]
    error_message = "Keys differing only in case give two records"
  }
}

run "same_key_twice" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = "foo", content = "a" }, { key = "foo", content = "b" }] } }
  }

  expect_failures = [output.flat_records]
}

run "key_with_surrounding_whitespace" {
  command = plan

  variables {
    records = { "app" = { TXT = [{ key = " foo", content = "a" }, { key = "foo ", content = "b" }] } }
  }

  expect_failures = [var.records]
}

# The same records in YAML (yamldecode, as in examples/yaml) and in HCL give the same
# flat records, including YAML 1.1 values that need care: quoted "off"/"yes"/"N", an
# unquoted N for a LOC direction, numbers in data
run "yaml" {
  command = plan

  variables {
    records = yamldecode(file("tests/fixtures/equivalence.yaml"))["records"]
  }
}

run "hcl_equals_yaml" {
  command = plan

  variables {
    records = {
      "@" = {
        TXT = [{ content = "v=spf1 \"a\" -all" }, { content = "off", key = "flag" }]
        CAA = [{ content = "letsencrypt.org", tag = "issue" }, { content = "mailto:security@example.com", tag = "iodef", flags = 128 }]
        MX  = [{ content = "mail.example.com.", priority = 10 }]
      }
      "app" = {
        A                     = [{ content = "192.0.2.10", ttl = 300, proxied = false }]
        "_acme-challenge.TXT" = [{ content = "yes" }]
        ALIASES               = [{ content = "www", proxied = true }]
      }
      "_sip._tcp" = {
        SRV = [{ data = { priority = "10", weight = "5", port = "5060", target = "sip.example.com" } }]
      }
      "office" = {
        LOC = [{ key = "hq", data = { lat_degrees = "59", lat_minutes = "26", lat_seconds = "14", lat_direction = "N", long_degrees = "24", long_minutes = "44", long_seconds = "43", long_direction = "E" } }]
      }
      "sip" = {
        NAPTR = [{ data = { order = "100", preference = "10", flags = "S", service = "SIP+D2U", regex = "", replacement = "_sip._udp.example.com." } }]
      }
    }
  }

  assert {
    condition     = output.flat_records == run.yaml.flat_records
    error_message = "The same records in YAML and in HCL must give the same flat records"
  }
}
