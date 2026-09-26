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
    "@" = {
      ALIASES        = [{ content = "root-alias" }]
      "_dmarc.TXT"   = [{ content = "v=DMARC1" }]
      "mail.ALIASES" = [{ content = "m2" }]
    }
    "app" = {
      A                     = [{ content = "30.40.50.60", proxied = true }]
      TXT                   = [{ content = "v=spf1 ~all" }]
      ALIASES               = [{ content = "support", ttl = 1800 }]
      "_acme-challenge.TXT" = [{ content = "tok" }]
      "www.ALIASES"         = [{ content = "w2" }]
      CAA                   = [{ content = "letsencrypt.org", tag = "issue" }]
      MX                    = [{ content = "mx.example.com", priority = 5 }]
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
    condition     = cloudflare_record.record["app TXT ${substr(sha1("v=spf1 ~all"), 0, 12)}"].ttl == 3600 && cloudflare_record.record["app TXT ${substr(sha1("v=spf1 ~all"), 0, 12)}"].proxied == false
    error_message = "Defaults"
  }

  assert {
    condition     = cloudflare_record.record["support CNAME"].content == "app.example.com" && cloudflare_record.record["support CNAME"].ttl == 1800
    error_message = "Alias"
  }

  assert {
    condition     = cloudflare_record.record["w2 CNAME"].content == "www.app.example.com" && cloudflare_record.record["m2 CNAME"].content == "mail.example.com"
    error_message = "Inline alias"
  }

  assert {
    condition     = cloudflare_record.record["root-alias CNAME"].content == "example.com"
    error_message = "Apex alias"
  }

  assert {
    condition     = cloudflare_record.record["app CAA issue letsencrypt.org"].data[0].flags == "0"
    error_message = "CAA"
  }

  assert {
    condition     = cloudflare_record.record["app MX mx.example.com"].priority == 5 && cloudflare_record.record["app TXT ${substr(sha1("v=spf1 ~all"), 0, 12)}"].priority == null
    error_message = "Priority only for MX"
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
