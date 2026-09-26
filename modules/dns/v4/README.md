# DNS records for Cloudflare provider v4

Manages DNS records with `cloudflare_record`. See the [main README](../../../README.md) for usage, record types, keys and migration.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |
| <a name="requirement_cloudflare"></a> [cloudflare](#requirement\_cloudflare) | ~> 4.30 |

## Providers

| Name | Version |
| ---- | ------- |
| <a name="provider_cloudflare"></a> [cloudflare](#provider\_cloudflare) | ~> 4.30 |

## Modules

| Name | Source | Version |
| ---- | ------ | ------- |
| <a name="module_records"></a> [records](#module\_records) | ../records | n/a |

## Resources

| Name | Type |
| ---- | ---- |
| [cloudflare_record.record](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/resources/record) | resource |
| [cloudflare_zone.this](https://registry.terraform.io/providers/cloudflare/cloudflare/latest/docs/data-sources/zone) | data source |

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_records"></a> [records](#input\_records) | DNS records grouped by base name (subdomain or @ for apex), then by record type | <pre>map(<br/>    map(<br/>      list(<br/>        object({<br/>          content  = optional(string)<br/>          ttl      = optional(number, 3600)<br/>          proxied  = optional(bool, false)<br/>          priority = optional(number)<br/><br/>          # for CAA<br/>          tag   = optional(string)<br/>          flags = optional(number, 0)<br/><br/>          # Structured data for SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC<br/>          data = optional(map(string))<br/><br/>          # Stable key instead of the record value, so changing the value updates the record in place<br/>          key = optional(string)<br/>        })<br/>      )<br/>    )<br/>  )</pre> | n/a | yes |
| <a name="input_zone_id"></a> [zone\_id](#input\_zone\_id) | Cloudflare Zone ID | `string` | n/a | yes |
| <a name="input_zone_name"></a> [zone\_name](#input\_zone\_name) | Zone domain name (e.g. example.com). If null, it is looked up from zone\_id | `string` | `null` | no |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_record_names"></a> [record\_names](#output\_record\_names) | Hostnames of all managed records |
| <a name="output_records"></a> [records](#output\_records) | Managed records keyed by their stable identifier, with id, name, type and content |
| <a name="output_state_migration"></a> [state\_migration](#output\_state\_migration) | Map of record keys used by module versions 1.x to the current keys, for state migration |
<!-- END_TF_DOCS -->
