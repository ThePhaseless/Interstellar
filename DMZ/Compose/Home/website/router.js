function redirectBasedOnScreenSize() {
	var mobilePath = "/mobile/"; // Path for the mobile website
	var defaultPath = "/"; // Default path for the main website

	console.log(window.innerWidth > window.innerHeight);
	console.log(window.location.pathname);

	// Check if the screen width is greater than the height
	if (window.innerWidth < window.innerHeight) {
		// If on the default site, redirect to the mobile site
		if (window.location.pathname === defaultPath) {
			console.log("redirecting to mobile site");
			window.location.href = mobilePath;
		}
	} else {
		// If on the mobile site, redirect to the default site
		if (window.location.pathname === mobilePath) {
			console.log("redirecting to default site");
			window.location.href = defaultPath;
		}
	}
}

// Call the function to redirect based on screen size initially
redirectBasedOnScreenSize();

// Add event listener for resize event to call redirection function on every resize
window.addEventListener("resize", redirectBasedOnScreenSize);
