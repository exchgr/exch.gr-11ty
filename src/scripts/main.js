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

		this.shadowRoot.querySelector("button[name=next]").addEventListener("click", this.next)
		this.shadowRoot.querySelector("button[name=previous]").addEventListener("click", this.previous)

		this.shadowRoot

		document.addEventListener("keydown", (event) => {
			const callback = {
				"ArrowLeft": this.previous,
				"ArrowRight": this.next
			}[event.key]

			callback?.(event)
		})

		this.modal = this.shadowRoot.querySelector(".modal")

		this.modal.addEventListener("click", this.closeLightbox)
	}

	disconnectedCallback() {}

	next = (event) => {
		event.preventDefault()

		if (this.currentPhoto >= this.photos.length - 1) {
			return
		}

		this.currentPhoto++
		this.updateCurrentPhoto("next")
	}

	previous = (event) => {
		event.preventDefault()

		if (this.currentPhoto <= 0) {
			return
		}

		this.currentPhoto--
		this.updateCurrentPhoto("previous")
	}

	openLightbox = (event) => {
		event.preventDefault()

		this.currentPhoto = Array.from(this.photos).findIndex((photo) =>
			getImgSrc(photo) ===
			getImgSrc(event.target)
		)

		this.updateCurrentPhoto("none");

		this.modal.classList.remove("hidden")
	};

	closeLightbox = (event) => {
		if (event.target !== this.modal) {
			return
		}
		this.closeLightboxUnsafe();
	};

	closeLightboxUnsafe = () => {
		this.modal.classList.add("hidden")
		const slot = this.shadowRoot.querySelector("slot[name=image]")
		const img = slot.querySelector("img")
		setTimeout(() => {
			slot.removeChild(img)
		}, 187)
	}

	updateCurrentPhoto = (direction) => {
		let oldClass
		let newClass

		switch (direction) {
			case "next":
				oldClass = "out-left"
				newClass = "out-right"
				break
			case "previous":
				oldClass = "out-right"
				newClass = "out-left"
				break
		}

		const previous = this.shadowRoot.querySelector("button[name=previous]");
		const next = this.shadowRoot.querySelector("button[name=next]")

		if (this.currentPhoto <= 0) {
			previous.setAttribute("disabled", "true")
		} else {
			previous.removeAttribute("disabled")
		}

		if (this.currentPhoto >= this.photos.length - 1) {
			next.setAttribute("disabled", true)
		} else {
			next.removeAttribute("disabled")
		}

		const newImgContainer = document.createElement("div")
		newImgContainer.innerHTML = `${getImg(this.photos[this.currentPhoto]).outerHTML}`

		const newImg = newImgContainer.querySelector("img");
		newClass && newImg.classList.add(newClass)

		const slot = this.shadowRoot.querySelector("slot[name=image]");
		const oldImg = slot.querySelector("img");

		slot.appendChild(newImg)
		oldClass && oldImg && oldImg.classList.add(oldClass)
		setTimeout(() => {
			newImg.classList.remove(newClass)
		}, 1)
		setTimeout(() => {
			oldImg && slot.removeChild(oldImg)
		}, 187)

		newImg.addEventListener('touchstart', (event) => {
			event.preventDefault()
			this.touchStartX = event.changedTouches[0].screenX
			this.touchStartY = event.changedTouches[0].screenY
		})

		newImg.addEventListener('touchend', (event) => {
			event.preventDefault()
			this.touchEndX = event.changedTouches[0].screenX
			this.touchEndY = event.changedTouches[0].screenY
			this.handleSwipe(event)
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
			console.log("HERE")
			this.closeLightboxUnsafe()
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
