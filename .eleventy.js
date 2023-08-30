const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})
const pluginRss = require("@11ty/eleventy-plugin-rss")
const {encode} = require('html-entities')
const allData = require('./src/views/_data/allData')

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

	eleventyConfig.addShortcode("inspect", (thing) => {
		return ""
	})

	eleventyConfig.addFilter("noAll", (collections) => (
		Object.keys(collections).filter((slug) => (
			slug !== "all"
		)).reduce(
			(accumulator, slug) => (
				accumulator[slug] = collections[slug], accumulator
			),
			{}
		)
	))

	eleventyConfig.on('eleventy.before', async () => {
		try {
			(await allData).data.collections.data.map((collection) =>
				collection.attributes.slug
			).forEach((collectionSlug) =>
				eleventyConfig.addCollection(collectionSlug, (collectionApi) =>
					collectionApi.getFilteredByGlob("./src/views/article.liquid").filter((item) =>
						item.data.article.attributes.collection.data.attributes.slug === collectionSlug
					)
				)
			)
		} catch(e) {
			console.error(e)
		}
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
