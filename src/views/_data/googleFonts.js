const fetch = require("@11ty/eleventy-fetch");

module.exports = async () => {
	try {
		return await fetch("https://fonts.googleapis.com/css2?family=Mrs+Sheppards&family=EB+Garamond&family=Playfair+Display:wght@800&display=swap", {
			duration: "1y",
			type: "text",
		})
	} catch (error) {
		console.error(error.message)
	}
}
