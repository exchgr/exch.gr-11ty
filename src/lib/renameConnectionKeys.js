const renameConnectionKeys = (val) => {
	if (Array.isArray(val)) {
		return val.map(renameConnectionKeys);
	}
	if (val && typeof val === 'object') {
		return Object.fromEntries(
			Object.entries(val).map(([key, value]) => {
				const newKey = key.endsWith('_connection') ? key.slice(0, -11) : key;
				return [newKey, renameConnectionKeys(value)];
			})
		);
	}
	return val;
};

module.exports = renameConnectionKeys;
