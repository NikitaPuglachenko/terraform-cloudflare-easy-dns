# Matching of records that already exist in the zone to the configured records

variables {
  root_domain = "example.com"
  records = {
    "@" = {
      TXT     = [{ content = "v=spf1 include:_spf.example.net ~all" }]
      MX      = [{ content = "mail.example.com", priority = 10 }]
      CAA     = [{ content = "letsencrypt.org", tag = "issue" }]
      ALIASES = [{ content = "www" }]
    }
    "app" = {
      A = [{ content = "30.40.50.60" }, { content = "30.40.50.61" }]
    }
    "_sip._tcp" = {
      SRV = [{ key = "sip", data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } }]
    }
    "dup" = {
      A = [{ content = "1.1.1.1" }]
    }
  }
  existing_records = [
    { id = "id-a", name = "App.Example.com", type = "A", content = "30.40.50.60" },
    { id = "id-txt", name = "example.com", type = "TXT", content = "\"v=spf1 include:_spf.example.net\" \" ~all\"" },
    { id = "id-cname", name = "www.example.com", type = "CNAME", content = "Example.com." },
    { id = "id-mx", name = "example.com", type = "MX", content = "mail.example.com" },
    { id = "id-caa", name = "example.com", type = "CAA", data = { flags = "0", tag = "issue", value = "letsencrypt.org" } },
    { id = "id-srv", name = "_sip._tcp.example.com", type = "SRV", data = { priority = "10", weight = "5", port = "5060", target = "sip.example.com." } },
    { id = "id-dup-1", name = "dup.example.com", type = "A", content = "1.1.1.1" },
    { id = "id-dup-2", name = "dup.example.com", type = "A", content = "1.1.1.1" },
    { id = "id-other", name = "other.example.com", type = "A", content = "9.9.9.9" },
    { id = "id-wrong-type", name = "app.example.com", type = "AAAA", content = "30.40.50.61" },
  ]
}

run "import_record_ids" {
  command = plan

  assert {
    condition = output.import_record_ids == {
      "app A 30.40.50.60"                                                    = "id-a"
      "@ TXT ${substr(sha1("v=spf1 include:_spf.example.net ~all"), 0, 12)}" = "id-txt"
      "www CNAME"                                                            = "id-cname"
      "@ MX mail.example.com"                                                = "id-mx"
      "@ CAA issue letsencrypt.org"                                          = "id-caa"
      "_sip._tcp SRV sip"                                                    = "id-srv"
    }
    error_message = "New records, ambiguous matches and unrelated records must be left out"
  }
}

run "no_existing_records" {
  command = plan

  variables {
    existing_records = []
  }

  assert {
    condition     = output.import_record_ids == {}
    error_message = "No import IDs without existing records"
  }
}
