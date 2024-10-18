resource "cloudflare_record" "apex" {
  name    = "exch.gr"
  proxied = true
  ttl     = 1
  type    = "CNAME"
  value   = "exch-gr-11ty.pages.dev"
	zone_id = data.external.env.result["CLOUDFLARE_ZONE_ID"]
}
