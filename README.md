# Cloudflare DNS Records Factory (Terraform Module)

[![Terraform Registry](https://img.shields.io/badge/terraform-registry-7B42BC?logo=terraform)](https://registry.terraform.io/modules/NikitaPuglachenko/easy-dns/cloudflare/latest) [![Release](https://img.shields.io/github/v/release/NikitaPuglachenko/terraform-cloudflare-easy-dns)](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/releases/latest) [![CI](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/actions/workflows/ci.yml/badge.svg)](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/actions/workflows/ci.yml) [![End-to-end](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/actions/workflows/e2e.yml/badge.svg)](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/actions/workflows/e2e.yml) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/blob/main/LICENSE)

A flexible Terraform module to manage Cloudflare DNS records using a structured object-based approach. Instead of defining multiple record resources, you can define your entire DNS zone (or sub-sections of it) in a single hierarchical map.

## How It Works in 30 Seconds

The zone is described as one map, grouped by name and then by record type:

```
records[<name>][<TYPE>] = [ <record>, ... ]
```

Each record becomes one Cloudflare DNS record, with a stable address in the Terraform state:

```hcl
module "dns" {
  source  = "NikitaPuglachenko/easy-dns/cloudflare"
  version = "~> 2.6"

  zone_id   = var.zone_id
  zone_name = "example.com"

  records = {
    "app" = {
      # app.example.com
      A = [{ content = "192.0.2.10" }]

      # _acme-challenge.app.example.com
      "_acme-challenge.TXT" = [{ key = "acme", content = "token" }]

      # www.example.com -> CNAME -> app.example.com
      ALIASES = [{ content = "www" }]
    }
  }
}
```

Each record is an instance of `module.dns.module.v5.cloudflare_dns_record.record`, with these keys:

| Record | Key in the state |
|:-------|:-----------------|
| `app.example.com A 192.0.2.10` | `app A 192.0.2.10` |
| `_acme-challenge.app.example.com TXT "token"` | `_acme-challenge.app TXT acme` |
| `www.example.com CNAME app.example.com` | `www CNAME` |

- **Names**: `"app"` is the name within the zone (`"@"` for the apex). A prefix before the type (`"_acme-challenge.TXT"`) is added to the name.
- **Addresses**: a record is addressed by its content, so adding or removing records in a list leaves the others alone. With `key`, the value can change without replacing the record, e.g. for tokens or DKIM keys.
- **Aliases**: `ALIASES` create CNAMEs that point to the name of the block.

Everything else (all record types, defaults, import of existing records, validation) builds on this; see the [full example](#full-example) and the sections below.

## Features

- 📂 **Structured Schema**: Group records by their base name (subdomain or `@` for the zone apex).
- 🔗 **Smart Aliases**: Automatically create `CNAME` records pointing to your main records using the `ALIASES` key.
- 🛠 **Hybrid Names**: Support for nested subdomains like `_acme-challenge.app`.
- ☁️ **Cloudflare Optimized**: Automatic `TTL = 1` for proxied records.
- 🛡 **CAA Support**: Proper handling of CAA tags, flags, and values.
- 📥 **Import of Existing Records**: Adopt records that already exist in the zone with a single `import` block (provider v5).
- 🧩 **All Record Types**: `SRV`, `URI`, `HTTPS`, `SVCB`, `TLSA`, `SSHFP`, `DS`, `LOC` and other structured records through a single `data` map.
- 🔀 **Provider v4 and v5**: The same input schema for both major versions of the Cloudflare provider.
- ✅ **Input Validation**: Mistakes in record types, names, IP addresses, TTL, MX or CAA fields fail at `plan`, before reaching the Cloudflare API.
- 🏷 **Defaults, Comments and Tags**: Set the TTL, proxying, comment and tags once for all records, and override them per record.
- ✍️ **Editor Support for YAML**: A JSON Schema for records kept in YAML, for completion and highlighting of mistakes before `plan`.
- 🧪 **Tested End to End**: Every record type, updates, import and the v4 to v5 migration are tested against a real Cloudflare zone.

## Structure

```
*.tf           # Root module (the Registry source): the v5 wrapper
modules/dns/
├── records/   # Provider-agnostic core: validation and flattening (internal)
├── v4/        # Wrapper for Cloudflare provider v4 (cloudflare_record)
└── v5/        # Wrapper for Cloudflare provider v5 (cloudflare_dns_record)
examples/
├── v4/        # Complete example for provider v4
└── v5/        # Complete example for provider v5
```

Both wrappers share the same inputs, outputs and record keys, so switching between them only requires changing the `source`. The root module passes everything to the v5 wrapper, so it has the same inputs and outputs.

## Requirements

| Module | Terraform | Cloudflare provider |
|--------|-----------|---------------------|
| Root module | `>= 1.8.0` | `~> 5.26` |
| `modules/dns/v4` | `>= 1.8.0` | `~> 4.41` |
| `modules/dns/v5` | `>= 1.8.0` | `~> 5.26` |

If `zone_name` is not set, the module looks up the zone by `zone_id`, so the API token needs the `Zone:Read` permission.

The v4 wrapper is kept for existing configurations. Provider v4 no longer gets new features, so new configurations should use v5 (the root module), and the v4 wrapper may be removed in a future major version. See [Migrating from v4 to v5](#migrating-from-v4-to-v5).

## Usage

The module is published on the [Terraform Registry](https://registry.terraform.io/modules/NikitaPuglachenko/easy-dns/cloudflare/latest):

| Cloudflare provider | `source` |
|---------------------|----------|
| v5 | `NikitaPuglachenko/easy-dns/cloudflare` |
| v4 | `NikitaPuglachenko/easy-dns/cloudflare//modules/dns/v4` |

Without the Registry (e.g. from a Git mirror), use a Git source with a tag: `git::https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns.git?ref=v2.6.0` for v5, or with `//modules/dns/v4` before `?ref=` for v4.

### Full Example

A zone with most of the features: the apex, nested names, aliases, CAA and a structured SRV record.

```hcl
module "dns" {
  source  = "NikitaPuglachenko/easy-dns/cloudflare"
  version = "~> 2.6"

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
      # An explicit key keeps the record in place when the value changes
      "google._domainkey.TXT" = [
        { key = "dkim", content = "v=DKIM1; k=rsa; p=MIIBIjANBg..." },
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
      SRV = [{
        data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" }
      }]
    }
  }
}
```

Complete runnable configurations are available in [`examples/v4`](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/tree/main/examples/v4) and [`examples/v5`](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/tree/main/examples/v5).

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
  SRV = [{
    data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" }
  }]
}
"mail" = {
  "_25._tcp.TLSA" = [{
    key  = "mx"
    data = { usage = 3, selector = 1, matching_type = 1, certificate = "..." }
  }]
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

- Record attributes must be known: a misspelled attribute such as `proxid = true` fails with `records["app"]["A"][0]: unknown attribute "proxid"` instead of being ignored, and the same for `settings`

- Supported record types: see [Record Types](#record-types), plus `ALIASES` (with an optional prefix, e.g. `"_acme-challenge.TXT"`)
- Records defined by `content` must have a non-empty `content`
- Structured records must have `data` with only the fields of their type and all required ones; other records must not set `data`
- `ttl` and `default_ttl` must be `1` (automatic) or between `30` and `86400`
- Only `A`, `AAAA`, `CNAME` and `ALIASES` records can be `proxied`
- `MX` and `URI` records require `priority`
- `A` records need an IPv4 address, `AAAA` records an IPv6 address, and `CNAME` records a hostname rather than an IP address
- `TXT` values are limited to 2048 characters
- Names, prefixes and `ALIASES` must be valid DNS names: labels of letters, digits, `_` and `-` separated by dots, optionally starting with `*` for wildcards
- `CAA` records require `tag`: `issue`, `issuewild` or `iodef`
- `key` must not contain whitespace
- Record keys must be unique. The error shows where each duplicate is defined, e.g. `"_acme-challenge.app TXT 79bead8e6d65" from records["_acme-challenge.app"]["TXT"][0] and records["app"]["_acme-challenge.TXT"][0]`
- A `CNAME` (including `ALIASES`) cannot share its name with other records, except at the zone apex `@` where Cloudflare uses CNAME flattening

## Inputs

Both wrappers take `zone_id`, `zone_name` (optional, looked up from `zone_id` when omitted), `records` and the [defaults](#defaults-comments-and-tags); the v5 wrapper also takes `import_existing`.

The type of `records` is shown as `any`: Terraform silently drops unknown attributes when it converts a value to an object type, so the module accepts the value as is, rejects unknown attributes, and then converts it to the typed structure described in [Record Object Schema](#record-object-schema). The full reference of inputs, outputs, requirements and resources is generated from the code with [terraform-docs](https://terraform-docs.io): [`modules/dns/v4`](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/tree/main/modules/dns/v4), [`modules/dns/v5`](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/tree/main/modules/dns/v5). The inputs of the root module are also shown on the [Terraform Registry](https://registry.terraform.io/modules/NikitaPuglachenko/easy-dns/cloudflare/latest?tab=inputs).

### Record Object Schema

| Field | Description | Default |
|-------|-------------|---------|
| `content` | IP address, hostname, or text value | `null` |
| `ttl` | Time to Live (automatically set to `1` if proxied) | `default_ttl` (`3600`) |
| `proxied` | Whether the record gets Cloudflare's proxy | `default_proxied` (`false`) for `A`, `AAAA`, `CNAME` and `ALIASES`, otherwise `false` |
| `priority` | Priority for MX and URI records | `null` |
| `tag` | Tag for CAA records (`issue`, `issuewild`, `iodef`) | `null` |
| `flags` | Flags for CAA records | `0` |
| `data` | Fields of structured records, see [Record Types](#record-types) | `null` |
| `key` | Stable key used instead of the value in the record key, see [Record Keys](#record-keys) | `null` |
| `comment` | Note shown in the Cloudflare dashboard | `default_comment` |
| `tags` | Tags such as `owner:web`, added to `default_tags` | `[]` |
| `settings` | `flatten_cname`, `ipv4_only` and `ipv6_only` (provider v5 only, ignored by the v4 wrapper) | `null` |

### Defaults, Comments and Tags

Values that most records share can be set once for the module call, and overridden per record:

| Input | Description | Default |
|-------|-------------|---------|
| `default_ttl` | TTL of records that do not set one | `3600` |
| `default_proxied` | Proxying of `A`, `AAAA`, `CNAME` and `ALIASES` records that do not set `proxied` (other types are never proxied) | `false` |
| `default_comment` | Comment of records that do not set one | `null` |
| `default_tags` | Tags added to the tags of every record | `[]` |

```hcl
module "dns" {
  source  = "NikitaPuglachenko/easy-dns/cloudflare"
  version = "~> 2.6"

  zone_id         = var.zone_id
  zone_name       = "example.com"
  default_proxied = true
  default_comment = "Managed by Terraform"
  default_tags    = ["managed-by:terraform"]

  records = {
    # Proxied, with the default comment and tags
    "@" = { A = [{ content = "192.0.2.10" }] }

    "vpn" = {
      A = [{ content = "192.0.2.20", proxied = false, comment = "WireGuard" }]
    }
  }
}
```

Cloudflare supports record tags only on some plans; on other plans, leave `default_tags` and `tags` empty.

## Outputs

- `record_names`: names of all managed records
- `records`: managed records keyed by their [record key](#record-keys), with `id`, `name`, `type` and `content`
- `state_migration`: map of the record keys used by 1.x to the current ones, see [Upgrading from v1](#upgrading-from-v1)
- `import_ids` (v5): import IDs of records that already exist in the zone, see [Importing Existing Records](#importing-existing-records)

## Records in YAML

Records can be kept in a YAML file and passed with `yamldecode`:

```hcl
records = yamldecode(file("${path.module}/dns.yaml")).records
```

`schema/records.schema.json` is a JSON Schema for such a file (a document with a `records` key). Editors use it for completion of record types, attributes and `data` fields, and highlight mistakes such as `proxid`, `ttl: 5m` or a CAA `tag` that does not exist before `terraform plan`:

The schema URL of this version is [`https://raw.githubusercontent.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/v2.6.0/schema/records.schema.json`](https://raw.githubusercontent.com/NikitaPuglachenko/terraform-cloudflare-easy-dns/v2.6.0/schema/records.schema.json).

- **VS Code** (with the YAML extension): add a comment with the schema URL at the top of the file

  ```yaml
  # yaml-language-server: $schema=<schema URL>
  ```

- **JetBrains IDEs**: Settings, Languages & Frameworks, Schemas and DTDs, JSON Schema Mappings: add the schema URL and map it to the YAML files with records.

Use the schema of the module version you use. For records written in HCL, Terraform provides no such completion, and misspelled attributes are reported at `plan`.

`yamldecode` follows YAML 1.1, where unquoted `yes`, `no`, `on`, `off`, `y` and `n` (in any case) are booleans; quote such values, e.g. `content: "on"`. The module accepts the unquoted `N` of a LOC `lat_direction`.

## Recipes

Mail with SPF, DKIM and DMARC; the DKIM record has a `key`, so rotating the key updates the record in place:

```hcl
"@" = {
  MX = [
    { content = "mx1.mail.example.net", priority = 10 },
    { content = "mx2.mail.example.net", priority = 20 },
  ]
  TXT = [{ content = "v=spf1 include:_spf.mail.example.net -all" }]

  "google._domainkey.TXT" = [
    { key = "dkim", content = "v=DKIM1; k=rsa; p=MIIBIjANBg..." },
  ]
  "_dmarc.TXT" = [
    { content = "v=DMARC1; p=quarantine; rua=mailto:dmarc@example.com" },
  ]
}
```

A website behind the Cloudflare proxy, with `www` pointing to the apex:

```hcl
"@" = {
  A       = [{ content = "192.0.2.10", proxied = true }]
  ALIASES = [{ content = "www", proxied = true }]
}
```

Certificate authority restrictions and the ACME DNS challenge of a certificate for `app.example.com`:

```hcl
"@" = {
  CAA = [
    { content = "letsencrypt.org", tag = "issue" },
    { content = "letsencrypt.org", tag = "issuewild" },
    { content = "mailto:security@example.com", tag = "iodef" },
  ]
}
"app" = {
  A                     = [{ content = "192.0.2.30" }]
  "_acme-challenge.TXT" = [{ key = "acme", content = "challenge-token" }]
}
```

A service advertised with SRV:

```hcl
"_sip._tcp" = {
  SRV = [{
    data = { priority = 10, weight = 5, port = 5060, target = "sip.example.com" }
  }]
}
```

## Importing Existing Records

When the zone already has records, the first `apply` would fail with "record already exists" for each of them. With provider v5, the module can find the existing records and adopt them into the state instead:

1. Set `import_existing = true`. The module then reads the records of the zone (the API token needs the `DNS Read` permission) and matches them to the configured records by name, type and value. The records are read with one request per record type of the configuration, which avoids a provider crash on zones with CAA records ([cloudflare/terraform-provider-cloudflare#7004](https://github.com/cloudflare/terraform-provider-cloudflare/issues/7004)).
2. Add an `import` block next to the module call:

   ```hcl
   import {
     for_each = module.dns.import_ids
     to       = module.dns.module.v5.cloudflare_dns_record.record[each.key]
     id       = each.value
   }
   ```

   With the `//modules/dns/v5` submodule, the address has no `module.v5`: `module.dns.cloudflare_dns_record.record[each.key]`.

3. Run `terraform plan`. Existing records are shown as imported, and only records missing in the zone are created. Check that no record you expect to be imported is shown as created.
4. Run `terraform apply`, then remove the `import` block and `import_existing`, so the zone is not read on every plan.

For structured records (`SRV`, `HTTPS`, `TLSA`, ...), provider v5 plans a one-time in-place update right after the import, without visible changes; after the `apply`, the plan is empty.

Matching ignores case, a trailing dot and the quoting of TXT values. A record is imported only when exactly one existing record matches it: when the zone has several identical records, the record is not imported and `plan` shows it as created, so the duplicates can be cleaned up first.

## Upgrading from v1

Version 2 changes the record keys in the state (see [Record Keys](#record-keys)). Without migration, Terraform would destroy and recreate every record. The `state_migration` output maps the old keys to the new ones, so the migration can be done with `moved` blocks:

1. Change the module `ref` to `v2.x` and run `terraform init -upgrade`.
2. Generate `moved` blocks (requires `jq`). Set `MODULE` to the module address and `RESOURCE` to `cloudflare_record` for the `v4` submodule or `cloudflare_dns_record` for the `v5` submodule (version 1 had no root module):

   ```sh
   MODULE=module.dns
   RESOURCE=cloudflare_record
   echo "jsonencode(${MODULE}.state_migration)" | terraform console \
     | jq -r --arg addr "$MODULE.$RESOURCE.record" '
         fromjson | to_entries[] |
         "moved {",
         "  from = \($addr)[\(.key | tojson)]",
         "  to   = \($addr)[\(.value | tojson)]",
         "}", ""' \
     > dns_migration.tf
   ```

3. Run `terraform plan`. It should only show records that have moved, with no records to add or destroy.
4. Run `terraform apply`, then delete `dns_migration.tf`. The next `terraform plan` should show no changes.

Upgrade the keys and switch from `v4` to `v5` in separate steps.

## Switching from the v5 Submodule to the Root Module

The root module wraps the v5 submodule, so its records have one more level in their address. When switching `source` from `NikitaPuglachenko/easy-dns/cloudflare//modules/dns/v5` (or a Git source with `//modules/dns/v5`) to the root module, add a `moved` block next to the module call, so the records are not recreated:

```hcl
moved {
  from = module.dns.cloudflare_dns_record.record
  to   = module.dns.module.v5.cloudflare_dns_record.record
}
```

Run `terraform init -upgrade` and `terraform plan`: it should only show records that have moved. After `terraform apply`, the `moved` block can be removed. Staying on the submodule is fine as well.

## Migrating from v4 to v5

The v5 wrapper contains a `moved` block from `cloudflare_record` to `cloudflare_dns_record`, so the state is migrated without recreating records:

1. Upgrade the Cloudflare provider to `~> 5.26`.
2. Change the module `source` from `//modules/dns/v4` to `//modules/dns/v5`, keeping the module name the same. To go straight to the root module, also add the `moved` block from [Switching from the v5 Submodule to the Root Module](#switching-from-the-v5-submodule-to-the-root-module), with `cloudflare_record` in `from`.
3. Run `terraform init -upgrade` and `terraform plan`. The plan should only show moved resources, without destroying or creating records; provider v5 also plans a one-time in-place update of the moved records (e.g. CAA `flags` become numbers). Review it carefully before applying.
4. Run `terraform apply`. Provider v5 (checked with 5.26) may report `Provider produced inconsistent result after apply` with `.modified_on` for some records: the timestamp in the migrated state has a different precision ([cloudflare/terraform-provider-cloudflare#7387](https://github.com/cloudflare/terraform-provider-cloudflare/issues/7387)). The records are updated anyway; run `terraform plan` again, it should show no changes.

## Testing

The core module, both wrappers and the examples have plan-only tests (the wrappers and examples use a mocked provider), no Cloudflare credentials needed:

```sh
cd modules/dns/v5
terraform init
terraform test
```

The module READMEs are generated with [terraform-docs](https://terraform-docs.io), and the JSON Schema with a script that reads the record types and `data` fields from the records module. After changing variables, outputs, requirements or record types, regenerate them:

```sh
./scripts/generate-docs.sh
python3 scripts/generate-schema.py
python3 scripts/test-schema.py   # requires jsonschema and pyyaml
```

CI runs `terraform fmt`, `validate` and `test` for the root module, the core module, both wrappers and the examples (on Terraform 1.8 and the latest version, and on the minimum supported provider versions), checks that the module READMEs and the JSON Schema are up to date, tests the schema, checks that the root module and the wrappers have the same interface, [TFLint](https://github.com/terraform-linters/tflint) and [Gitleaks](https://github.com/gitleaks/gitleaks) on every pull request.

### End-to-End Tests

`tests/e2e/run.sh` runs against a real Cloudflare zone. Under a label of the run (e.g. `e2e-1234.example.com`), it:

1. Creates records of every type through the root module and checks that a second `plan` shows no changes (no drift in the provider).
2. Changes values: a record without a `key` is replaced, a record with a `key` is updated in place.
3. Adopts the same records into an empty state with `import_existing` and checks that all of them are imported and none created.
4. Creates records with the v4 wrapper and opens the state with the v5 wrapper: the records must be moved, not recreated.
5. Deletes everything. `tests/e2e/sweep.sh` also removes records left by failed runs; it only deletes records with the comment `easy-dns-e2e` and a run label in the name.

```sh
CLOUDFLARE_API_TOKEN=... E2E_ZONE_ID=... E2E_ZONE_NAME=example.com tests/e2e/run.sh
```

The token needs the `DNS Edit` permission on the zone. In CI, the test runs weekly and on demand (never for pull requests), with the token stored in the `cloudflare-e2e` environment.

## License
MIT
