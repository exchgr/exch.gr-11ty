const {expect} = require('chai')
const {stripTagsPrefix} = require('../src/lib/util')

describe('util', () => {
	describe('stripTagsPrefix', () => {
		it("removes 'tags/' from the beginning of a string", () => {
			expect(stripTagsPrefix("tags/cool-stuff")).to.eq("cool-stuff")
		})

		it("doesn't remove 'tags/' from anywhere but the beginning of a string", () => {
			expect(stripTagsPrefix("stags/cool-stuff")).to.eq("stags/cool-stuff")
			expect(stripTagsPrefix("cool-stuff")).to.eq("cool-stuff")
		})
	})
})
