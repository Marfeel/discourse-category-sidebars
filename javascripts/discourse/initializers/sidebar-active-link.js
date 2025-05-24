import { schedule } from "@ember/runloop";
import { withPluginApi } from "discourse/lib/plugin-api";

export default {
  name: "sidebar-active-link",

  initialize() {
    withPluginApi("0.8.31", (api) => {
      function updateSidebarActiveLink() {
        const segments = window.location.pathname.split("/");

        // check all segments in order to find first segment that is a number
        // this is to handle cases where the route contains a number
        // e.g. /t/how-to-set-up-the-x-twitter-integration/9253, /t/postmortem-2024-05-08-champions-league-semifinals/59480/2
        let topicId = "";
        for (let i = 0; i < segments.length; i++) {
          if (segments[i].match(/^\d+$/)) {
            topicId = segments[i];
            break;
          }
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

      api.onPageChange(() => {
        updateSidebarActiveLink();
      });

      document.addEventListener('custom-sections-ready', () => {
        console.log("Custom sections are ready, updating sidebar active link.");
        schedule("afterRender", () => {
          updateSidebarActiveLink();
        });
      });
    });
  }
};