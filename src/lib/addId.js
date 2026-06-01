const addId = (obj) =>
	obj.documentId && !obj.id
		? {...obj, id: obj.documentId}
		: obj;

module.exports = addId;
