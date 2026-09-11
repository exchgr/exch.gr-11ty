const supportsGridLanes = CSS.supports('display', 'grid-lanes')

const resizeMasonryItem = (item) => {
	const grid = document.getElementsByClassName('grid-gallery')[0]
	const rowGap = parseFloat(window.getComputedStyle(grid).getPropertyValue('grid-row-gap'))
	const itemStyle = window.getComputedStyle(item)

	const itemHeight = Array.from(item.querySelectorAll('img, figcaption')).reduce((sum, content) => {
			return (
				sum
				+ content.getBoundingClientRect().height
			);
		}, 0)
		+ parseInt(itemStyle.getPropertyValue('margin-top'))
		+ parseInt(itemStyle.getPropertyValue('margin-bottom'))
		+ rowGap

	const rowSpan = Math.ceil((itemHeight) / (rowGap))

	item.style.gridRowEnd = 'span ' + rowSpan
}

const resizeAllMasonryItems = () => {
	Array.from(document.querySelectorAll('.grid-gallery > *')).forEach(resizeMasonryItem)
}

const waitForImages = () => {
	if (supportsGridLanes) return
	Array.from(document.querySelectorAll('.grid-gallery > *')).forEach((item) => {
		imagesLoaded(item).on('progress', (instance) => resizeMasonryItem(instance.elements[0]))
	})
}

['load', 'resize'].forEach((event) => {
	if (supportsGridLanes) return
	window.addEventListener(event, resizeAllMasonryItems)
})

waitForImages()
