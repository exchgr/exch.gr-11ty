const allData = require("./allData")

module.exports = async () =>
	(await allData()).collections.data.filter((collection) =>
		collection.attributes.slug === "music"
	)[0]
