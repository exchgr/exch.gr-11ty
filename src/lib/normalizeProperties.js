const normalizeProperties = (obj, normalizeFn) =>
	Object.fromEntries(
		Object.entries(obj).map(([key, val]) => [key, normalizeFn(val)])
	);

module.exports = normalizeProperties;
