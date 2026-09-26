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
      A                     = [{ content = "30.40.50.60", proxied = true }]
      TXT                   = [{ content = "v=spf1 ~all" }]
      ALIASES               = [{ content = "support", ttl = 1800 }]
      "_acme-challenge.TXT" = [{ content = "tok" }]
      "www.ALIASES"         = [{ content = "w2" }]
      CAA                   = [{ content = "letsencrypt.org", tag = "issue" }]
      MX                    = [{ content = "mx.example.com", priority = 5 }]
    }
    "@" = {
      ALIASES        = [{ content = "root-alias" }]
      "_dmarc.TXT"   = [{ content = "v=DMARC1" }]
      "mail.ALIASES" = [{ content = "m2" }]
    }
  }
}

run "plan" {
  command = plan

  assert {
    condition     = cloudflare_dns_record.record["A_app_0"].ttl == 1 && cloudflare_dns_record.record["TXT_app_0"].ttl == 3600 && cloudflare_dns_record.record["TXT_app_0"].proxied == false
    error_message = "ttl/proxied"
  }

  assert {
    condition     = cloudflare_dns_record.record["ALIASES_app_support"].content == "app.example.com" && cloudflare_dns_record.record["ALIASES_app_support"].ttl == 1800
    error_message = "legacy alias"
  }

  assert {
    condition     = cloudflare_dns_record.record["_acme-challenge.TXT_app_0"].name == "_acme-challenge.app" && cloudflare_dns_record.record["_dmarc.TXT_@_0"].name == "_dmarc"
    error_message = "nested names"
  }

  assert {
    condition     = cloudflare_dns_record.record["ALIASES_INLINE_app_www.ALIASES_0_w2"].content == "www.app.example.com" && cloudflare_dns_record.record["ALIASES_INLINE_@_mail.ALIASES_0_m2"].content == "mail.example.com"
    error_message = "inline alias"
  }

  assert {
    condition     = cloudflare_dns_record.record["ALIASES_@_root-alias"].content == "example.com"
    error_message = "apex alias"
  }

  assert {
    condition     = cloudflare_dns_record.record["CAA_app_issue_letsencrypt.org_0"].data.tag == "issue"
    error_message = "caa"
  }

  assert {
    condition     = cloudflare_dns_record.record["MX_app_0"].priority == 5 && cloudflare_dns_record.record["TXT_app_0"].priority == null
    error_message = "mx priority"
  }
}

run "zone_lookup" {
  command = plan
  variables {
    zone_name = null
  }

  assert {
    condition     = cloudflare_dns_record.record["ALIASES_app_support"].content == "app.looked-up.com"
    error_message = "zone lookup"
  }
}
