# Cloudflare DNS Records Factory (Terraform Module)

A flexible Terraform module to manage Cloudflare DNS records using a structured object-based approach. Instead of defining multiple record resources, you can define your entire DNS zone (or sub-sections of it) in a single hierarchical map.

## Features

- 📂 **Structured Schema**: Group records by their base name (subdomain or `@` for the zone apex).
- 🔗 **Smart Aliases**: Automatically create `CNAME` records pointing to your main records using the `ALIASES` key.
- 🛠 **Hybrid Names**: Support for nested subdomains like `_acme-challenge.app`.
- ☁️ **Cloudflare Optimized**: Automatic `TTL = 1` for proxied records.
- 🛡 **CAA Support**: Proper handling of CAA tags, flags, and values.
- 📥 **Import of Existing Records**: Adopt records that already exist in the zone with a single `import` block (provider v5).
- 🧩 **All Record Types**: `SRV`, `URI`, `HTTPS`, `SVCB`, `TLSA`, `SSHFP`, `DS`, `LOC` and other structured records through a single `data` map.
- 🔀 **Provider v4 and v5**: The same input schema for both major versions of the Cloudflare provider.
- ✅ **Input Validation**: Mistakes in record types, TTL, MX or CAA fields fail at `plan`, before reaching the Cloudflare API.

## Structure

```
modules/dns/
├── records/   # Provider-agnostic core: validates and flattens the input map (used internally)
├── v4/        # Wrapper for Cloudflare provider v4 (cloudflare_record)
└── v5/        # Wrapper for Cloudflare provider v5 (cloudflare_dns_record)
examples/
├── v4/        # Complete example for provider v4
└── v5/        # Complete example for provider v5
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
  source = "git::https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns.git//modules/dns/v5?ref=v2.3.0"

  zone_id   = var.zone_id
  zone_name = "example.com" # optional, looked up from zone_id when omitted

  records = {
    # Zone apex (example.com)
    "@" = {
      A = [
        { content = "30.40.50.61", proxied = true },
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

    # Structured records use data instead of content
    # Result: SRV record for _sip._tcp.example.com
    "_sip._tcp" = {
      SRV = [
        { data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } },
      ]
    }
  }
}
```

Complete runnable configurations are available in [`examples/v4`](examples/v4) and [`examples/v5`](examples/v5).

## How It Works

The module flattens the input map into a single map with a unique key for each record, which is then used in `for_each`.

