resource "cloudflare_pages_project" "cloudflare_pages_project" {
	account_id        = data.external.env.result["CLOUDFLARE_ACCOUNT_ID"]
	name              = data.external.env.result["APP_NAME"]
	production_branch = data.external.env.result["GITHUB_REF_NAME"]

	build_config {
		build_command = "npx @11ty/eleventy"
		destination_dir = "_site"
	}

	deployment_configs {
		preview {
			fail_open = true
		}

		production {
			environment_variables = {
				"NODE_VERSION"    = data.external.env.result["NODE_VERSION"]
				"STRAPI_HOST"     = data.external.env.result["STRAPI_HOST"]
				"STRAPI_PORT"     = data.external.env.result["STRAPI_PORT"]
				"STRAPI_PROTOCOL" = data.external.env.result["STRAPI_PROTOCOL"]
				"STRAPI_FETCH_INTERVAL" = data.external.env.result["STRAPI_FETCH_INTERVAL"]
			}
			fail_open = true
		}
	}

	source {
		type = "github"

		config {
			owner                   = data.external.env.result["GITHUB_REPOSITORY_OWNER"]
			production_deployment_enabled = false
			preview_branch_includes = [
				"*",
			]
			production_branch       = data.external.env.result["GITHUB_REF_NAME"]
			repo_name               = data.external.env.result["GITHUB_REPOSITORY_NAME"]
		}
	}
}
