module.exports = async () => {
	try {
		const {default: fetch} = await import('node-fetch')
		const data = await fetch(`${process.env['STRAPI_PROTOCOL']}://${process.env['STRAPI_HOST']}:${process.env['STRAPI_PORT']}/graphql`, {
			method: "POST",
			headers: {
				"Content-Type": "application/json",
				"Accept": "application/json",
				"Authorization": `bearer ${process.env['STRAPI_TOKEN']}`
			},
			body: JSON.stringify({
				query: `{
					collections(
						sort: "updatedAt:DESC"
					) {
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
				}`
			})
		})

		const response = await data.json()

		response.errors?.map((error) => {
			console.error(error.message)
			throw new Error(error.message)
		})

		return response.data.collections
	} catch (error) {
		console.error(error.message)
	}
}