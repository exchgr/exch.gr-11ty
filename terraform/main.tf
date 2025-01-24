terraform {
	backend "s3" {}

	required_providers {
		cloudflare = {
			source = "cloudflare/cloudflare"
			version = "~> 4.51"
		}
	}
}

provider "cloudflare" {
}
