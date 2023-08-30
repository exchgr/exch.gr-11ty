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
					collections(sort: "updatedAt:DESC") {
						data {
							attributes {
								slug
							}
						}
					}
					articles(sort: "publishedAt:DESC", pagination: { limit: 100000 }) {
						data {
							id
							attributes {
								title
								body
								author
								slug
								publishedAt
								updatedAt
								og_image {
									data {
										attributes {
											url
										}
									}
								}
								og_type
								collection {
									data {
										attributes {
											name
											slug
										}
									}
								}
								tags(sort: "name:ASC") {
									data {
										attributes {
											name
											slug
										}
									}
								}
							}
						}
					}
					oneOffs {
						data {
							attributes {
								title
								body
								slug
							}
						}
					}
				}`
			})
		}
	})
