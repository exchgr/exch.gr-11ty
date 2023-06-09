const markdownIt = require("markdown-it")

module.exports = (eleventyConfig) => {
	eleventyConfig.setLibrary("md", markdownIt({
		html: true
	}))

	return {
		dir: {
			input: "src/views",
			includes: "_includes",
			layouts: "_includes/layouts",
			data: "_data",
		},
	}
}
