import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "sidebar-active-link",
  
  initialize() {
    withPluginApi("0.8.7", (api) => {
      let sideObserver;
      let router;

      function getTopicIdFromRoute() {
        if (!router) {
          router = api.container.lookup("service:router");
        }

        const currentRoute = router.currentRoute;
        if (!currentRoute) return null;

        // Get topic ID from route params if available
        if (currentRoute.params?.topic_id) {
          return currentRoute.params.topic_id;
        }

        // Get topic ID from parent route params
        let route = currentRoute;
        while (route && !route.params?.topic_id) {
          route = route.parent;
        }

        if (route?.params?.topic_id) {
          return route.params.topic_id;
        }

        // Fallback to URL parsing for edge cases
        const segments = window.location.pathname.split("/");
        for (let i = 0; i < segments.length; i++) {
          if (segments[i].match(/^\d+$/)) {
            return segments[i];
          }
        }

        return null;
      }

      function updateSidebarActiveLink() {
        const topicId = getTopicIdFromRoute();
        if (!topicId) return;

        const activeItem = document.querySelector(
          "li a.active:not(.sidebar-section-link)"
        );

        if (activeItem) {
          activeItem.classList.remove("active");
          let parent = activeItem.closest("details");

          while (parent) {
            if (parent.tagName === "DETAILS") {
              parent.open = false;
            }
            parent = parent.parentElement.closest("details");
          }
        }

        const currentSidebarItem = document.querySelector(
          `.sidebar-sections li > a[href$='/${topicId}']:not(.active):not(.sidebar-section-link)`
        );

        if (currentSidebarItem) {
          currentSidebarItem.classList.add("active");
          let element = currentSidebarItem.closest("details");

          while (element) {
            if (element.tagName === "DETAILS") {
              element.open = true;
            }
            element = element.parentElement.closest("details");
          }
        }
      }

      function initializeSidebarObserver() {
        if (sideObserver) {
          sideObserver.disconnect();
        }

        const topicBody = document.querySelector("#main-outlet-wrapper");
        if (topicBody) {
          sideObserver = new MutationObserver(updateSidebarActiveLink);
          sideObserver.observe(topicBody, { childList: true, subtree: true });
        }
      }

      // Handle page changes using router service
      api.onPageChange(() => {
        if (!router) {
          router = api.container.lookup("service:router");
        }

        // Add slight delay to allow fixed-sidebar content to move
        setTimeout(() => {
          updateSidebarActiveLink();
          initializeSidebarObserver();
        }, 100);
      });

      // Initialize services and observer on startup
      router = api.container.lookup("service:router");
      initializeSidebarObserver();

      // Cleanup on application teardown
      api.onAppEvent("discourse:before-route-change", () => {
        if (sideObserver) {
          sideObserver.disconnect();
        }
      });
    });
  }
};