# Scenario 3b: the state of 3a opened with the v5 wrapper

module "fixture" {
  source = "../fixture"

  prefix    = var.prefix
  zone_name = var.zone_name
}

module "dns" {
  source = "../../../modules/dns/v5"

  zone_id         = var.zone_id
  zone_name       = var.zone_name
  default_ttl     = 300
  default_comment = "easy-dns-e2e"
  records         = module.fixture.migration_records
}
