const DOUBLE_TAP_MAX_MS = 300
const DOUBLE_TAP_MAX_DISTANCE = 30
const DOUBLE_TAP_ZOOM_IN_SCALE = 2;

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
		this.touchStarts = []
		this.zoomScale = 1
		this.panX = 0
		this.panY = 0
		this.zoomAnchorPhotoX = 0
		this.zoomAnchorPhotoY = 0
		this.startPan = {
			x: null,
			y: null
		}

		this.lastTap = null
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
			if (
				this.modal.classList.contains("hidden") ||
				this.getCurrentImg().classList.contains("zooming")
			) return

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
			img.addEventListener("touchstart", this.resetTouches, {passive: false})
			img.addEventListener("touchmove", this.touchMoveRouter, {passive: false})
			img.addEventListener("touchend", this.touchEndRouter, {passive: false})
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
		if (this.getCurrentImg()?.classList.contains("zooming")) return

		this.modal.classList.add("hidden")
		this.getCurrentImg().addEventListener(
			"transitionend",
			this.resetGestureState,
			{once: true}
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

	resolveGestureDirection = (targetTouch) => {
		if (this.gestureDirection) return
		if (euclideanDistance(this.touchStarts[0], targetTouch) < 10)
			return

		this.gestureDirection =
			Math.abs(targetTouch.clientX - this.touchStarts[0].clientX) >
			Math.abs(targetTouch.clientY - this.touchStarts[0].clientY)
				? "horizontal" : "vertical"
	}

	resetTouches = (event) => {
		this.touchStarts = []

		for (const targetTouch of event.targetTouches) {
			this.touchStarts.push(targetTouch)
		}

		this.startPan = {
			x: null,
			y: null
		}

		if (this.touchStarts.length === 1) this.resetScrollDirection()
	}

	resetScrollDirection = () => {
		this.gestureDirection = undefined
	}

	touchMoveRouter = (event) => {
		this.maxTouches = Math.max(this.maxTouches, event.targetTouches.length)

		switch (this.maxTouches) {
			case 1:
				switch (this.zoomScale) {
					case 1:
						this.maybeApplyVerticalDrag(event)
						break;
					default:
						this.panZoomedImage(event)
						break;
				}
				break;
			case 2:
				this.pinchToZoom(event)
				break;
		}
	}

	pinchToZoom = (event) => {
		if (this.getCurrentImg().classList.contains("dragging")) return
		if (event.targetTouches.length === 1) return

		const img = this.getCurrentImg()
		const rect = img.getBoundingClientRect()

		event.preventDefault()

		img.classList.add("zooming")
		img.classList.remove("zooming-paused")

		const distance = Math.hypot(
			event.targetTouches[0].clientX - event.targetTouches[1].clientX,
			event.targetTouches[0].clientY - event.targetTouches[1].clientY
		)
		const previousScale = this.zoomScale

		if (this.startDistance == null) {
			this.startDistance = Math.hypot(
				this.touchStarts[0].clientX - this.touchStarts[1].clientX,
				this.touchStarts[0].clientY - this.touchStarts[1].clientY
			)
			this.startScale = this.zoomScale

			this.zoomAnchorPhotoX = ((event.targetTouches[0].clientX + event.targetTouches[1].clientX) / 2 - rect.left) / previousScale
			this.zoomAnchorPhotoY = ((event.targetTouches[0].clientY + event.targetTouches[1].clientY) / 2 - rect.top) / previousScale
		}

		this.zoomScale = Math.max(1, this.startScale * (distance / this.startDistance))

		const midpointX = (event.targetTouches[0].clientX + event.targetTouches[1].clientX) / 2
		const midpointY = (event.targetTouches[0].clientY + event.targetTouches[1].clientY) / 2

		this.panX +=
			(midpointX - rect.left) - this.zoomScale * this.zoomAnchorPhotoX
			+ (img.offsetWidth / 2) * (this.zoomScale - previousScale)
		this.panY +=
			(midpointY - rect.top) - this.zoomScale * this.zoomAnchorPhotoY
			+ (img.offsetHeight / 2) * (this.zoomScale - previousScale)

		img.style.setProperty("--scale", this.zoomScale)
		img.style.setProperty("--pan-x", `${this.panX}px`)
		img.style.setProperty("--pan-y", `${this.panY}px`)
	}

	panZoomedImage = (event) => {
		event.preventDefault()
		const img = this.getCurrentImg()
		const rect = img.getBoundingClientRect()

		if (this.startPan.x == null || this.startPan.y == null) {
			img.classList.add("panning")

			this.startPan = {
				x: (event.targetTouches[0].clientX - rect.left) / this.zoomScale,
				y: (event.targetTouches[0].clientY - rect.top) / this.zoomScale
			}
		}

		this.panX +=
			(event.targetTouches[0].clientX - rect.left) - this.startPan.x * this.zoomScale
		this.panY +=
			(event.targetTouches[0].clientY - rect.top) - this.startPan.y * this.zoomScale

		img.style.setProperty("--pan-x", `${this.panX}px`)
		img.style.setProperty("--pan-y", `${this.panY}px`)
	}

	maybeApplyVerticalDrag = (event) => {
		this.resolveGestureDirection(event.targetTouches[0])

		if (this.gestureDirection !== "vertical") return

		this.track.style.scrollSnapType = "none"
		this.track.style.overflowX = "hidden"

		event.preventDefault()
		this.applyVerticalDrag(event.targetTouches[0].clientY - this.touchStarts[0].clientY)
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

	/*
	* suppressed because this is an integration method, where complexity lives.
	* the responsibility of this method is to route to several other methods,
	* each with its own single responsibility.
	*/
	// eslint-disable-next-line complexity
	touchEndRouter = (event) => {
		if (event.targetTouches.length !== 0) return
		const img = this.getCurrentImg();

		switch (this.zoomScale) {
			case 1:
				if (this.isDoubleTap(event)) {
					this.doubleTapZoomIn(event)
				} else if (this.maxTouches === 1) {
					this.verticalGestureCloseLightbox(event)
				} else if (this.maxTouches >= 2) {
					this.resetZoomState(img)
				}
				break;
			default:
				if (this.isDoubleTap(event)) {
					this.resetZoomState(img)
				} else if (this.maxTouches === 1) {
					this.panningTouchEnd(event)
				} else if (this.maxTouches >= 2) {
					this.pauseZooming(event)
				}
				break;
		}

		this.maxTouches = 0
	}

	isDoubleTap = (event) => {
		const isDoubleTap = this.lastTap &&
			event.timeStamp - this.lastTap.time < DOUBLE_TAP_MAX_MS &&
			euclideanDistance(this.lastTap.targetTouch, event.changedTouches[0]) < DOUBLE_TAP_MAX_DISTANCE;

		this.lastTap = isDoubleTap ? null : {
			time: event.timeStamp,
			targetTouch: event.changedTouches[0]
		};

		return isDoubleTap;
	}

	doubleTapZoomIn = (event) => {
		event.preventDefault()
		this.resetGestureState()

		const img = this.getCurrentImg();
		const rect = img.getBoundingClientRect()
		this.lastTap = null

		this.zoomScale = DOUBLE_TAP_ZOOM_IN_SCALE
		this.panX += (1 - DOUBLE_TAP_ZOOM_IN_SCALE) * ((event.changedTouches[0].clientX - rect.left) - img.offsetWidth / 2)
		this.panY += (1 - DOUBLE_TAP_ZOOM_IN_SCALE) * ((event.changedTouches[0].clientY - rect.top) - img.offsetHeight / 2)

		img.classList.add("zooming", "zooming-paused")
		img.style.setProperty("--scale", this.zoomScale)
		img.style.setProperty("--pan-x", `${this.panX}px`)
		img.style.setProperty("--pan-y", `${this.panY}px`)
	}

	panningTouchEnd = () => {
		const img = this.getCurrentImg()

		this.startPan = {
			x: null,
			y: null
		}

		img.classList.remove("panning")
	}

	pauseZooming = () => {
		const img = this.getCurrentImg()
		this.startDistance = null
		img.classList.add("zooming-paused")
	}

	resetZoomState = (img) => {
		img.classList.remove("zooming", "zooming-paused")
		img.style.removeProperty("--scale")
		img.style.removeProperty("--pan-x")
		img.style.removeProperty("--pan-y")
		this.zoomScale = 1
		this.panX = 0
		this.panY = 0
	}

	verticalGestureCloseLightbox = (event) => {
		if (this.gestureDirection !== "vertical") return

		const img = this.getCurrentImg()
		img.style.transition = "transform 0.33s ease-out, opacity 0.33s ease-out"
		const dy = event.changedTouches[0].clientY - this.touchStarts[0].clientY

		if (Math.abs(dy) < Math.min(window.innerHeight * 0.3, 150)) {
			img.style.setProperty("--drag-y", "0")
			img.style.setProperty("--drag-opacity", "1")
			img.addEventListener("transitionend", this.resetGestureState, {once: true})

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
		this.startDistance = null
	}
}

const euclideanDistance = (a, b) => Math.hypot(b.clientX - a.clientX, b.clientY - a.clientY)

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

const loadLargeImage = (slide, photo) => {
	const largeUrl = getLargeUrl(photo)
	if (largeUrl) slide.querySelector('img')?.setAttribute('src', largeUrl)
}

customElements.define("light-box", Lightbox)
