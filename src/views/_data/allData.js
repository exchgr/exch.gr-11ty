const fetch = require("@11ty/eleventy-fetch");

module.exports = fetch(
	`${process.env['STRAPI_PROTOCOL']}://${process.env['STRAPI_HOST']}:${process.env['STRAPI_PORT']}/graphql`,
	{
		duration: process.env['STRAPI_FETCH_INTERVAL'],
		type: "json",
		fetchOptions: {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				"Accept": "application/json",
				"Authorization": `bearer ${process.env['STRAPI_TOKEN']}`
			},
			body: JSON.stringify({
				query: `{
					collections(sort: "updatedAt:DESC", pagination: { limit: 100000 }) {
						slug
						blurb
						name
						mailName
						mailUrl
					}
					articles(sort: "publishedAt:DESC", pagination: { limit: 100000 }) {
						documentId
						title
						body
						author
						slug
						publishedAt
						updatedAt
						og_image {
							url
						}
						og_type
						collection {
							name
							slug
							mailName
							mailUrl
							blurb
						}
						tags(sort: "name:ASC", pagination: { limit: 100000 }) {
							name
							slug
						}
					}
					tags(sort: "name:ASC", pagination: { limit: 100000 }) {
						slug
						name
					}
					oneOffs(pagination: { limit: 100000 }) {
						title
						body
						slug
					}
					redirects(pagination: { limit: 100000 }) {
						from
						httpCode
						to {
							slug
							collection {
								slug
							}
						}
					}
				}`
			})
		}
	});
