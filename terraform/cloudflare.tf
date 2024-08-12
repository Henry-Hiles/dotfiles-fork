provider "cloudflare" {
  api_token = data.sops_file.terraform.data["cloudflare.api-token"]
}

# -------------
# DDNS and ACME token

data "cloudflare_api_token_permission_groups" "all" {}

resource "cloudflare_api_token" "dns" {
  name = "dns"

  policy {
    permission_groups = [
      data.cloudflare_api_token_permission_groups.all.zone["Zone Read"],
      data.cloudflare_api_token_permission_groups.all.zone["Zone Settings Read"],
      data.cloudflare_api_token_permission_groups.all.zone["DNS Write"],
    ]
    resources = {
      "com.cloudflare.api.account.zone.*" = "*"
    }
  }
}

output "cloudflare_token" {
  value     = cloudflare_api_token.dns.value
  sensitive = true
}

# -------------
# Account ID

locals {
  cloudflare_main_account_id = data.sops_file.terraform.data["cloudflare.account-id"]
}

# -------------
# Zones

resource "cloudflare_zone" "com_li7g" {
  account_id = local.cloudflare_main_account_id
  zone       = "li7g.com"
}

resource "cloudflare_zone" "zip_prebuilt" {
  account_id = local.cloudflare_main_account_id
  zone       = "prebuilt.zip"
}

resource "cloudflare_zone_settings_override" "com_li7g" {
  zone_id = cloudflare_zone.com_li7g.id
  settings {
    ssl = "strict"
  }
}

resource "cloudflare_zone_settings_override" "zip_prebuilt" {
  zone_id = cloudflare_zone.zip_prebuilt.id
  settings {
    ssl = "strict"
  }
}

# ttl = 1 for automatic

# CNAME records

