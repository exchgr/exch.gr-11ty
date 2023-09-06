const allData = require("./allData")

module.exports = async () => {
	try {
		return (await allData).data.oneOffs.data;
	} catch (e) {
		console.error(e)
	}
}
