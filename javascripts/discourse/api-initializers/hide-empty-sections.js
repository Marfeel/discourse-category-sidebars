import { apiInitializer } from "discourse/lib/api";

export default apiInitializer((api) => {
	const currentUser = api.getCurrentUser();
	if (currentUser) {
		return;
	}

	document.body.classList.add("no-fixed-sections");
});
