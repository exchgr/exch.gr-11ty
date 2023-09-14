const {expect} = require('chai')
const {isTag, stripTagsPrefix} = require("../lib/util");

describe('util', () => {
	describe('isTag', () => {
		it('matches a tag', () => {
			expect(isTag("tags/")).to.be.true
			expect(isTag("tags/cool-stuff")).to.be.true
		})

		it("doesn't match a non-tag", () => {
			expect(isTag("stags/cool-stuff")).to.be.false
			expect(isTag("cool-stuff")).to.be.false
		})
	})

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