### Record Types and Nested Names
Each key inside a base name block is a record type (`A`, `AAAA`, `CNAME`, `TXT`, `MX`, `CAA`, `SRV`, ...; see [Record Types](#record-types)). A key with a dot-notation (like `"_acme-challenge.TXT"`) is split: the last part is the record type, everything before it is prepended to the base name. Inside the `@` block the prefix becomes the record name itself (`"_dmarc.TXT"` becomes `_dmarc.example.com`).

### Record Types

Most records are defined by `content`. Structured records are defined by a `data` map instead, with the same fields as in the Cloudflare API:

| Type | Defined by | `data` fields (optional in italics) |
|------|-----------|--------------------------------------|
| `A`, `AAAA`, `CNAME`, `NS`, `PTR`, `TXT` | `content` | - |
| `MX` | `content`, `priority` | - |
| `OPENPGPKEY` | `content` | - (provider v5 only) |
| `CAA` | `content`, `tag`, `flags` | - |
| `SRV` | `data` | `priority`, `weight`, `port`, `target` |
| `URI` | `data`, `priority` | `weight`, `target` |
| `HTTPS`, `SVCB` | `data` | `priority`, `target`, *`value`* |
| `TLSA`, `SMIMEA` | `data` | `usage`, `selector`, `matching_type`, `certificate` |
| `SSHFP` | `data` | `algorithm`, `type`, `fingerprint` |
| `DS` | `data` | `key_tag`, `algorithm`, `digest_type`, `digest` |
| `DNSKEY` | `data` | `flags`, `protocol`, `algorithm`, `public_key` |
| `CERT` | `data` | `type`, `key_tag`, `algorithm`, `certificate` |
| `NAPTR` | `data` | `order`, `preference`, `replacement`, *`flags`*, *`service`*, *`regex`* |
| `LOC` | `data` | `lat_degrees`, `lat_minutes`, `lat_seconds`, `lat_direction`, `long_degrees`, `long_minutes`, `long_seconds`, `long_direction`, *`altitude`*, *`size`*, *`precision_horz`*, *`precision_vert`* |

The service and protocol of `SRV`, `URI` and `TLSA` records are part of the name:

```hcl
"_sip._tcp" = {
  SRV = [{ data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" } }]
}
"mail" = {
  "_25._tcp.TLSA" = [{ key = "mx", data = { usage = 3, selector = 1, matching_type = 1, certificate = "..." } }]
}
```

### The `ALIASES` Logic
When you define `ALIASES` inside a block (e.g., inside `"app"`), the module creates a `CNAME` record for each entry where:
- **Name**: The value provided in `content` (e.g., `support` for support.example.com).
- **Target**: The base name plus the zone domain (e.g., `app.example.com`, or `example.com` for `@`).

### Inline Aliases
A key like `"cdn.ALIASES"` works the same way, but the target is the prefixed name: `cdn.app.example.com` (or `cdn.example.com` for `@`).

### Record Keys
Each record is keyed in the state by its content, in the zone file format `<name> <TYPE> <value>`, so adding, removing or reordering items in a list affects only those items:

| Record | Key |
|--------|-----|
| `A`, `AAAA`, `MX`, `NS`, `PTR` | `app A 30.40.50.60`, `@ MX mail.example.com` |
| `TXT` | `_dmarc TXT 21541c4e7044` (first 12 characters of the SHA-1 of the value) |
| Records with `data` (`SRV`, `TLSA`, ...) | `_sip._tcp SRV 9c61601f99e8` (first 12 characters of the SHA-1 of the data) |
| `CNAME` and `ALIASES` | `www CNAME` (only one CNAME is allowed per name) |
| `CAA` | `app CAA issue letsencrypt.org` |
| Any record with `key` | `google._domainkey TXT dkim` |

```
module.dns.cloudflare_record.record["app A 30.40.50.60"]
```

Since the value is a part of the key, changing it replaces the record. For values that change over time (e.g. DKIM rotation or a server IP), set an explicit `key`, so the record is updated in place:

```hcl
"google._domainkey.TXT" = [
  { key = "dkim", content = "v=DKIM1; k=rsa; p=MIIBIjANBg..." },
]
```

Two records that produce the same key (e.g. the same value listed twice, or a `CNAME` and an alias with the same name) fail at `plan` with the list of duplicates and where each of them is defined.

## Validation

The `records` input is validated before any API call:

- Supported record types: see [Record Types](#record-types), plus `ALIASES` (with an optional prefix, e.g. `"_acme-challenge.TXT"`)
- Records defined by `content` must have a non-empty `content`
- Structured records must have `data` with only the fields of their type and all required ones; other records must not set `data`
- `ttl` must be `1` (automatic) or between `30` and `86400`
- Only `A`, `AAAA`, `CNAME` and `ALIASES` records can be `proxied`
- `MX` and `URI` records require `priority`
- `CAA` records require `tag`: `issue`, `issuewild` or `iodef`
- `key` must not contain whitespace
- Record keys must be unique. The error shows where each duplicate is defined, e.g. `"_acme-challenge.app TXT 79bead8e6d65" from records["_acme-challenge.app"]["TXT"][0] and records["app"]["_acme-challenge.TXT"][0]`
- A `CNAME` (including `ALIASES`) cannot share its name with other records, except at the zone apex `@` where Cloudflare uses CNAME flattening

## Inputs

Both wrappers take `zone_id`, `zone_name` (optional, looked up from `zone_id` when omitted) and `records`; the v5 wrapper also takes `import_existing`. The full reference of inputs, outputs, requirements and resources is generated from the code with [terraform-docs](https://terraform-docs.io): [`modules/dns/v4`](modules/dns/v4/README.md), [`modules/dns/v5`](modules/dns/v5/README.md).

### Record Object Schema

| Field | Description | Default |
|-------|-------------|---------|
| `content` | IP address, hostname, or text value | `null` |
| `ttl` | Time to Live (automatically set to `1` if proxied) | `3600` |
| `proxied` | Whether the record gets Cloudflare's proxy | `false` |
| `priority` | Priority for MX and URI records | `null` |
| `tag` | Tag for CAA records (`issue`, `issuewild`, `iodef`) | `null` |
| `flags` | Flags for CAA records | `0` |
| `data` | Fields of structured records, see [Record Types](#record-types) | `null` |
| `key` | Stable key used instead of the value in the record key, see [Record Keys](#record-keys) | `null` |

## Outputs

- `record_names`: names of all managed records
- `records`: managed records keyed by their [record key](#record-keys), with `id`, `name`, `type` and `content`
- `state_migration`: map of the record keys used by 1.x to the current ones, see [Upgrading from v1](#upgrading-from-v1)
- `import_ids` (v5): import IDs of records that already exist in the zone, see [Importing Existing Records](#importing-existing-records)

## Importing Existing Records

When the zone already has records, the first `apply` would fail with "record already exists" for each of them. With provider v5, the module can find the existing records and adopt them into the state instead:

1. Set `import_existing = true`. The module then reads all records of the zone (the API token needs the `DNS Read` permission) and matches them to the configured records by name, type and value.
2. Add an `import` block next to the module call:

   ```hcl
   import {
     for_each = module.dns.import_ids
     to       = module.dns.cloudflare_dns_record.record[each.key]
     id       = each.value
   }
   ```

3. Run `terraform plan`. Existing records are shown as imported, and only records missing in the zone are created. Check that no record you expect to be imported is shown as created.
4. Run `terraform apply`, then remove the `import` block and `import_existing`, so the zone is not read on every plan.

Matching ignores case, a trailing dot and the quoting of TXT values. A record is imported only when exactly one existing record matches it: when the zone has several identical records, the record is not imported and `plan` shows it as created, so the duplicates can be cleaned up first.

## Upgrading from v1

Version 2 changes the record keys in the state (see [Record Keys](#record-keys)). Without migration, Terraform would destroy and recreate every record. The `state_migration` output maps the old keys to the new ones, so the migration can be done with `moved` blocks:

1. Change the module `ref` to `v2.x` and run `terraform init -upgrade`.
2. Generate `moved` blocks (requires `jq`). Set `MODULE` to the module address and `RESOURCE` to `cloudflare_record` for `v4` or `cloudflare_dns_record` for `v5`:

   ```sh
   MODULE=module.dns
   RESOURCE=cloudflare_record
   echo "jsonencode(${MODULE}.state_migration)" | terraform console \
     | jq -r --arg addr "$MODULE.$RESOURCE.record" \
       'fromjson | to_entries[] | "moved {\n  from = \($addr)[\(.key | tojson)]\n  to   = \($addr)[\(.value | tojson)]\n}\n"' \
     > dns_migration.tf
   ```

3. Run `terraform plan`. It should only show records that have moved, with no records to add or destroy.
4. Run `terraform apply`, then delete `dns_migration.tf`. The next `terraform plan` should show no changes.

Upgrade the keys and switch from `v4` to `v5` in separate steps.

## Migrating from v4 to v5

The v5 wrapper contains a `moved` block from `cloudflare_record` to `cloudflare_dns_record`, so the state is migrated without recreating records:

1. Upgrade the Cloudflare provider to `~> 5.26`.
2. Change the module `source` from `//modules/dns/v4` to `//modules/dns/v5`, keeping the module name the same.
3. Run `terraform init -upgrade` and `terraform plan`. The plan should only show moved resources, without destroying or creating records. Review it carefully before applying.

## Testing

The core module, both wrappers and the examples have plan-only tests (the wrappers and examples use a mocked provider), no Cloudflare credentials needed:

```sh
cd modules/dns/v5
terraform init
terraform test
```

The module READMEs are generated with [terraform-docs](https://terraform-docs.io). After changing variables, outputs or requirements, regenerate them:

```sh
./scripts/generate-docs.sh
```

CI runs `terraform fmt`, `validate` and `test` for the core module, both wrappers and the examples (on Terraform 1.8 and the latest version), checks that the module READMEs are up to date, [TFLint](https://github.com/terraform-linters/tflint) and [Gitleaks](https://github.com/gitleaks/gitleaks) on every pull request.

## License
MIT
