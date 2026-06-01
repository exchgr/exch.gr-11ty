const normalizeId = require("./normalizeId");
const normalizeArray = require("./normalizeArray");
const normalizeProperties = require("./normalizeProperties");
const renameConnectionKeys = require("./renameConnectionKeys");

const normalizeIdAndProperties = (val) => {
	if (Array.isArray(val)) {
		return normalizeArray(val, normalizeIdAndProperties);
	}
	if (val && typeof val === 'object') {
		return normalizeProperties(normalizeId(val), normalizeIdAndProperties);
	}
	return val;
};

const normalizeResponse = (val) => normalizeIdAndProperties(renameConnectionKeys(val));

module.exports = normalizeResponse;
