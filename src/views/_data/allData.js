const fetch = require("@11ty/eleventy-fetch");

module.exports = async () => {
	try {
		return (await fetch(`${process.env['STRAPI_PROTOCOL']}://${process.env['STRAPI_HOST']}:${process.env['STRAPI_PORT']}/graphql`, {
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
									name
									articles(
										sort: "publishedAt:DESC"
									) {
										data {
											id
											attributes {
												title
												body
												author
												slug
												publishedAt
												updatedAt
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
								}
							}
						}
						articles(sort: "publishedAt:DESC") {
							data {
								id
								attributes {
									title
									body
									author
									slug
									publishedAt
									updatedAt
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
					}`
				})
			}
		})).data
	} catch (error) {
		console.error(error.message)
	}
}
