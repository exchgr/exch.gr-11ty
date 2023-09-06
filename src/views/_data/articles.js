const allData = require("./allData")

module.exports = async () => {
	try {
		return (await allData).data.articles.data
	} catch (e) {
		console.error(e)
	}
}
