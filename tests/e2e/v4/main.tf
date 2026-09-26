# Scenario 3a: records created with provider v4

module "fixture" {
  source = "../fixture"

  prefix    = var.prefix
  zone_name = var.zone_name
}

module "dns" {
  source = "../../../modules/dns/v4"

  zone_id         = var.zone_id
  zone_name       = var.zone_name
  default_ttl     = 300
  default_comment = "easy-dns-e2e"
  records         = module.fixture.migration_records
}
