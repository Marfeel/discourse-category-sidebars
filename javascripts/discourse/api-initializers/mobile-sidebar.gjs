import { apiInitializer } from "discourse/lib/api";
import CustomCategorySidebar from "../components/category-sidebar";

export default apiInitializer((api) => {
    const site = api.container.lookup("service:site");

    if (!site.mobileView) {
        return;
    }

    api.renderInOutlet("after-sidebar-sections", CustomCategorySidebar);
});
