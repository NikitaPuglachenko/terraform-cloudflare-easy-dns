# DNS records for Cloudflare provider v5

Manages DNS records with `cloudflare_dns_record`. See the [main README](https://github.com/NikitaPuglachenko/terraform-cloudflare-easy-dns#readme) for usage, record types, keys and migration.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 5.26 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 5.26 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_records"></a> [records](#module\_records) | ../records | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_dns_record.record](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/dns_record) | resource |
| [cloudflare_dns_records.existing](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/dns_records) | data source |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_default_comment"></a> [default\_comment](#input\_default\_comment) | Comment of records that do not set one, e.g. "Managed by Terraform" | `string` | `null` | no |
| <a name="input_default_proxied"></a> [default\_proxied](#input\_default\_proxied) | Whether A, AAAA, CNAME and ALIASES records that do not set proxied are proxied by Cloudflare | `bool` | `false` | no |
| <a name="input_default_tags"></a> [default\_tags](#input\_default\_tags) | Tags added to all records, e.g. ["managed-by:terraform"] (tags require a Cloudflare plan that supports them) | `list(string)` | `[]` | no |
| <a name="input_default_ttl"></a> [default\_ttl](#input\_default\_ttl) | TTL of records that do not set one (1 means automatic) | `number` | `3600` | no |
| <a name="input_import_existing"></a> [import\_existing](#input\_import\_existing) | Look up records that already exist in the zone and expose their IDs in the import\_ids output, to adopt them with import blocks. Requires the DNS Read permission | `bool` | `false` | no |
| <a name="input_records"></a> [records](#input\_records) | DNS records grouped by base name (subdomain or @ for apex), then by record type | <pre>map(<br/>    map(<br/>      list(<br/>        object({<br/>          content  = optional(string)<br/>          ttl      = optional(number) # default_ttl when not set<br/>          proxied  = optional(bool)   # default_proxied when not set<br/>          priority = optional(number)<br/><br/>          # for CAA<br/>          tag   = optional(string)<br/>          flags = optional(number, 0)<br/><br/>          # Structured data for SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC<br/>          data = optional(map(string))<br/><br/>          # Stable key instead of the record value, so changing the value updates the record in place<br/>          key = optional(string)<br/><br/>          # Shown in the Cloudflare dashboard: comment replaces default_comment, tags are added to default_tags<br/>          comment = optional(string)<br/>          tags    = optional(list(string))<br/><br/>          # Record settings, provider v5 only (ignored by the v4 wrapper)<br/>          settings = optional(object({<br/>            flatten_cname = optional(bool)<br/>            ipv4_only     = optional(bool)<br/>            ipv6_only     = optional(bool)<br/>          }))<br/>        })<br/>      )<br/>    )<br/>  )</pre> | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare Zone ID | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Zone domain name (e.g. example.com). If null, it is looked up from zone\_id | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_import_ids"></a> [import\_ids](#output\_import\_ids) | Import IDs (<zone\_id>/<record\_id>) of records that already exist in the zone, keyed by record key. Empty unless import\_existing is true; records with no or several matches are left out |
| <a name="output_record_names"></a> [record\_names](#output\_record\_names) | Names of all managed records |
| <a name="output_records"></a> [records](#output\_records) | Managed records keyed by their stable identifier, with id, name, type and content |
| <a name="output_state_migration"></a> [state\_migration](#output\_state\_migration) | Map of record keys used by module versions 1.x to the current keys, for state migration |
<!-- END_TF_DOCS -->
