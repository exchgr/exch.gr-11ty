const allData = require("./allData")

module.exports = async () =>
	(await allData).data.oneOffs.data
