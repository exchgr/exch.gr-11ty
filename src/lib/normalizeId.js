const addId = require("./addId");
const addDocumentId = require("./addDocumentId");

const normalizeId = (obj) =>
	!obj || typeof obj !== 'object'
		? obj
		: addDocumentId(addId(obj));

module.exports = normalizeId;
