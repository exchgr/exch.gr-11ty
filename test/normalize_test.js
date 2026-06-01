const {expect} = require('chai');
const addId = require('../src/lib/addId');
const addDocumentId = require('../src/lib/addDocumentId');
const normalizeId = require('../src/lib/normalizeId');
const renameConnectionKeys = require('../src/lib/renameConnectionKeys');
const normalizeResponse = require('../src/lib/normalizeResponse');

describe('Normalize ID Utilities', () => {
	describe('addId', () => {
		it('adds id if documentId is present and id is missing', () => {
			const input = {documentId: 'doc123'};
			const result = addId(input);
			expect(result).to.deep.eq({documentId: 'doc123', id: 'doc123'});
		});

		it('does nothing if id is already present', () => {
			const input = {documentId: 'doc123', id: 'existing'};
			const result = addId(input);
			expect(result).to.deep.eq(input);
		});
	});

	describe('addDocumentId', () => {
		it('adds documentId if id is present and documentId is missing', () => {
			const input = {id: 'id123'};
			const result = addDocumentId(input);
			expect(result).to.deep.eq({id: 'id123', documentId: 'id123'});
		});

		it('does nothing if documentId is already present', () => {
			const input = {id: 'id123', documentId: 'existing'};
			const result = addDocumentId(input);
			expect(result).to.deep.eq(input);
		});
	});

	describe('normalizeId', () => {
		it('returns non-objects as-is', () => {
			expect(normalizeId(null)).to.be.null;
			expect(normalizeId('hello')).to.eq('hello');
			expect(normalizeId(123)).to.eq(123);
		});

		it('normalizes ids on objects', () => {
			expect(normalizeId({id: 'id123'})).to.deep.eq({
				id: 'id123',
				documentId: 'id123'
			});
			expect(normalizeId({documentId: 'doc123'})).to.deep.eq({
				id: 'doc123',
				documentId: 'doc123'
			});
		});
	});

	describe('renameConnectionKeys', () => {
		it('recursively renames keys ending with _connection', () => {
			const input = {
				articles_connection: {
					data: [
						{
							title: 'Hello',
							tags_connection: {
								data: [
									{name: 'Tech'}
								]
							}
						}
					]
				}
			};
			const expected = {
				articles: {
					data: [
						{
							title: 'Hello',
							tags: {
								data: [
									{name: 'Tech'}
								]
							}
						}
					]
				}
			};
			expect(renameConnectionKeys(input)).to.deep.eq(expected);
		});
	});

	describe('normalizeResponse', () => {
		it('recursively normalizes complex nested response shapes', () => {
			const response = {
				articles_connection: {
					data: [
						{
							documentId: 'art-1',
							title: 'My Article',
							collection: {
								data: {
									id: 'col-1',
									name: 'Tech'
								}
							}
						}
					]
				}
			};

			const expected = {
				articles: {
					data: [
						{
							id: 'art-1',
							documentId: 'art-1',
							title: 'My Article',
							collection: {
								data: {
									id: 'col-1',
									documentId: 'col-1',
									name: 'Tech'
								}
							}
						}
					]
				}
			};

			expect(normalizeResponse(response)).to.deep.eq(expected);
		});
	});
});
