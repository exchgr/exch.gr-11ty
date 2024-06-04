const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})
const pluginRss = require("@11ty/eleventy-plugin-rss")
const {encode} = require('html-entities')
const allData = require('./src/views/_data/allData')
const filters = require('./src/lib/filters')
const shortcodes = require('./src/lib/shortcodes')

module.exports = (eleventyConfig) => {
	eleventyConfig.addFilter('markdown', body => markdownIt.render(body))
	eleventyConfig.addFilter('htmlEncode', encode)
	eleventyConfig.setLibrary("md", markdownIt)

	// include assets
	eleventyConfig.addPassthroughCopy({"src/styles": "styles"})
	eleventyConfig.addPassthroughCopy({"src/fonts": "fonts"})
	eleventyConfig.addPassthroughCopy({"src/scripts": "scripts"})
	eleventyConfig.addPassthroughCopy({"src/images": "images"})
	eleventyConfig.addPassthroughCopy({"src/views/robots.txt": "robots.txt"})

	// rss plugin
	eleventyConfig.addPlugin(pluginRss);
	eleventyConfig.addLiquidFilter("absoluteUrl", pluginRss.absoluteUrl)
	eleventyConfig.addLiquidFilter("convertHtmlToAbsoluteUrls", pluginRss.convertHtmlToAbsoluteUrls)
	eleventyConfig.addLiquidFilter("dateToRfc3339", pluginRss.dateToRfc3339)
	eleventyConfig.addLiquidFilter("dateToRfc822", pluginRss.dateToRfc822)
	eleventyConfig.addLiquidFilter("getNewestCollectionItemDate", pluginRss.getNewestCollectionItemDate)

	Object.keys(shortcodes).forEach((key) => {
			eleventyConfig.addShortcode(key, shortcodes[key])
		})

	Object.keys(filters).forEach((key) => {
		eleventyConfig.addFilter(key, filters[key])
	})

	eleventyConfig.on('eleventy.before', async () => {
		const resolvedAllData = (await allData).data;
		resolvedAllData.collections.data.map((collection) =>
			collection.attributes.slug
		).forEach((collectionSlug) =>
			// CAUTION: overwrites existing collections
			eleventyConfig.getCollections()[collectionSlug] = (collectionApi) =>
				collectionApi.getFilteredByGlob("./src/views/article.liquid").filter((article) =>
					article.data.article.attributes.collection.data.attributes.slug === collectionSlug
				)
		)

		resolvedAllData.tags.data.map((tag) =>
			tag.attributes.slug
		).forEach((tagSlug) =>
			// CAUTION: overwrites existing collections
			eleventyConfig.getCollections()[`tags/${tagSlug}`] = (collectionApi) =>
				collectionApi.getFilteredByGlob("./src/views/article.liquid").filter((article) =>
					article.data.article.attributes.tags.data.filter((tag) =>
						tag.attributes.slug === tagSlug
					).length > 0
				)
		)
	})

	return {
		dir: {
			input: "src/views",
			includes: "_includes",
			layouts: "_includes/layouts",
			data: "_data",
		},
	}
}
