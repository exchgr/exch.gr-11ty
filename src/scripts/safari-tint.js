const root = document.documentElement;

const refresh = () => {
	root.dataset.safariTintRefresh = "";
	requestAnimationFrame(() => requestAnimationFrame(() => {
		delete root.dataset.safariTintRefresh;
	}));
};

window.matchMedia("(prefers-color-scheme: dark)").addEventListener("change", refresh);
window.addEventListener("pageshow", refresh);
