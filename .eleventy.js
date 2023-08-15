const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})
const pluginRss = require("@11ty/eleventy-plugin-rss")
const {encode} = require('html-entities')

module.exports = (eleventyConfig) => {
	eleventyConfig.addFilter('markdown', body => markdownIt.render(body))
	eleventyConfig.addFilter('htmlEncode', encode)
	eleventyConfig.setLibrary("md", markdownIt)

	// include assets
	eleventyConfig.addPassthroughCopy({"src/styles": "styles"})
	eleventyConfig.addPassthroughCopy({"src/fonts": "fonts"})
	eleventyConfig.addPassthroughCopy({"src/scripts": "scripts"})
	eleventyConfig.addPassthroughCopy({"src/views/robots.txt": "robots.txt"})

	// rss plugin
	eleventyConfig.addPlugin(pluginRss);
	eleventyConfig.addLiquidFilter("absoluteUrl", pluginRss.absoluteUrl)
	eleventyConfig.addLiquidFilter("convertHtmlToAbsoluteUrls", pluginRss.convertHtmlToAbsoluteUrls)
	eleventyConfig.addLiquidFilter("dateToRfc3339", pluginRss.dateToRfc3339)
	eleventyConfig.addLiquidFilter("dateToRfc822", pluginRss.dateToRfc822)
	eleventyConfig.addLiquidFilter("getNewestCollectionItemDate", pluginRss.getNewestCollectionItemDate)

	return {
		dir: {
			input: "src/views",
			includes: "_includes",
			layouts: "_includes/layouts",
			data: "_data",
		},
	}
}
