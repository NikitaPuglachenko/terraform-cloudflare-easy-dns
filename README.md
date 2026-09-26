# Cloudflare DNS Records Factory (Terraform Module)

A flexible Terraform module to manage Cloudflare DNS records using a structured object-based approach. Instead of defining multiple record resources, you can define your entire DNS zone (or sub-sections of it) in a single hierarchical map.

## Features

- 📂 **Structured Schema**: Group records by their base name (subdomain or `@` for the zone apex).
- 🔗 **Smart Aliases**: Automatically create `CNAME` records pointing to your main records using the `ALIASES` key.
- 🛠 **Hybrid Names**: Support for nested subdomains like `_acme-challenge.app`.
- ☁️ **Cloudflare Optimized**: Automatic `TTL = 1` for proxied records.
- 🛡 **CAA Support**: Proper handling of CAA tags, flags, and values.
- 🔀 **Provider v4 and v5**: The same input schema for both major versions of the Cloudflare provider.

## Structure

```
modules/dns/
├── records/   # Provider-agnostic core: flattens the input map (used internally)
├── v4/        # Wrapper for Cloudflare provider v4 (cloudflare_record)
└── v5/        # Wrapper for Cloudflare provider v5 (cloudflare_dns_record)
```

Both wrappers share the same inputs, outputs and record keys, so switching between them only requires changing the `source`.

## Requirements

| Module | Terraform | Cloudflare provider |
|--------|-----------|---------------------|
| `modules/dns/v4` | `>= 1.8.0` | `~> 4.30` |
| `modules/dns/v5` | `>= 1.8.0` | `~> 5.26` |

If `zone_name` is not set, the module looks up the zone by `zone_id`, so the API token needs the `Zone:Read` permission.

## Usage

```hcl
module "dns" {
  # Use //modules/dns/v4 for Cloudflare provider v4
  source = "git::https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns.git//modules/dns/v5?ref=<tag>"

  zone_id   = var.zone_id
  zone_name = "example.com" # optional, looked up from zone_id when omitted

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
        { content = "letsencrypt.org", tag = "issue" },
        { content = "letsencrypt.org", tag = "issuewild" },
      ]
      # Supports specific sub-keys.
      # Result: TXT record for _acme-challenge.app.example.com
      "_acme-challenge.TXT" = [
        { content = "verification-token" },
      ]
      # Inline aliases point to a prefixed name.
      # Result: static.example.com -> CNAME -> cdn.app.example.com
      "cdn.ALIASES" = [
        { content = "static" },
      ]
    }

    # Zone apex (example.com)
    "@" = {
      A = [
        { content = "30.40.50.61", proxied = true },
      ]
      # Result: TXT record for _dmarc.example.com
      "_dmarc.TXT" = [
        { content = "v=DMARC1; p=none" },
      ]
      # Result: www.example.com -> CNAME -> example.com
      ALIASES = [
        { content = "www", proxied = true },
      ]
    }
  }
}
```

## How It Works

The module flattens the input map into a single map with a unique key for each record, which is then used in `for_each`.

### Record Types and Nested Names
Each key inside a base name block is a record type (`A`, `AAAA`, `CNAME`, `TXT`, `MX`, `CAA`, ...). A key with a dot-notation (like `"_acme-challenge.TXT"`) is split: the last part is the record type, everything before it is prepended to the base name. Inside the `@` block the prefix becomes the record name itself (`"_dmarc.TXT"` becomes `_dmarc.example.com`).

### The `ALIASES` Logic
When you define `ALIASES` inside a block (e.g., inside `"app"`), the module creates a `CNAME` record for each entry where:
- **Name**: The value provided in `content` (e.g., `support` for support.example.com).
- **Target**: The base name plus the zone domain (e.g., `app.example.com`, or `example.com` for `@`).

### Inline Aliases
A key like `"cdn.ALIASES"` works the same way, but the target is the prefixed name: `cdn.app.example.com` (or `cdn.example.com` for `@`).

### Record Keys
Keys in the state look like `A_app_0`, `_acme-challenge.TXT_app_0`, `ALIASES_app_support` or `CAA_app_issue_letsencrypt.org_0`. Regular records are keyed by their position in the list, so removing or reordering items in a list recreates the records that follow.

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| `zone_id` | The Cloudflare Zone ID where records will be created | `string` | - | Yes |
| `zone_name` | Zone domain name (e.g. `example.com`), used as the target for aliases. Looked up from `zone_id` when `null` | `string` | `null` | No |
| `records` | A map of DNS records grouped by base name, then by record type | `map(map(list(object)))` | - | Yes |

### Record Object Schema

| Field | Description | Default |
|-------|-------------|---------|
| `content` | IP address, hostname, or text value | `null` |
| `ttl` | Time to Live (automatically set to `1` if proxied) | `3600` |
| `proxied` | Whether the record gets Cloudflare's proxy | `false` |
| `priority` | Priority for MX records | `null` |
| `tag` | Tag for CAA records (`issue`, `issuewild`, `iodef`) | `null` |
| `flags` | Flags for CAA records | `0` |

## Outputs

| Name | Description |
|------|-------------|
| `record_names` | Names of all managed records |

## Migrating from v4 to v5

The v5 wrapper contains a `moved` block from `cloudflare_record` to `cloudflare_dns_record`, so the state is migrated without recreating records:

1. Upgrade the Cloudflare provider to `~> 5.26`.
2. Change the module `source` from `//modules/dns/v4` to `//modules/dns/v5`, keeping the module name the same.
3. Run `terraform init -upgrade` and `terraform plan`. The plan should only show moved resources, without destroying or creating records. Review it carefully before applying.

## Testing

Each wrapper has plan-only tests with a mocked provider, no Cloudflare credentials needed:

```sh
cd modules/dns/v5
terraform init
terraform test
```

CI runs `terraform fmt`, `validate` and `test` for both wrappers (on Terraform 1.8 and the latest version), [TFLint](https://github.com/terraform-linters/tflint) and [Gitleaks](https://github.com/gitleaks/gitleaks) on every pull request.

## License
MIT
