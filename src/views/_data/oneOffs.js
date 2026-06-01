const allData = require("./allData")

module.exports = async () => {
	try {
		return (await allData).data.oneOffs;
	} catch (e) {
		console.error(e)
	}
}
