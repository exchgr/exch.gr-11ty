resource "cloudflare_record" "apex" {
  name    = "exch.gr"
  proxied = false
  ttl     = 60
  type    = "CNAME"
  value   = "exch-gr-11ty.pages.dev"
	zone_id = data.external.env.result["CLOUDFLARE_ZONE_ID"]
}
