class Lightbox extends HTMLElement {
	constructor() {
		super();
		this
			.attachShadow({mode: "open"})
			.appendChild(
				document.importNode(
					document.getElementById("light-box").content,
					true
				)
			)
	}

	connectedCallback() {
		this.photos = document.querySelectorAll(".grid-gallery > *")

		this.currentPhoto = 0
		this.maxTouches = 0

		this.bindEvents()
		this.buildSlides()
		this.updateButtonStates()
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

	buildSlides = () => {
		this.photos.forEach((photo) => {
			const slide = document.createElement("div")
			slide.className = "slide"
			const img = getImg(photo).cloneNode(true)
			img.addEventListener("click", (event) => event.stopPropagation())
			img.addEventListener("touchstart", this.resetScrollDirection, {passive: false})
			img.addEventListener("touchmove", this.maybeApplyVerticalDrag, {passive: false})
			img.addEventListener("touchend", this.touchEndRouter)
			slide.appendChild(img)
			this.imageSlot.appendChild(slide)
		})

		this.slides = this.imageSlot.querySelectorAll(".slide")
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
		loadLargeImage(this.slides[this.currentPhoto], this.photos[this.currentPhoto])
	}

	closeLightbox = () => {
		this.modal.classList.add("hidden")
		this.getCurrentImg().addEventListener(
			"transitionend",
			this.resetGestureState
		)
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

	getCurrentImg = () =>
		this.slides[this.currentPhoto]?.querySelector("img")

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

	updateCurrentPhoto = (index, behavior = "smooth") => {
		this.currentPhoto = index

		this.track.scrollTo({
			left: index * window.innerWidth,
			behavior
		})

		this.updateButtonStates()
	}

	// TODO: figure out if timeout is necessary; if not, rename & inline
	onScroll = () => {
		clearTimeout(this.scrollSyncTimeoutId)
		this.scrollSyncTimeoutId = setTimeout(() => {
			this.syncCurrentPhotoFromScroll()
		}, 100)
	}

	syncCurrentPhotoFromScroll = () => {
		this.currentPhoto = Math.max(0, Math.min(this.photos.length - 1, Math.round(this.track.scrollLeft / window.innerWidth)))
		this.updateButtonStates()
		loadLargeImage(this.slides[this.currentPhoto], this.photos[this.currentPhoto])
	}

	resolveGestureDirection = (currentPoint) => {
		if (this.gestureDirection) return
		if (euclideanDistance(this.touchStart, currentPoint) < 10)
			return

		this.gestureDirection =
			Math.abs(currentPoint.x - this.touchStart.x) >
			Math.abs(currentPoint.y - this.touchStart.y)
				? "horizontal" : "vertical"
	}

	resetScrollDirection = (event) => {
		if (event.touches.length !== 1) return

		this.touchStart = {
			x: event.touches[0].clientX,
			y: event.touches[0].clientY
		}

		this.gestureDirection = undefined
	}

	maybeApplyVerticalDrag = (event) => {
		this.maxTouches = Math.max(this.maxTouches, event.touches.length)

		if (this.maxTouches !== 1) return

		this.resolveGestureDirection({
			x: event.touches[0].clientX,
			y: event.touches[0].clientY
		})

		if (this.gestureDirection !== "vertical") return

		this.track.style.scrollSnapType = "none"
		this.track.style.overflowX = "hidden"

		event.preventDefault()
		this.applyVerticalDrag(event.touches[0].clientY - this.touchStart.y)
	}

	applyVerticalDrag = (dy) => {
		const img = this.getCurrentImg()
		if (!img) return

		img.classList.add("dragging")

		const maxDrag = window.innerHeight * 0.5
		const opacity = Math.max(0, Math.min(1, 1 - (Math.abs(dy) / maxDrag)))

		img.style.setProperty("--drag-y", `${dy}px`)
		img.style.setProperty("--drag-opacity", opacity)
	}

	touchEndRouter = (event) => {
		// only act if no fingers are left touching the screen
		if (event.touches.length === 0) {
			// only close lightbox if it was single touch
			if (this.maxTouches === 1) {
				this.verticalGestureCloseLightbox(event)
			}

			this.maxTouches = 0
		}
	}

	verticalGestureCloseLightbox = (event) => {
		if (this.gestureDirection !== "vertical") return

		const img = this.getCurrentImg()
		img.style.transition = "transform 0.33s ease-out, opacity 0.33s ease-out"
		const dy = event.changedTouches[0].clientY - this.touchStart.y

		if (Math.abs(dy) < Math.min(window.innerHeight * 0.3, 150)) {
			img.style.setProperty("--drag-y", "0")
			img.style.setProperty("--drag-opacity", "1")
			img.addEventListener("transitionend", this.resetGestureState)

			return
		}

		img.style.setProperty("--drag-y", `${dy > 0 ? dy + 200 : dy - 200}px`)
		img.style.setProperty("--drag-opacity", "0")
		this.closeLightbox()
		this.gestureDirection = undefined
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

		this.maxTouches = 0
	}
}

const euclideanDistance = (a, b) => Math.hypot(b.x - a.x, b.y - a.y)

const getImg = (photo) => {
	return photo.querySelector('img') || photo;
}

const getImgSrc = (photo) => {
	return getImg(photo).getAttribute('src');
}

const getLargeUrl = (photo) => {
	if (photo.tagName === 'A') return photo.href
	return photo.querySelector('a')?.href || null
}

const LARGE_VIEWPORT_BREAKPOINT = 600

const loadLargeImage = (slide, photo) => {
	const largeUrl = getLargeUrl(photo)
	if (largeUrl) slide.querySelector('img')?.setAttribute('src', largeUrl)
}

customElements.define("light-box", Lightbox)
