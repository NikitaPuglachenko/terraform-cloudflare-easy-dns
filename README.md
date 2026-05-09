# Cloudflare DNS Records Factory (Terraform Module)

A flexible Terraform module to manage Cloudflare DNS records using a structured object-based approach. Instead of defining multiple `cloudflare_record` resources, you can define your entire DNS zone (or sub-sections of it) in a single hierarchical map.

## Features

- 📂 **Structured Schema**: Group records by their base name (subdomain).
- 🔗 **Smart Aliases**: Automatically create `CNAME` records pointing to your main records using the `ALIASES` key.
- 🛠 **Hybrid Names**: Support for nested subdomains like `_acme-challenge.app`.
- ☁️ **Cloudflare Optimized**: Automatic `TTL = 1` for proxied records.
- 🛡 **CAA Support**: Proper handling of CAA tags, flags, and values.

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.5.0 |
| cloudflare | >= 4.30.0 |

## Usage

```hcl
module "dns" {
  source  = "../../modules/dns"
  zone_id = var.zone_id

  records = {
    # This will manage records for app.example.com
    "app" = {
      A = [
        { content = "30.40.50.60", proxied = true },
      ]
      # Aliases create CNAMEs pointing to 'app.example.com'
      # Result: support.example.com -> CNAME -> app.example.com
      ALIASES = [
        { content = "support", ttl = 1800 }, 
      ]
      TXT = [
        { content = "v=spf1 include:_spf.google.com ~all" },
      ]
      MX = [
        { content = "mail.example.com", priority = 1 },
      ]
      CAA = [
        { content = "letsencrypt.org", tag = "issue", flags = 0 },
        { content = "letsencrypt.org", tag = "issuewild", flags = 0 },
      ]
      # Supports specific sub-keys. 
      # Result: TXT record for _acme-challenge.app.example.com
      "_acme-challenge.TXT" = [
        { content = "verification-token" },
      ]
    }
  }
}
```

## How It Works

The module performs a complex "flattening" of the input map to generate unique keys for each record.

### The `ALIASES` Logic
When you define `ALIASES` inside a block (e.g., inside `"app"`), the module automatically creates a `CNAME` record where:
- **Name**: The value provided in `content` (e.g., `support` for support.example.com).
- **Target**: The parent key plus the root domain (e.g., `app.example.com`).

### Nested Subdomains
By using a dot-notation in the record type key (like `"_acme-challenge.TXT"`), the module splits the key to prepend the prefix to the base name, allowing for easy management of ACME challenges or DKIM records.

## Inputs


| Name | Description | Type | Required |
|------|-------------|------|:--------:|
| `zone_id` | The Cloudflare Zone ID where records will be created | `string` | Yes |
| `records` | A complex map of DNS records grouped by subdomain | `map(map(list(object)))` | Yes |

### Record Object Schema

| Field | Description | Default |
|-------|-------------|---------|
| `content` | IP address, hostname, or text value | `null` |
| `ttl` | Time to Live (automatically set to `1` if proxied) | `3600` |
| `proxied` | Whether the record gets Cloudflare's proxy | `false` |
| `priority` | Priority for MX records | `null` |
| `tag` | Tag for CAA records (`issue`, `issuewild`, `iodef`) | `null` |
| `flags` | Flags for CAA records (usually `0`) | `0` |

## Outputs


| Name | Description |
|------|-------------|
| `flat_records` | The processed map of records used for `for_each` |

## License
MIT
