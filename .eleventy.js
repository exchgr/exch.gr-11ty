const markdownIt = require("markdown-it")({
	html: true,
	typographer: true
})
const markdownItFootnote = require("markdown-it-footnote")
const pluginRss = require("@11ty/eleventy-plugin-rss")
const {encode} = require('html-entities')
const allData = require('./src/views/_data/allData')
const filters = require('./src/lib/filters')
const shortcodes = require('./src/lib/shortcodes')
const markdownItHighlightjs = require("markdown-it-highlightjs")
const c = require('highlight.js/lib/languages/c');
const clip = require('text-clipper').default
const { htmlToText } = require('html-to-text')

module.exports = (eleventyConfig) => {
	markdownIt.use(markdownItFootnote)
	markdownIt.use(markdownItHighlightjs, {register: {c}})
	eleventyConfig.addFilter('markdown', body => markdownIt.render(body))

	eleventyConfig.addFilter('clip', (body, maxLength = 0) =>
		clip(body, maxLength, {
			html: true,
			imageWeight: 500
		})
	)

	eleventyConfig.addFilter('minimalHtmlClip', (body, maxLength = 0) =>
		clip(body, maxLength, {
			html: true,
			stripTags: ['img', 'figure', 'lite-youtube']
		})
	)

	eleventyConfig.addFilter('textClip', (body, maxLength = 0) => {
		const options = {
			html: false
		}

		return clip(body, maxLength, options)
	})

	eleventyConfig.addFilter('htmlToText', (body) => (
		htmlToText(body, {
			selectors: [
				{
					selector: 'a',
					options: {
						ignoreHref: true
					}
				},
				{
					selector: 'img',
					format: 'skip'
				},
				{
					selector: 'iframe',
					format: 'skip'
				},
				{
					selector: 'figure',
					format: 'skip'
				},
				{
					selector: 'blockquote',
					format: 'skip'
				}
			]
		})
	))

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
			eleventyConfig.addCollection(collectionSlug, (collectionApi) =>
				collectionApi.getFilteredByGlob("./src/views/article.liquid").filter((article) =>
					article.data.article.attributes.collection.data.attributes.slug === collectionSlug
				))
		)

		resolvedAllData.tags.data.map((tag) =>
			tag.attributes.slug
		).forEach((tagSlug) =>
			eleventyConfig.addCollection(`tags/${tagSlug}`, (collectionApi) =>
				collectionApi.getFilteredByGlob("./src/views/article.liquid").filter((article) =>
					article.data.article.attributes.tags.data.filter((tag) =>
						tag.attributes.slug === tagSlug
					).length > 0
				))
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
