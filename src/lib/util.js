const tagsPrefix = /^tags\//

module.exports = {
	stripTagsPrefix: slug => slug.replace(tagsPrefix, "")
}
