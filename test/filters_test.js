const {expect} = require('chai')
const {
	noTags,
	noAll,
	categoryOrTag,
	categoryOrTagName
} = require('../src/lib/filters')

describe('filters', () => {
	const category = {
		name: "photography",
		slug: "photography"
	};
	const tags = [
		{
			name: "bad stuff",
			slug: "bad-stuff"
		},
		{
			name: "cool stuff",
			slug: "cool-stuff"
		},
		{
			name: "extra-cool stuff 2",
			slug: "extra-cool-stuff-2"
		}
	];

	const article = {
		data: {
			article: {
				collection: category,
				tags
			}
		}
	};

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
		it('extracts a category when the slug is a category', () => {
			expect(categoryOrTag("not_a_tags/", article)).to.deep.equal(category)
		})

		it('extracts a tag when the slug is a tag', () => {
			expect(categoryOrTag("tags/cool-stuff", article)).to.deep.equal(tags[1])
		})
	})

	describe('categoryOrTagName', () => {
		it('extracts a category name when the slug is a category', () => {
			expect(categoryOrTagName("not_a_tags/", article)).to.equal("photography")
		})

		it('extracts a tag name when the slug is a tag', () => {
			expect(categoryOrTagName("tags/cool-stuff", article)).to.equal("cool stuff")
		})

		it('is falsy when there is no article', () => {
			expect(categoryOrTagName("tags/cool-stuff", undefined)).to.be.undefined
		})
	})
})
