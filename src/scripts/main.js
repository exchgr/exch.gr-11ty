// Timestamp
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
// end Timestamp

// masonry
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
// end masonry

// lightbox
class Lightbox extends HTMLElement {
	constructor() {
		super();
		let template = document.getElementById("light-box")
		let templateContent = template.content

		const shadowRoot = this.attachShadow({mode: "open"})
		shadowRoot.appendChild(document.importNode(templateContent, true))
	}

	connectedCallback() {
		this.photos = document.querySelectorAll(".grid-gallery > *")

		this.currentPhoto = 0

		this.photos.forEach((photo) => {
			photo.addEventListener("click", this.openLightbox)
		})

		this.nextButton = this.shadowRoot.querySelector("button[name=next]")
		this.previousButton = this.shadowRoot.querySelector("button[name=previous]")

		this.nextButton.addEventListener("click", this.next)
		this.previousButton.addEventListener("click", this.previous)

		document.addEventListener("keydown", (event) => {
			const callback = {
				"ArrowLeft": this.previous,
				"ArrowRight": this.next
			}[event.key]

			callback?.(event)
		})

		this.modal = this.shadowRoot.querySelector(".modal")
		this.modal.addEventListener("click", this.closeLightbox)

		this.imageSlot = this.shadowRoot.querySelector("slot[name=image]");
	}

	next = (event) => {
		event.preventDefault()
		event.stopPropagation()

		if (this.isLastPhoto()) {
			return
		}

		this.updateCurrentPhoto(this.currentPhoto + 1)
	}

	previous = (event) => {
		event.preventDefault()
		event.stopPropagation()

		if (this.isFirstPhoto()) {
			return
		}

		this.updateCurrentPhoto(this.currentPhoto - 1)
	}

	isLastPhoto = () => {
		return this.currentPhoto >= this.photos.length - 1;
	}

	isFirstPhoto = () => {
		return this.currentPhoto <= 0;
	}

	openLightbox = (event) => {
		event.preventDefault()

		this.updateCurrentPhoto(
			Array.from(this.photos).findIndex((photo) =>
				getImgSrc(photo) ===
				getImgSrc(event.target)
			),
			false
		);

		this.modal.classList.remove("hidden")
	};

	closeLightbox = () => {
		this.modal.classList.add("hidden")
		const img = this.imageSlot.querySelector("img")
		setTimeout(() => {
			this.imageSlot.removeChild(img)
		}, 250)
	};

	updateCurrentPhoto = (index, animate = true) => {
		let oldClass
		let newClass

		if (animate) {
			if (index > this.currentPhoto) {
				oldClass = "out-left"
				newClass = "out-right"
			}

			if (index < this.currentPhoto) {
				oldClass = "out-right"
				newClass = "out-left"
			}
		}

		this.currentPhoto = index

		if (this.isFirstPhoto()) {
			this.previousButton.setAttribute("disabled", "true")
		} else {
			this.previousButton.removeAttribute("disabled")
		}

		if (this.isLastPhoto()) {
			this.nextButton.setAttribute("disabled", "true")
		} else {
			this.nextButton.removeAttribute("disabled")
		}

		const newImgContainer = document.createElement("div")
		newImgContainer.innerHTML = `${getImg(this.photos[this.currentPhoto]).outerHTML}`

		const newImg = newImgContainer.querySelector("img");
		newClass && newImg.classList.add(newClass)
		this.imageSlot.appendChild(newImg)

		const oldImg = Array.from(this.imageSlot.querySelectorAll("img")).at(-2)
		oldClass && oldImg && oldImg.classList.add(oldClass)

		setTimeout(() => {
			newImg.classList.remove(newClass)
		}, 1)
		setTimeout(() => {
			oldImg && this.imageSlot.removeChild(oldImg)
		}, 250)

		newImg.addEventListener('touchstart', (event) => {
			event.preventDefault()
			event.stopPropagation()
			this.touchStartX = event.changedTouches[0].screenX
			this.touchStartY = event.changedTouches[0].screenY
		})

		newImg.addEventListener('touchend', (event) => {
			event.preventDefault()
			event.stopPropagation()
			this.touchEndX = event.changedTouches[0].screenX
			this.touchEndY = event.changedTouches[0].screenY
			this.handleSwipe(event)
		})

		newImg.addEventListener('click', (event) => {
			event.preventDefault()
			event.stopPropagation()
		})
	}

	handleSwipe = (event) => {
		const xDelta = this.touchStartX - this.touchEndX
		const yDelta = this.touchStartY - this.touchEndY

		if (Math.abs(xDelta) > Math.abs(yDelta)) {
			if (xDelta > 0) {
				this.next(event)
			} else {
				this.previous(event)
			}
		} else if (xDelta !== 0 && yDelta !== 0) {
			this.closeLightbox()
		}
	}
}

const getImg = (photo) => {
	return photo.querySelector('img') || photo;
}

const getImgSrc = (photo) => {
	return getImg(photo).getAttribute('src');
}

customElements.define("light-box", Lightbox)
