# Record parsing, aliases and validation are covered by the tests of modules/dns/records.
# These tests cover only how records are mapped to the provider resource.

mock_provider "cloudflare" {
  override_data {
    target = data.cloudflare_zone.this[0]
    values = { name = "looked-up.com" }
  }
}

variables {
  zone_id   = "z"
  zone_name = "example.com"
  records = {
    "app" = {
      A       = [{ content = "30.40.50.60", proxied = true }]
      TXT     = [{ content = "v=spf1 ~all", key = "spf" }]
      MX      = [{ content = "mx.example.com", priority = 5 }]
      CAA     = [{ content = "letsencrypt.org", tag = "issue" }]
      ALIASES = [{ content = "support" }]
      DNSKEY  = [{ data = { flags = 257, protocol = 3, algorithm = 13, public_key = "abc" } }]
      NAPTR   = [{ data = { order = 100, preference = 10, flags = "U", service = "E2U+sip", regex = "!^.*0sip:info@example.com!", replacement = "." } }]
    }
    "_sip._tcp" = {
      SRV = [{ key = "sip", data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } }]
    }
  }
}

run "plan" {
  command = plan

  assert {
    condition     = cloudflare_record.record["app A 30.40.50.60"].ttl == 1 && cloudflare_record.record["app A 30.40.50.60"].proxied == true
    error_message = "Proxied records must have automatic TTL"
  }

  assert {
    condition     = cloudflare_record.record["app TXT spf"].ttl == 3600 && cloudflare_record.record["app TXT spf"].priority == null
    error_message = "Default TTL, no priority for TXT"
  }

  assert {
    condition     = cloudflare_record.record["app MX mx.example.com"].priority == 5
    error_message = "MX priority"
  }

  assert {
    condition     = cloudflare_record.record["app CAA issue letsencrypt.org"].data[0].tag == "issue" && cloudflare_record.record["app CAA issue letsencrypt.org"].data[0].flags == "0"
    error_message = "CAA data"
  }

  assert {
    condition     = cloudflare_record.record["_sip._tcp SRV sip"].priority == 10 && cloudflare_record.record["_sip._tcp SRV sip"].data[0].port == 5060 && cloudflare_record.record["_sip._tcp SRV sip"].data[0].target == "sip.example.com"
    error_message = "SRV data and priority"
  }

  assert {
    condition     = cloudflare_record.record["app DNSKEY ${substr(sha1(jsonencode({ flags = "257", protocol = "3", algorithm = "13", public_key = "abc" })), 0, 12)}"].data[0].flags == "257"
    error_message = "DNSKEY flags"
  }

  assert {
    condition     = one([for k, r in cloudflare_record.record : r.data[0].flags if r.type == "NAPTR"]) == "U"
    error_message = "NAPTR flags"
  }
}

run "zone_lookup" {
  command = plan

  variables {
    zone_name = null
  }

  assert {
    condition     = cloudflare_record.record["support CNAME"].content == "app.looked-up.com"
    error_message = "Zone lookup"
  }
}
