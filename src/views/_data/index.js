const allData = require("./allData")

module.exports = async () => (await allData()).collections.data
