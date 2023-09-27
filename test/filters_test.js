const {expect}= require('chai')
const {noTags, noAll, categoryOrTag} = require('../src/lib/filters')

describe('filters', () => {
	describe('noTags', () => {
		it("should exclude strings beginning with 'tags/'", () => {
			const collections = {
				"collection": {},
				"tags/cool-tag": {},
				"stags/cool-stag": {}
			}

			const expectedCollections = {
				"collection": {},
				"stags/cool-stag": {}
			}

			expect(noTags(collections)).to.deep.equal(expectedCollections)
		})
	})

	describe('noAll', () => {
		it("should exclude strings beginning with 'tags/'", () => {
			const collections = {
				"collection": {},
				"all": {},
				"alls": {}
			}

			const expectedCollections = {
				"collection": {},
				"alls": {}
			}

			expect(noAll(collections)).to.deep.equal(expectedCollections)
		})
	})

	describe('categoryOrTag', () => {
		const category = {
			data: {}
		}
		const tags = {
			data: [
				{
					attributes: {
						name: "bad stuff",
						slug: "bad-stuff"
					}
				},
				{
					attributes: {
						name: "cool stuff",
						slug: "cool-stuff"
					}
				},
				{
					attributes: {
						name: "extra-cool stuff 2",
						slug: "extra-cool-stuff-2"
					}
				}
			]
		}

		const article = {
			data: {
				article: {
					attributes: {
						collection: category,
						tags
					}
				}
			}
		}

		it('extracts a category when the slug is a category', () => {
			expect(categoryOrTag("not_a_tags/", article)).to.deep.equal(category.data)
		})

		it('extracts a tag when the slug is a tag', () => {
			expect(categoryOrTag("tags/cool-stuff", article)).to.deep.equal(tags.data[1])
		})
	})
})
