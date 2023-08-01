const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})
const pluginRss = require("@11ty/eleventy-plugin-rss")
const nunjucks = require("nunjucks")

module.exports = (eleventyConfig) => {
	eleventyConfig.addFilter('markdown', body => markdownIt.render(body))
	eleventyConfig.addFilter('interpolate', function(body, article) {
		return nunjucks.renderString(body, { article })
	})
	eleventyConfig.setLibrary("md", markdownIt)

	// include assets
	eleventyConfig.addPassthroughCopy({"src/styles": "styles"})
	eleventyConfig.addPassthroughCopy({"src/fonts": "fonts"})

	eleventyConfig.addPlugin(pluginRss);

	return {
		dir: {
			input: "src/views",
			includes: "_includes",
			layouts: "_includes/layouts",
			data: "_data",
		},
	}
}
