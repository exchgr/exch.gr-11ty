const allData = require("./allData");

module.exports = async () => {
	try {
		return (await allData).data.redirects
	} catch (e) {
		console.error(e)
	}
}
