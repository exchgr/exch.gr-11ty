const allData = require("./allData")

module.exports = async () => {
	try {
		return (await allData).data.articles
	} catch (e) {
		console.error(e)
	}
}
