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
