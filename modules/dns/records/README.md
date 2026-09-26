# Records core

Provider-agnostic core used by the `v4` and `v5` wrappers: validates the `records` input and flattens it into a map of records keyed by `<name> <TYPE> <value>`. It has no provider dependency and is not meant to be used directly. See the [main README](../../../README.md) for the input format.

<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
| ---- | ------- |
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.8.0 |

## Providers

No providers.

## Modules

No modules.

## Resources

No resources.

## Inputs

| Name | Description | Type | Default | Required |
| ---- | ----------- | ---- | ------- | :------: |
| <a name="input_existing_records"></a> [existing\_records](#input\_existing\_records) | Records that already exist in the zone, used to find import IDs. Names are fully qualified, as returned by the Cloudflare API | <pre>list(object({<br/>    id      = string<br/>    name    = string<br/>    type    = string<br/>    content = optional(string)<br/>    data    = optional(map(string))<br/>  }))</pre> | `[]` | no |
| <a name="input_records"></a> [records](#input\_records) | DNS records grouped by base name (subdomain or @ for apex), then by record type | <pre>map(<br/>    map(<br/>      list(<br/>        object({<br/>          content  = optional(string)<br/>          ttl      = optional(number, 3600)<br/>          proxied  = optional(bool, false)<br/>          priority = optional(number)<br/><br/>          # for CAA<br/>          tag   = optional(string)<br/>          flags = optional(number, 0)<br/><br/>          # Structured data for SRV, URI, HTTPS, SVCB, TLSA, SMIMEA, SSHFP, DS, DNSKEY, CERT, NAPTR and LOC<br/>          data = optional(map(string))<br/><br/>          # Stable key instead of the record value, so changing the value updates the record in place<br/>          key = optional(string)<br/>        })<br/>      )<br/>    )<br/>  )</pre> | n/a | yes |
| <a name="input_root_domain"></a> [root\_domain](#input\_root\_domain) | Zone domain name (e.g. example.com), used as the target suffix for aliases | `string` | n/a | yes |

## Outputs

| Name | Description |
| ---- | ----------- |
| <a name="output_flat_records"></a> [flat\_records](#output\_flat\_records) | Flattened map of records keyed by "<name> <TYPE> <value>", ready for for\_each |
| <a name="output_import_record_ids"></a> [import\_record\_ids](#output\_import\_record\_ids) | Cloudflare record IDs of existing\_records matching the configured records, keyed by record key. Records with no or several matches are left out |
| <a name="output_state_migration"></a> [state\_migration](#output\_state\_migration) | Map of record keys used by module versions 1.x to the current keys, for state migration |
<!-- END_TF_DOCS -->
