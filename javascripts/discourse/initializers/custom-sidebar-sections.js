export default {
  name: "custom-sidebar-sections",

  initialize() {
    function updateCustomSidebar() {
      const sidebarSections = document.querySelectorAll(
        ".sidebar-section-wrapper[data-section-name]"
      );

      for (const section of sidebarSections) {
        const sidebarName = section.dataset.sectionName;
        const customSidebar = document.querySelector(
          `.sidebar-section-wrapper .custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
        );

        if (!customSidebar) {
          const mainOutlet = document.querySelector("#main-outlet");
          const customSidebarClone = mainOutlet?.querySelector(
            `.custom-sidebar-section[data-sidebar-name="${sidebarName}"]`
          );

          if (customSidebarClone) {
            const clonedSidebar = customSidebarClone.cloneNode(true);
            section.appendChild(clonedSidebar);
          }
        }
      }
    }

    // Wait for DOM to be ready
    const initializeCustomSidebarObserver = () => {
      const fixedObserver = new MutationObserver(() => {
        updateCustomSidebar();
      });

      const mainOutletSidebars = document.body;

      if (mainOutletSidebars) {
        fixedObserver.observe(mainOutletSidebars, {
          childList: true,
          subtree: true,
        });

        window.addEventListener("beforeunload", () => {
          fixedObserver.disconnect();
        });

        // Run initial update
        updateCustomSidebar();
      }
    };

    // Initialize when DOM is ready
    if (document.readyState === "loading") {
      document.addEventListener(
        "DOMContentLoaded",
        initializeCustomSidebarObserver
      );
    } else {
      initializeCustomSidebarObserver();
    }
  },
};
