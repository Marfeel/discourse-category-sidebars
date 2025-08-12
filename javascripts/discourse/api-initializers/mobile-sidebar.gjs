import { apiInitializer } from "discourse/lib/api";
import CustomCategorySidebar from "../components/category-sidebar";

export default apiInitializer((api) => {
    const site = api.container.lookup("service:site");

    if (!site.mobileView) {
        return;
    }

    const MobileSidebar = <template>
        <div class="sidebar-sections">
            <CustomCategorySidebar />
        </div>
    </template>;

    api.renderInOutlet("after-sidebar-sections", MobileSidebar);
});
