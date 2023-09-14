const tagsPrefix = /^tags\//

module.exports = {
	isTag: (slug) => (
		!!slug.match(tagsPrefix)
	),

	stripTagsPrefix: slug => slug.replace(tagsPrefix, "")
}
