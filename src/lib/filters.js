const {isTag, stripTagsPrefix} = require("./util");

// given a slug that does or does not start with "tags/", extract the tag with
// the matching slug or the category, respectively
const categoryOrTag = (collectionSlug, article) => (
	isTag(collectionSlug) ? extractTag(collectionSlug, article?.data.article) : extractCategory(article?.data.article)
);

const extractTag = (collectionSlug, article) => (
	article?.attributes.tags.data.filter(
		tag => tag.attributes.slug === stripTagsPrefix(collectionSlug)
	)[0]
);

const extractCategory = article =>
	article?.attributes.collection.data;

const noTags = (collections) => (
	Object.keys(collections).filter(slug => !isTag(slug))
		.reduce(_copyObjectFromKeys(collections), {})
);

const noAll = (collections) => (
	Object.keys(collections).filter(slug => slug !== "all")
		.reduce(_copyObjectFromKeys(collections), {})
);

const _copyObjectFromKeys = (collections) => ((accumulator, slug) => (
	accumulator[slug] = collections[slug], accumulator
));

module.exports = {
	noTags,
	noAll,
	categoryOrTag,
	extractTag,
	extractCategory
}
