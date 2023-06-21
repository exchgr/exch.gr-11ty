const allData = require("./allData")

module.exports = async () => (await allData()).articles.data
