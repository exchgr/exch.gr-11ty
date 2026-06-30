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

	getCurrentImg = () => {
		return this.slides[this.currentPhoto]?.querySelector("img")
	}

	resetGestureState = () => {
		const img = this.getCurrentImg()
		if (!img) return

		img.classList.remove("dragging")
		img.style.removeProperty("--drag-y")
		img.style.removeProperty("--drag-opacity")
		img.style.removeProperty("transition")

		this.track.style.scrollSnapType = ""
		this.track.style.overflowX = ""
	}

	connectedCallback() {
		this.photos = document.querySelectorAll(".grid-gallery > *")

		this.currentPhoto = 0

		this.bindEvents()
		this.buildSlides()
		this.updateButtonStates()
	}

	buildSlides = () => {
		this.photos.forEach((photo) => {
			const slide = document.createElement("div")
			slide.className = "slide"
			const img = getImg(photo).cloneNode(true)
			img.addEventListener("click", (event) => event.stopPropagation())
			img.addEventListener("touchstart", this.resetScrollDirection, {passive: false})
			img.addEventListener("touchmove", this.maybeApplyVerticalDrag, {passive: false})
			img.addEventListener("touchend", this.verticalGestureCloseLightbox)
			slide.appendChild(img)
			this.imageSlot.appendChild(slide)
		})

		this.slides = this.imageSlot.querySelectorAll(".slide")
	}

	bindEvents = () => {
		this.photos.forEach((photo) => {
			photo.addEventListener("click", this.openLightbox)
		})

		this.nextButton = this.shadowRoot.querySelector("button[name=next]")
		this.previousButton = this.shadowRoot.querySelector("button[name=previous]")

		this.nextButton.addEventListener("click", this.next)
		this.previousButton.addEventListener("click", this.previous)

		document.addEventListener("keydown", (event) => {
			if (this.modal.classList.contains("hidden")) return

			const callback = {
				"ArrowLeft": this.previous,
				"ArrowRight": this.next
			}[event.key]

			callback?.(event)
		})

		this.modal = this.shadowRoot.querySelector(".modal")
		this.modal.addEventListener("click", this.closeLightbox)

		this.track = this.shadowRoot.querySelector(".track")
		this.imageSlot = this.shadowRoot.querySelector("slot[name=image]")
		this.track.addEventListener("scroll", this.onScroll)
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
			"auto"
		)

		this.modal.classList.remove("hidden")
	}

	closeLightbox = () => {
		this.modal.classList.add("hidden")
		this.resetGestureState()
	}

	updateCurrentPhoto = (index, behavior = "smooth") => {
		this.currentPhoto = index

		this.track.scrollTo({
			left: index * window.innerWidth,
			behavior
		})

		this.updateButtonStates()
	}

	updateButtonStates = () => {
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
	}

	resetScrollDirection = (event) => {
		if (event.touches.length !== 1) return

		this.touchStartX = event.touches[0].clientX
		this.touchStartY = event.touches[0].clientY
		this.gestureDirection = "undecided"
	}

	resolveGestureDirection = (currentX, currentY) => {
		const dx = Math.abs(currentX - this.touchStartX)
		const dy = Math.abs(currentY - this.touchStartY)

		if (this.thresholdExceedsGestureDistance(dx, dy)) return

		this.gestureDirection = dx > dy ? "horizontal" : "vertical"
	}

	thresholdExceedsGestureDistance = (dx, dy) => dx < 10 && dy < 10

	applyVerticalDrag = (dy) => {
		const img = this.getCurrentImg()
		if (!img) return

		img.classList.add("dragging")

		const maxDrag = window.innerHeight * 0.5
		const opacity = Math.max(0, Math.min(1, 1 - (Math.abs(dy) / maxDrag)))

		img.style.setProperty("--drag-y", `${dy}px`)
		img.style.setProperty("--drag-opacity", opacity)
	}

	maybeApplyVerticalDrag = (event) => {
		if (event.touches.length !== 1) return

		const currentX = event.touches[0].clientX
		const currentY = event.touches[0].clientY

		this.resolveGestureDirection(currentX, currentY)

		if (this.gestureDirection !== "vertical") return

		this.track.style.scrollSnapType = "none"
		this.track.style.overflowX = "hidden"

		event.preventDefault()
		this.applyVerticalDrag(currentY - this.touchStartY)
	}

	verticalGestureCloseLightbox = (event) => {
		if (this.gestureDirection !== "vertical") return
		const dy = event.changedTouches[0].clientY - this.touchStartY

		if (Math.abs(dy) < Math.min(window.innerHeight * 0.3, 150)) {
			this.resetGestureState()
			return
		}

		const img = this.getCurrentImg()
		img.style.transition = "transform 0.25s ease-out, opacity 0.25s ease-out"
		img.style.setProperty("--drag-y", `${dy > 0 ? dy + 200 : dy - 200}px`)
		img.style.setProperty("--drag-opacity", "0")
		this.closeLightbox()
		this.gestureDirection = "undecided"
	}

	onScroll = () => {
		clearTimeout(this.scrollSyncTimeoutId)
		this.scrollSyncTimeoutId = setTimeout(() => {
			this.syncCurrentPhotoFromScroll()
		}, 100)
	}

	syncCurrentPhotoFromScroll = () => {
		this.currentPhoto = Math.round(this.track.scrollLeft / window.innerWidth)
		this.updateButtonStates()
	}
}

const getImg = (photo) => {
	return photo.querySelector('img') || photo;
}

const getImgSrc = (photo) => {
	return getImg(photo).getAttribute('src');
}

customElements.define("light-box", Lightbox)
