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
        if (!currentRoute) {
          return null;
        }

        if (currentRoute.params?.topic_id) {
          return currentRoute.params.topic_id;
        }

        let route = currentRoute;
        while (route && !route.params?.topic_id) {
          route = route.parent;
        }

        if (route?.params?.topic_id) {
          return route.params.topic_id;
        }

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
        if (!topicId) {
          return;
        }

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
        sideObserver?.disconnect();

        const topicBody = document.querySelector("#main-outlet-wrapper");
        if (topicBody) {
          sideObserver = new MutationObserver(updateSidebarActiveLink);
          sideObserver.observe(topicBody, { childList: true, subtree: true });
        }
      }

      function initializeMobileObserver() {
        api.onAppEvent("sidebar:panel-shown", () => {
          setTimeout(() => updateSidebarActiveLink(), 50);
        });

        api.onAppEvent("mobile:panel-opened", () => {
          setTimeout(() => updateSidebarActiveLink(), 50);
        });

        const mobilePanel = document.querySelector(".mobile-view .panel");
        if (mobilePanel) {
          const mobilePanelObserver = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
              if (mutation.type === "childList") {
                const sidebarInPanel =
                  mobilePanel.querySelector(".sidebar-sections");
                if (sidebarInPanel) {
                  setTimeout(() => updateSidebarActiveLink(), 50);
                }
              }
            }
          });

          mobilePanelObserver.observe(mobilePanel, {
            childList: true,
            subtree: true,
          });

          const panelVisibilityObserver = new MutationObserver((mutations) => {
            for (const mutation of mutations) {
              if (
                mutation.type === "attributes" &&
                mutation.attributeName === "class"
              ) {
                const panel = mutation.target;
                if (
                  panel.offsetParent !== null &&
                  panel.querySelector(".sidebar-sections")
                ) {
                  setTimeout(() => updateSidebarActiveLink(), 50);
                }
              }
            }
          });

          panelVisibilityObserver.observe(mobilePanel, {
            attributes: true,
            attributeFilter: ["class", "style"],
          });
        }
      }

      api.onPageChange(() => {
        if (!router) {
          router = api.container.lookup("service:router");
        }

        setTimeout(() => {
          updateSidebarActiveLink();
          initializeSidebarObserver();
        }, 100);
      });

      router = api.container.lookup("service:router");
      initializeSidebarObserver();

      const site = api.container.lookup("service:site");
      if (site?.mobileView) {
        setTimeout(() => initializeMobileObserver(), 200);
      }

      api.onAppEvent("discourse:before-route-change", () => {
        sideObserver?.disconnect();
      });
    });
  },
};
