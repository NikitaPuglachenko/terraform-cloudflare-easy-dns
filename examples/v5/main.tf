module "dns" {
  # Outside of this repository use:
  # git::https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns.git//modules/dns/v5?ref=v2.1.0
  source = "../../modules/dns/v5"

  zone_id   = var.zone_id
  zone_name = var.zone_name

  records = {
    # Zone apex (example.com)
    "@" = {
      A = [
        { content = "30.40.50.61", proxied = true },
      ]
      MX = [
        { content = "mail.example.com", priority = 10 },
      ]
      TXT = [
        { content = "v=spf1 include:_spf.google.com ~all" },
      ]
      CAA = [
        { content = "letsencrypt.org", tag = "issue" },
        { content = "letsencrypt.org", tag = "issuewild" },
      ]
      # Result: TXT record for _dmarc.example.com
      "_dmarc.TXT" = [
        { content = "v=DMARC1; p=none" },
      ]
      # An explicit key keeps the record in place when the value changes (e.g. DKIM rotation)
      "google._domainkey.TXT" = [
        { key = "dkim", content = "v=DKIM1; k=rsa; p=MIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEA" },
      ]
      # Result: www.example.com -> CNAME -> example.com
      ALIASES = [
        { content = "www", proxied = true },
      ]
    }

    # Records for app.example.com
    "app" = {
      A = [
        { content = "30.40.50.60", proxied = true },
      ]
      # Result: support.example.com -> CNAME -> app.example.com
      ALIASES = [
        { content = "support", ttl = 1800 },
      ]
      # Result: TXT record for _acme-challenge.app.example.com
      "_acme-challenge.TXT" = [
        { content = "verification-token" },
      ]
      # Result: static.example.com -> CNAME -> cdn.app.example.com
      "cdn.ALIASES" = [
        { content = "static" },
      ]
    }

    "mail" = {
      A = [
        { content = "30.40.50.62" },
      ]
    }

    # Structured records use data instead of content
    "_sip._tcp" = {
      SRV = [
        { data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } },
      ]
    }
  }
}
