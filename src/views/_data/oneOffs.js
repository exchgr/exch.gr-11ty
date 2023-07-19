const allData = require("./allData")

module.exports = async () =>
	(await allData()).oneOffs.data
