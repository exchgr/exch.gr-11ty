const allData = require("./allData")

module.exports = async () => (await allData).data.articles.data