resource "cloudflare_record" "li7g_home" {
  name    = "home"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "ae370c7d335a.sn.mynetname.net"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "li7g" {
  name    = "li7g.com"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  content = "fsn0.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "zip_prebuilt" {
  name    = "prebuilt.zip"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  content = "prebuilt-zip.li7g.com"
  zone_id = cloudflare_zone.zip_prebuilt.id
}
resource "cloudflare_record" "zip_prebuilt_wildcard" {
  name = "*"
  # cluodflare's edge ssl certificate
  # only covers second level of the domain
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "prebuilt-zip.li7g.com"
  zone_id = cloudflare_zone.zip_prebuilt.id
}

locals {
  service_cname_mappings = {
    portal        = { on = "hkg0", proxy = true }
    ntfy          = { on = "hkg0", proxy = true }
    atuin         = { on = "hkg0", proxy = true }
    cache-overlay = { on = "hkg0", proxy = true }
    nuc-proxy     = { on = "hkg0", proxy = true }
    hydra-proxy   = { on = "hkg0", proxy = true }
    # typhon-proxy    = { on = "hkg0", proxy = true }
    tar             = { on = "lax0", proxy = true }
    pgp-public-key  = { on = "lax0", proxy = true }
    oranc           = { on = "lax0", proxy = true }
    ace-bot         = { on = "lax0", proxy = true }
    hledger         = { on = "mtl0", proxy = true }
    vault           = { on = "mtl0", proxy = true }
    pb              = { on = "mtl0", proxy = true }
    git             = { on = "mtl0", proxy = true }
    box             = { on = "mtl0", proxy = true }
    minio-console   = { on = "mtl0", proxy = true }
    static          = { on = "mtl0", proxy = true }
    http-test       = { on = "mtl0", proxy = true }
    minio           = { on = "mtl0", proxy = false }
    prebuilt-zip    = { on = "mtl0", proxy = false }
    "shanghai.derp" = { on = "shg0", proxy = false }
    dst             = { on = "shg0", proxy = false }
    matrix-qq       = { on = "shg0", proxy = false }
    teamspeak       = { on = "shg0", proxy = false }
    matrix          = { on = "fsn0", proxy = true }
    matrix-syncv3   = { on = "fsn0", proxy = true }
    synapse-admin   = { on = "fsn0", proxy = true }
    social          = { on = "fsn0", proxy = true }
    mastodon        = { on = "fsn0", proxy = true }
    smtp            = { on = "fsn0", proxy = false }
    influxdb        = { on = "fsn0", proxy = true }
    bird-lg         = { on = "fsn0", proxy = true }
    dn42            = { on = "fsn0", proxy = true }
    keycloak        = { on = "fsn0", proxy = true }
    hydra           = { on = "nuc", proxy = false }
    # typhon          = { on = "nuc", proxy = false }
    transmission = { on = "nuc", proxy = false }
    jellyfin     = { on = "nuc", proxy = false }
    nextcloud    = { on = "nuc", proxy = false }
    mc           = { on = "nuc", proxy = false }
  }
}
output "service_cname_mappings" {
  value     = local.service_cname_mappings
  sensitive = false
}

resource "cloudflare_record" "general_cname" {
  for_each = local.service_cname_mappings

  name    = each.key
  proxied = each.value.proxy
  ttl     = 1
  type    = "CNAME"
  content = "${each.value.on}.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "general_tailscale_cname" {
  for_each = local.service_cname_mappings

  name    = "${each.key}.ts"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "${each.value.on}.ts.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "general_zerotier_cname" {
  for_each = local.service_cname_mappings

  name    = "${each.key}.zt"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "${each.value.on}.zt.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "general_dn42_cname" {
  for_each = local.service_cname_mappings

  name    = "${each.key}.dn42"
  proxied = false
  ttl     = 1
  type    = "CNAME"
  content = "${each.value.on}.dn42.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

# anycast record

resource "cloudflare_record" "dns" {
  name    = "dns"
  proxied = false
  ttl     = 1
  type    = "AAAA"
  content = local.dn42_anycast_dns_v6
  zone_id = cloudflare_zone.com_li7g.id
}

# localhost record

resource "cloudflare_record" "localhost_a" {
  name    = "localhost"
  proxied = false
  ttl     = 1
  type    = "A"
  content = "127.0.0.1"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "localhost_aaaa" {
  name    = "localhost"
  proxied = false
  ttl     = 1
  type    = "AAAA"
  content = "::1"
  zone_id = cloudflare_zone.com_li7g.id
}

# ad-hoc ddns record

# currently nothing
# resource "cloudflare_record" "mc" {
#   name    = "mc"
#   proxied = false
#   ttl     = 1
#   type    = "A"
#   content   = "127.0.0.1"
#   zone_id = cloudflare_zone.com_li7g.id
#   lifecycle { ignore_changes = [content] }
# }

# smtp records for sending

resource "cloudflare_record" "li7g_dkim" {
  name    = "default._domainkey"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "v=DKIM1; k=${local.dkim_algorithm}; p=${local.dkim_public_key}"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "li7g_dmarc" {
  name    = "_dmarc"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "v=DMARC1; p=quarantine; ruf=mailto:postmaster@li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "li7g_spf" {
  name    = "li7g.com"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "v=spf1 include:_spf.mx.cloudflare.net redirect=smtp.li7g.com"
  zone_id = cloudflare_zone.com_li7g.id
}

resource "cloudflare_record" "li7g_smtp_spf" {
  name    = "smtp"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "v=spf1 a ~all"
  zone_id = cloudflare_zone.com_li7g.id
}

# github pages dns challange

resource "cloudflare_record" "github_pages_challenge" {
  name    = "_github-pages-challenge-linyinfeng"
  proxied = false
  ttl     = 1
  type    = "TXT"
  content = "6d2a79cedb6068b2a2b13ed18ccf4e"
  zone_id = cloudflare_zone.com_li7g.id
}

# cache

resource "cloudflare_record" "li7g_b2" {
  name    = "b2"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  content = module.b2_download_url.host
  zone_id = cloudflare_zone.com_li7g.id
}
resource "cloudflare_record" "li7g_cache" {
  name    = "cache"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  content = module.b2_download_url.host
  zone_id = cloudflare_zone.com_li7g.id
}

# Ruleset

resource "cloudflare_ruleset" "li7g_http_request_transform" {
  name        = "url-rewrite"
  description = "URL Rewrite"
  kind        = "zone"
  zone_id     = cloudflare_zone.com_li7g.id
  phase       = "http_request_transform"

  rules {
    enabled     = true
    description = "Rewrite cache path"
    expression  = "(http.host eq \"cache.li7g.com\")"
    action      = "rewrite"
    action_parameters {
      uri {
        path {
          expression = "concat(\"/file/${b2_bucket.cache.bucket_name}\", http.request.uri.path)"
        }
      }
    }
  }
}

resource "cloudflare_ruleset" "li7g_http_config_settings" {
  name        = "acme-challenge"
  description = "Disable SSL for ACME challenge"
  kind        = "zone"
  zone_id     = cloudflare_zone.com_li7g.id
  phase       = "http_config_settings"

  rules {
    enabled = true
    action  = "set_config"
    action_parameters {
      automatic_https_rewrites = false
      ssl                      = "off"
    }
    expression  = <<EOT
      (starts_with(http.request.uri.path, "/.well-known/acme-challenge/"))
    EOT
    description = "Disable SSL for ACME challenge"
  }
}

resource "cloudflare_ruleset" "li7g_http_request_firewall_custom" {
  name        = "block-cn-traffic"
  description = "Block CN GET traffic for some hosts"
  kind        = "zone"
  zone_id     = cloudflare_zone.com_li7g.id
  phase       = "http_request_firewall_custom"

  rules {
    enabled     = true
    action      = "block"
    expression  = <<EOT
      (
        ip.geoip.country eq "CN" and
        http.request.method eq "GET" and
        ( http.host eq "pb.li7g.com" or
          http.host eq "social.li7g.com" or
          http.host eq "mastodon.li7g.com" or
          http.host eq "matrix.li7g.com" or
          http.host eq "ace-bot.li7g.com")
      )
    EOT
    description = "Block Traffic to some site from CN"
  }
}

resource "cloudflare_ruleset" "li7g_http_request_cache_settings" {
  name        = "cache-settings"
  description = "Cache settings"
  kind        = "zone"
  zone_id     = cloudflare_zone.com_li7g.id
  phase       = "http_request_cache_settings"

  rules {
    enabled     = true
    action      = "set_cache_settings"
    expression  = <<EOT
      (
        http.host eq "pb.li7g.com" or
        http.host eq "cache.li7g.com" or
        http.host eq "oranc.li7g.com"
      )
    EOT
    description = "Set cache settings rule"
    action_parameters {
      cache = true # cache everything
    }
  }
}

# Email routing

resource "cloudflare_email_routing_settings" "li7g" {
  zone_id = cloudflare_zone.com_li7g.id
  enabled = true
}

resource "cloudflare_email_routing_rule" "postmaster_li7g" {
  zone_id = cloudflare_zone.com_li7g.id
  name    = "postmaster"
  enabled = true
  matcher {
    type  = "literal"
    field = "to"
    value = "postmaster@li7g.com"
  }
  action {
    type  = "forward"
    value = ["lin.yinfeng@outlook.com"]
  }
}

resource "cloudflare_email_routing_rule" "admin_li7g" {
  zone_id = cloudflare_zone.com_li7g.id
  name    = "admin"
  enabled = true
  matcher {
    type  = "literal"
    field = "to"
    value = "admin@li7g.com"
  }
  action {
    type  = "forward"
    value = ["lin.yinfeng@outlook.com"]
  }
}

resource "cloudflare_email_routing_catch_all" "li7g" {
  zone_id = cloudflare_zone.com_li7g.id
  name    = "catch all"
  enabled = true
  matcher {
    type = "all"
  }
  action {
    type  = "drop"
    value = []
  }
}
