const allData = require("./allData")

module.exports = async () =>
	(await allData()).collections.data.reduce((collections, collection) => (
			collections[collection.attributes.slug] = collection, collections
		),
		{}
	)
