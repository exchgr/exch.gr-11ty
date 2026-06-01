const addDocumentId = (obj) =>
	obj.id && !obj.documentId
		? {...obj, documentId: obj.id}
		: obj;

module.exports = addDocumentId;
