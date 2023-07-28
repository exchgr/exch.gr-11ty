const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})

module.exports = (eleventyConfig) => {
	eleventyConfig.addFilter('markdown', body => markdownIt.render(body))
	eleventyConfig.setLibrary("md", markdownIt)

	// include assets
	eleventyConfig.addPassthroughCopy({"src/styles": "styles"})
	eleventyConfig.addPassthroughCopy({"src/fonts": "fonts"})

	return {
		dir: {
			input: "src/views",
			includes: "_includes",
			layouts: "_includes/layouts",
			data: "_data",
		},
	}
}
