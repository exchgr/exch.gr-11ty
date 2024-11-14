class Timestamp extends HTMLElement {
	connectedCallback() {
		const date = new Date(this.getAttribute("data-time"));

		const dateString = date.toLocaleDateString(
			'en-US',
			{
				weekday: 'short',
				month: 'short',
				day: 'numeric',
				year: 'numeric',
			}
		);

		const timeString = date.toLocaleTimeString(
			'en-US',
			{
				hour: 'numeric',
				minute: '2-digit',
				timeZoneName: 'short'
			}
		)

		this.innerHTML = `${dateString} at ${timeString}`
	}
}

customElements.define(
	"time-stamp",
	Timestamp
)

const resizeMasonryItem = (item) => {
	const grid = document.getElementsByClassName('grid-gallery')[0]
	const rowGap = parseInt(window.getComputedStyle(grid).getPropertyValue('grid-row-gap'))
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

	const rowSpan = Math.ceil((itemHeight)/(rowGap))

	item.style.gridRowEnd = 'span ' + rowSpan
}

const resizeAllMasonryItems = () => {
	Array.from(document.querySelectorAll('.grid-gallery > *')).forEach(resizeMasonryItem)
}

const waitForImages = () => {
	Array.from(document.querySelectorAll('.grid-gallery > *')).forEach((item) => {
		imagesLoaded(item).on('progress', (instance) => resizeMasonryItem(instance.elements[0]))
	})
}

['load', 'resize'].forEach((event) => {
	window.addEventListener(event, resizeAllMasonryItems)
})

waitForImages()
